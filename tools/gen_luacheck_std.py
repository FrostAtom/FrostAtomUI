"""Generates tools/luacheck_std_wow335.lua from the 3.3.5a (12340) client and its Blizzard interface sources.

Usage: gen_luacheck_std.py <Interface dir> <Wow.exe> [output]

Globals come from the FrameXML and AddOns sources (Lua globals, GlobalStrings, named XML frames, regions and fonts with
templates expanded, frames created from Lua with a literal name, globals the code reads but never defines) and from
the Lua registration tables of Wow.exe (split where the code references them): a table becomes global API when the
Blizzard code reads a quarter of it as globals, which tells it apart from the widget method tables; the string, table,
math, bit and coroutine library tables add only their capitalized names.
"""
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

import luabytecode

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIRS = ("FrameXML", "AddOns")
HANDLER_ARGS = ", ".join(
    "self event elapsed button down delta motion value userInput key text char width height keystate ...".split()
)
LUA_BUILTINS = set(
    """_G _VERSION arg assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs load
    loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select
    setfenv setmetatable string table tonumber tostring type unpack xpcall""".split()
)
ENGINE_FRAMES = ("PlayerArrowFrame", "PlayerArrowEffectFrame", "PlayerMiniArrowFrame", "PlayerMiniArrowEffectFrame")
LITERAL_FRAME = re.compile(r'CreateFrame\(\s*"\w+"\s*,\s*"(\w+)"\s*(?:,\s*([^,)]*)\s*(?:,\s*"([^"]+)")?)?\)')
IDENT = re.compile(rb"[A-Za-z_][A-Za-z0-9_]*\0")
API_TABLE_MIN_SHARE = 0.25
LUA_LIBRARY_MARKERS = {"byte", "concat", "cosh", "bnot", "yield"}


def local_name(tag):
    return tag.rsplit("}", 1)[-1]


def source_files(root, ext):
    for d in SOURCE_DIRS:
        for dp, dns, fns in os.walk(os.path.join(root, d)):
            dns.sort()
            for fn in sorted(fns):
                if fn.lower().endswith(ext):
                    yield os.path.join(dp, fn)


class Globals:
    def __init__(self):
        self.defined, self.read = set(), set()
        self.errors = []

    def add_chunk(self, source, chunkname):
        code, err = luabytecode.compile_source(source, chunkname)
        if err:
            self.errors.append(err)
            return
        for kind, name, _ in luabytecode.globals_used(luabytecode.parse(code)):
            (self.defined if kind == "set" else self.read).add(name)


class Frames:
    def __init__(self):
        self.templates = {}
        self.names = set()

    def collect_templates(self, root):
        for el in root.iter():
            name = el.get("name")
            if name and el.get("virtual", "").lower() == "true":
                self.templates[name] = el
                if local_name(el.tag) == "Font":
                    self.names.add(name)

    def resolve(self, name, parent):
        if "$parent" in name.lower():
            if not parent:
                return None
            return re.sub(r"\$parent", parent, name, flags=re.I)
        return name

    def inherits(self, el):
        return [t.strip() for t in (el.get("inherits") or "").split(",") if t.strip()]

    def instantiate(self, template_names, owner, depth=0):
        if depth > 20:
            return
        for tname in template_names:
            tmpl = self.templates.get(tname)
            if tmpl is None:
                continue
            self.instantiate(self.inherits(tmpl), owner, depth + 1)
            for child in tmpl:
                self.walk(child, owner, depth + 1)

    def walk(self, el, parent, depth=0):
        if el.get("virtual", "").lower() == "true":
            return
        name = el.get("name")
        owner = parent
        if name:
            resolved = self.resolve(name, parent)
            if resolved:
                self.names.add(resolved)
                owner = resolved
        if name or el.get("inherits"):
            self.instantiate(self.inherits(el), owner if name else parent, depth)
        for child in el:
            self.walk(child, owner, depth)

    def create_from_lua(self, name, template):
        self.names.add(name)
        if template:
            self.instantiate([t.strip() for t in template.split(",")], name)


def parse_xml(path):
    with open(path, "rb") as f:
        data = f.read()
    if not data.strip():
        return None
    try:
        return ET.fromstring(data)
    except ET.ParseError as e:
        raise SystemExit("%s: %s" % (path, e))


