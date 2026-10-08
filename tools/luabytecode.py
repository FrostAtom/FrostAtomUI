"""Lua 5.1 compiler front end (luac5.1, or lupa.lua51 when luac5.1 is not on PATH) and bytecode reader."""
import os
import shutil
import struct
import subprocess
import tempfile

OP_GETGLOBAL, OP_SETGLOBAL, OP_SELF = 5, 7, 11
BITRK = 1 << 8

_lupa_compile = None


class Proto:
    __slots__ = ("source", "line", "lastline", "nups", "nparams", "code", "consts", "protos", "lines", "locvars")


def _compile_lupa(source, chunkname):
    global _lupa_compile
    if _lupa_compile is None:
        import lupa.lua51

        rt = lupa.lua51.LuaRuntime(encoding=None)
        _lupa_compile = rt.eval(
            "function(s, n) local f, e = loadstring(s, n) if not f then return nil, e end return string.dump(f) end"
        )
    res = _lupa_compile(source, chunkname.encode("utf-8"))
    if isinstance(res, tuple):
        return None, res[1].decode("utf-8", "replace")
    return res, None


def _compile_luac(luac, source, chunkname):
    with tempfile.TemporaryDirectory() as tmp:
        name = chunkname[1:] if chunkname.startswith("@") else chunkname
        src = os.path.join(tmp, "in.lua")
        out = os.path.join(tmp, "out.luac")
        with open(src, "wb") as f:
            f.write(source)
        r = subprocess.run([luac, "-o", out, src], capture_output=True)
        if r.returncode != 0:
            err = r.stderr.decode("utf-8", "replace").strip()
            err = err.replace(src, name)
            if err.startswith("luac5.1: ") or err.startswith("luac: "):
                err = err.split(": ", 1)[1]
            return None, err
        with open(out, "rb") as f:
            return f.read(), None


def compile_source(source, chunkname):
    if isinstance(source, str):
        source = source.encode("utf-8")
    luac = shutil.which("luac5.1")
    if luac:
        return _compile_luac(luac, source, chunkname)
    return _compile_lupa(source, chunkname)


def compile_file(path, chunkname=None):
    with open(path, "rb") as f:
        return compile_source(f.read(), chunkname or "@" + path.replace("\\", "/"))


class _Reader:
    def __init__(self, data):
        self.data, self.pos = data, 0
        if data[:4] != b"\x1bLua" or data[4] != 0x51:
            raise ValueError("not Lua 5.1 bytecode")
        endian = "<" if data[6] == 1 else ">"
        self.int_size, self.size_t, self.instr_size, self.num_size = data[7], data[8], data[9], data[10]
        self.integral = data[11] == 1
        self.e = endian
        self.pos = 12

    def unpack(self, fmt, size):
        v = struct.unpack_from(self.e + fmt, self.data, self.pos)[0]
        self.pos += size
        return v

    def byte(self):
        v = self.data[self.pos]
        self.pos += 1
        return v

    def int(self):
        return self.unpack({4: "i", 8: "q"}[self.int_size], self.int_size)

    def sizet(self):
        return self.unpack({4: "I", 8: "Q"}[self.size_t], self.size_t)

    def string(self):
        n = self.sizet()
        if n == 0:
            return None
        s = self.data[self.pos : self.pos + n - 1]
        self.pos += n
        return s.decode("utf-8", "replace")

    def number(self):
        if self.integral:
            return self.unpack({4: "i", 8: "q"}[self.num_size], self.num_size)
        return self.unpack({4: "f", 8: "d"}[self.num_size], self.num_size)

    def proto(self, parent_source):
        p = Proto()
        p.source = self.string() or parent_source
        p.line, p.lastline = self.int(), self.int()
        p.nups, p.nparams = self.byte(), self.byte()
        self.byte()
        self.byte()
        n = self.int()
        p.code = list(struct.unpack_from(self.e + "%dI" % n, self.data, self.pos))
        self.pos += n * self.instr_size
        p.consts = []
        for _ in range(self.int()):
            t = self.byte()
            if t == 0:
                p.consts.append(None)
            elif t == 1:
                p.consts.append(self.byte() != 0)
            elif t == 3:
                p.consts.append(self.number())
            elif t == 4:
                p.consts.append(self.string())
            else:
                raise ValueError("bad constant type %d" % t)
        p.protos = [self.proto(p.source) for _ in range(self.int())]
        n = self.int()
        p.lines = list(struct.unpack_from(self.e + "%di" % n, self.data, self.pos))
        self.pos += n * 4
        p.locvars = []
        for _ in range(self.int()):
            name = self.string()
            p.locvars.append((name, self.int(), self.int()))
        for _ in range(self.int()):
            self.string()
        return p


def parse(bytecode):
    return _Reader(bytecode).proto(None)


def walk(proto):
    yield proto
    for child in proto.protos:
        yield from walk(child)


def globals_used(proto):
    for p in walk(proto):
        for pc, ins in enumerate(p.code):
            op = ins & 0x3F
            if op == OP_GETGLOBAL or op == OP_SETGLOBAL:
                name = p.consts[(ins >> 14) & 0x3FFFF]
                yield ("get" if op == OP_GETGLOBAL else "set"), name, p.lines[pc] if pc < len(p.lines) else p.line


def method_calls(proto):
    for p in walk(proto):
        for pc, ins in enumerate(p.code):
            if ins & 0x3F == OP_SELF:
                c = (ins >> 14) & 0x1FF
                if c & BITRK:
                    yield p.consts[c & ~BITRK], p.lines[pc] if pc < len(p.lines) else p.line


def string_constants(proto):
    for p in walk(proto):
        for k in p.consts:
            if isinstance(k, str):
                yield k


def peak_locals(proto):
    events = []
    for _, start, end in proto.locvars:
        events.append((start, 1))
        events.append((end, -1))
    cur = peak = 0
    for _, d in sorted(events, key=lambda e: (e[0], -e[1])):
        cur += d
        peak = max(peak, cur)
    return peak
