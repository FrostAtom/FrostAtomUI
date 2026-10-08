"""Repository invariants: TOC <-> disk, UTF-8 without BOM and LF, Lua 5.1 syntax and limits, retail-only API, settings addon boundary."""
import os
import re
import subprocess
import sys

import luabytecode
from report import Report

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
ADDONS = ("FrostAtomUI", "FrostAtomUI_Config")
TEXT_EXT = (".lua", ".toc", ".xml")
LOCALS_WARN, LOCALS_MAX = 185, 200
UPVALUES_WARN, UPVALUES_MAX = 55, 60
RETAIL_METHODS = {
    "SetShown": "use ns.SetShown",
    "SetColorTexture": "use SetTexture(r, g, b, a)",
    "SetAtlas": "no atlases in 3.3.5",
    "SetResizeBounds": "use SetMinResize/SetMaxResize",
    "SetObeyStepOnDrag": "",
    "SetClipsChildren": "",
    "SetIgnoreParentScale": "",
    "SetSnapToPixelGrid": "",
    "SetTexelSnappingBias": "",
    "SetFromAlpha": "use SetChange on Alpha animations",
    "SetToAlpha": "use SetChange on Alpha animations",
    "SetScaleFrom": "",
    "SetScaleTo": "",
    "SetMask": "",
    "SetPropagateKeyboardInput": "",
    "SetFixedFrameStrata": "",
    "SetFixedFrameLevel": "",
}
RETAIL_STRINGS = {"BackdropTemplate": "retail template, 3.3.5 frames have SetBackdrop built in"}
CONFIG_BOUNDARY = [
    (re.compile(r"\bGetModule\b"), "modules are reached through ns.API actions and previews"),
    (re.compile(r"\.db\b"), "saved state goes through ns.API.GetUIState / SetUIState / UIStore"),
    (re.compile(r"\.Defaults\b"), "defaults go through GetFactoryConfig or ns.API.FactoryValue"),
    (re.compile(r"\.Config\b"), "settings go through GetConfig"),
    (re.compile(r"\bSlashCmdList\."), "commands go through ns.API.RunAction"),
    (re.compile(r"\bui\.\w+Data\b"), "spell data goes through ns.API.Catalog"),
]
STORAGE_OWNER = "FrostAtomUI/Core/Storage.lua"
COMBAT_LOG_OWNER = "FrostAtomUI/Core/CombatLog.lua"
COMBAT_LOG_ACCESS = re.compile(r'RegisterEvent\(\s*"COMBAT_LOG_EVENT_UNFILTERED"')
STORAGE_ACCESS = re.compile(r"\bns\.db\b|\bSaveVariable\b|\bFrostAtomUIDB\b|\bLoadSavedVariables\b")

GLYPH_DATA = "FrostAtomUI/Core/GlyphData.lua"
GLYPH_USE = re.compile(r'(?:[Cc]reateGlyph|[Ss]etGlyph|[Cc]reateGlyphButton|\b[Gg]lyph)\([^"\n]*?"([a-z0-9-]+)"|\bglyph\s*=\s*"([a-z0-9-]+)"')

report = Report("check_repo")