def exe_lua_tables(path):
    with open(path, "rb") as f:
        data = f.read()
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe : pe + 4] != b"PE\0\0" or struct.unpack_from("<H", data, pe + 24)[0] != 0x10B:
        raise SystemExit("%s: not a 32-bit PE image" % path)
    nsec = struct.unpack_from("<H", data, pe + 6)[0]
    opt = pe + 24
    first = opt + struct.unpack_from("<H", data, pe + 20)[0]
    base = struct.unpack_from("<I", data, opt + 28)[0]
    sections = []
    for i in range(nsec):
        vsize, va, rsize, raw = struct.unpack_from("<IIII", data, first + i * 40 + 8)
        chars = struct.unpack_from("<I", data, first + i * 40 + 36)[0]
        sections.append((base + va, vsize, raw, rsize, bool(chars & 0x20000000)))

    def string_at(va):
        for sva, vsize, raw, rsize, _ in sections:
            if sva <= va < sva + min(vsize, rsize):
                m = IDENT.match(data, raw + va - sva)
                return m.group(0)[:-1].decode() if m else None
        return None

    def is_code(va):
        return any(code and sva <= va < sva + vsize for sva, vsize, _, _, code in sections)

    runs = []
    for sva, vsize, raw, rsize, code in sections:
        if code:
            continue
        n = min(vsize, rsize) // 4
        words = struct.unpack_from("<%dI" % n, data, raw)
        i = 0
        while i < n - 1:
            run, j = [], i
            while j < n - 1:
                name = string_at(words[j])
                if not name or not is_code(words[j + 1]):
                    break
                run.append((sva + j * 4, name))
                j += 2
            if len(run) >= 3:
                runs.append(run)
                i = j
            else:
                i += 1
    entries = {addr for run in runs for addr, _ in run}
    referenced = set()
    for sva, vsize, raw, rsize, code in sections:
        if not code:
            continue
        text = data[raw : raw + min(vsize, rsize)]
        for shift in range(4):
            usable = (len(text) - shift) // 4 * 4
            for (word,) in struct.iter_unpack("<I", text[shift : shift + usable]):
                if word in entries:
                    referenced.add(word)
    tables = []
    for run in runs:
        current = []
        for addr, name in run:
            if addr in referenced and current:
                tables.append(current)
                current = []
            current.append(name)
        tables.append(current)
    return tables


def collect_sources(root):
    g, frames = Globals(), Frames()
    lua_sources = []
    for path in source_files(root, ".lua"):
        with open(path, "rb") as f:
            src = f.read()
        lua_sources.append(src)
        g.add_chunk(src, "@" + os.path.relpath(path, root))
    trees = [(path, tree) for path in source_files(root, ".xml") for tree in [parse_xml(path)] if tree is not None]
    for _, tree in trees:
        frames.collect_templates(tree)
    for path, tree in trees:
        rel = os.path.relpath(path, root)
        frames.walk(tree, None)
        for el in tree.iter():
            tag = local_name(el.tag)
            body = (el.text or "").strip()
            if not body:
                continue
            if tag.startswith("On") or tag in ("PostClick", "PreClick", "Binding"):
                g.add_chunk("return function(%s)\n%s\nend" % (HANDLER_ARGS, body), "@%s:%s" % (rel, tag))
            elif tag == "Script":
                g.add_chunk(el.text, "@%s:Script" % rel)
    for src in lua_sources:
        for m in LITERAL_FRAME.finditer(src.decode("utf-8", "replace")):
            frames.create_from_lua(m.group(1), m.group(3))
    if g.errors:
        raise SystemExit("\n".join(g.errors))
    frames.names.update(ENGINE_FRAMES)
    return g, frames


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    root, exe = sys.argv[1], sys.argv[2]
    out_path = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "luacheck_std_wow335.lua")
    g, frames = collect_sources(root)
    api = set()
    for table in exe_lua_tables(exe):
        if sum(1 for name in table if name in g.read) >= API_TABLE_MIN_SHARE * len(table):
            library = any(name in LUA_LIBRARY_MARKERS for name in table)
            api.update(name for name in table if name[0].isupper() or not library)
    names = (g.defined | g.read | frames.names | api) - LUA_BUILTINS
    names = sorted(n for n in names if re.match(r"^[A-Za-z_]\w*$", n))
    lines = ["return {", "\tread_globals = {"]
    lines += ['\t\t"%s",' % n for n in names]
    lines += ["\t},", "}", ""]
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(
        "%d globals: %d defined in Lua, %d XML and Lua frames, %d read and not defined, %d C API (%d not used by FrameXML)"
        % (
            len(names),
            len(g.defined),
            len(frames.names),
            len(g.read - g.defined - frames.names),
            len(api),
            len(api - g.read - g.defined),
        )
    )


if __name__ == "__main__":
    main()