def repo_files():
    out = subprocess.run(
        ["git", "ls-files", "--eol", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
        capture_output=True,
        check=True,
    ).stdout.decode("utf-8")
    files = {}
    for entry in out.split("\0"):
        if "\t" not in entry:
            continue
        info, path = entry.split("\t", 1)
        if os.path.isfile(os.path.join(ROOT, path)):
            files[path] = info.split()
    return files


def read(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return f.read()


def toc_entries(addon):
    toc = "%s/%s.toc" % (addon, addon)
    listed = []
    for n, line in enumerate(read(toc).decode("utf-8", "replace").split("\n"), 1):
        line = line.strip()
        if line and not line.startswith("#"):
            listed.append((addon + "/" + line.replace("\\", "/"), n))
    return toc, listed


def xml_includes(rel):
    base = os.path.dirname(rel)
    text = read(rel).decode("utf-8", "replace")
    for m in re.finditer(r'<(?:Script|Include)\s+file\s*=\s*"([^"]+)"', text):
        yield os.path.normpath(os.path.join(base, m.group(1).replace("\\", "/"))).replace("\\", "/")


def check_tocs(files):
    by_lower = {p.lower(): p for p in files}
    for addon in ADDONS:
        toc, listed = toc_entries(addon)
        seen, loaded = {}, set()
        queue = []
        for path, n in listed:
            key = path.lower()
            if key in seen:
                report.error("duplicate entry %s (first on line %d)" % (path, seen[key]), toc, n)
            seen.setdefault(key, n)
            if key not in by_lower:
                report.error("lists a missing file %s" % path, toc, n)
            else:
                queue.append(by_lower[key])
        while queue:
            path = queue.pop()
            if path.lower() in loaded:
                continue
            loaded.add(path.lower())
            if path.endswith(".xml"):
                for inc in xml_includes(path):
                    if inc.lower() in by_lower:
                        queue.append(by_lower[inc.lower()])
                    else:
                        report.error("includes a missing file %s" % inc, path)
        for p in files:
            if p == addon + "/Bindings.xml":
                continue
            if p.startswith(addon + "/") and p.endswith((".lua", ".xml")) and p.lower() not in loaded:
                report.error("not loaded by %s (dead file or forgotten TOC entry)" % toc, p)


def check_encoding(files):
    for p, info in files.items():
        if not (p.endswith(TEXT_EXT) or p == ".luacheckrc"):
            continue
        data = read(p)
        if data.startswith(b"\xef\xbb\xbf"):
            report.error("UTF-8 BOM", p, 1)
        index_eol = info[0][2:]
        normalized = "eol=lf" in " ".join(info[2:])
        if index_eol in ("crlf", "mixed") or (b"\r" in data and not normalized):
            report.error("CR line endings", p, data[: data.index(b"\r")].count(b"\n") + 1 if b"\r" in data else None)
        try:
            data.decode("utf-8")
        except UnicodeDecodeError as e:
            report.error("not UTF-8 (%s)" % e, p, data[: e.start].count(b"\n") + 1)


def check_lua(files):
    for p in files:
        if not p.endswith(".lua") or "/Libs/" in p:
            continue
        code, err = luabytecode.compile_file(os.path.join(ROOT, p), "@" + p)
        if err:
            m = re.match(r"(?:[^:]*):(\d+): (.*)", err, re.S)
            report.error(m.group(2) if m else err, p, int(m.group(1)) if m else None)
            continue
        chunk = luabytecode.parse(code)
        for proto in luabytecode.walk(chunk):
            line = proto.line or 1
            n = luabytecode.peak_locals(proto)
            if n >= LOCALS_MAX:
                report.error("%d active locals, Lua 5.1 stops compiling at %d" % (n, LOCALS_MAX + 1), p, line)
            elif n >= LOCALS_WARN:
                report.warning("%d active locals of %d allowed by Lua 5.1" % (n, LOCALS_MAX), p, line)
            if proto.nups >= UPVALUES_MAX:
                report.error("%d upvalues, Lua 5.1 allows %d" % (proto.nups, UPVALUES_MAX), p, line)
            elif proto.nups >= UPVALUES_WARN:
                report.warning("%d upvalues of %d allowed by Lua 5.1" % (proto.nups, UPVALUES_MAX), p, line)
        for kind, name, line in luabytecode.globals_used(chunk):
            if re.match(r"C_[A-Z]", name):
                report.error("retail namespace %s does not exist in 3.3.5" % name, p, line)
        for name, line in luabytecode.method_calls(chunk):
            if name in RETAIL_METHODS:
                hint = RETAIL_METHODS[name]
                report.error("retail-only method :%s()%s" % (name, ", " + hint if hint else ""), p, line)
        for s in set(luabytecode.string_constants(chunk)):
            if s in RETAIL_STRINGS:
                report.error('"%s": %s' % (s, RETAIL_STRINGS[s]), p)


def check_config_boundary(files):
    for p in files:
        if not (p.startswith("FrostAtomUI_Config/") and p.endswith(".lua")):
            continue
        for n, line in enumerate(read(p).decode("utf-8", "replace").split("\n"), 1):
            code = re.sub(r"--.*$", "", re.sub(r'"(?:[^"\\]|\\.)*"|' + r"'(?:[^'\\]|\\.)*'", '""', line))
            for pattern, hint in CONFIG_BOUNDARY:
                if pattern.search(code):
                    report.error("settings addon reaches into the core (%s): %s" % (pattern.pattern, hint), p, n)


def check_storage(files):
    for p in files:
        if not (p.startswith("FrostAtomUI/") and p.endswith(".lua")) or p.startswith("FrostAtomUI/Libs/"):
            continue
        for n, line in enumerate(read(p).decode("utf-8", "replace").split("\n"), 1):
            code = re.sub(r"--.*$", "", re.sub(r'"(?:[^"\\]|\\.)*"|' + r"'(?:[^'\\]|\\.)*'", '""', line))
            if p != STORAGE_OWNER and STORAGE_ACCESS.search(code):
                report.error("saved variables are reached only through ns.Storage slots", p, n)
            if p != COMBAT_LOG_OWNER and COMBAT_LOG_ACCESS.search(line):
                report.error("the combat log is reached through ns.CombatLog.Register", p, n)


def check_glyphs(files):
    known = set(re.findall(r'\["([^"]+)"\]', read(GLYPH_DATA).decode("utf-8")))
    for p in files:
        if not p.endswith(".lua") or p == GLYPH_DATA or not p.startswith(("FrostAtomUI/", "FrostAtomUI_Config/")):
            continue
        for n, line in enumerate(read(p).decode("utf-8", "replace").split("\n"), 1):
            for m in GLYPH_USE.finditer(line):
                name = m.group(1) or m.group(2)
                if name not in known:
                    report.error("glyph \"%s\" is not in Core/GlyphData.lua" % name, p, n)


def main():
    files = repo_files()
    check_tocs(files)
    check_encoding(files)
    check_lua(files)
    check_config_boundary(files)
    check_storage(files)
    check_glyphs(files)
    report.finish()


if __name__ == "__main__":
    main()
