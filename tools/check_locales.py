"""Localization lint: missing and duplicate keys, EN <-> RU placeholders and escapes, Latin letters in Cyrillic words."""
import os
import re
import sys

from report import Report

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
ROOT = os.path.abspath(ARGS[0] if ARGS else os.path.join(os.path.dirname(__file__), ".."))
STRICT = "--strict" in sys.argv
LOCALE_FILES = {"ruRU": "FrostAtomUI/Locales/ruRU.lua"}
CODE_DIRS = ("FrostAtomUI", "FrostAtomUI_Config")
SKIP = ("/Libs/", "/Locales/")
CORE_ADDON = "FrostAtomUI/"
TRANSLATED_LITERALS = {
    "FrostAtomUI/Core/SetupPresets.lua": (
        re.compile(r'\b(?:name|desc) = "([^"]+)"'),
        re.compile(r'^\t\["[\w.]+"\] = "([^"]+)",$', re.M),
        re.compile(r'^\t\w+ = "([^"]+)",$', re.M),
    ),
    "FrostAtomUI/Modules/Chat/Chat.lua": (re.compile(r'\{ (?:"\w+"|nil), "(\[[^"]+\])" \}'),),
}
GENERATED = re.compile(r"^(Arena opponent|Party member) %d( (castbar|cooldowns|pet|pet castbar|target|target castbar))?$")
SPEC = re.compile(r"%(%|[-+#0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs])")
BAD_PCT = re.compile(r"%(?![-+#0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs])")
KW = set(
    "and break do else elseif end false for function if in local nil not or repeat return then true until while".split()
)
CYR = "А-Яа-яЁё"

report = Report("check_locales")


def lex(src):
    i, n, line, out = 0, len(src), 1, []
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i : i + 64])
            if m:
                j = src.find("]" + m.group(1) + "]", i)
                j = n if j < 0 else j
                line += src.count("\n", i, j)
                i = j + len(m.group(1)) + 2
                continue
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", src[i : i + 64])
        if m:
            close = "]" + m.group(1) + "]"
            s = i + len(m.group(0))
            j = src.find(close, s)
            body = src[s:j]
            body = body[1:] if body.startswith("\n") else body
            out.append(("S", body, line))
            line += src.count("\n", i, j)
            i = j + len(close)
            continue
        if c in "\"'":
            j, buf = i + 1, []
            while src[j] != c:
                if src[j] == "\\":
                    e = src[j + 1]
                    if e.isdigit():
                        k = j + 1
                        while k < j + 4 and src[k].isdigit():
                            k += 1
                        buf.append(chr(int(src[j + 1 : k])))
                        j = k
                        continue
                    buf.append({"n": "\n", "t": "\t", "r": "\r", "\n": "\n"}.get(e, e))
                    j += 2
                    continue
                buf.append(src[j])
                j += 1
            out.append(("S", "".join(buf), line))
            line += src.count("\n", i, j)
            i = j + 1
            continue
        m = re.match(r"[A-Za-z_]\w*", src[i : i + 128])
        if m:
            w = m.group(0)
            out.append(("K" if w in KW else "N", w, line))
            i += len(w)
            continue
        m = re.match(r"0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?", src[i : i + 64])
        if m:
            out.append(("D", m.group(0), line))
            i += len(m.group(0))
            continue
        if src.startswith("...", i):
            op = "..."
        elif src[i : i + 2] in ("..", "==", "~=", "<=", ">="):
            op = src[i : i + 2]
        else:
            op = c
        out.append(("O", op, line))
        i += len(op)
    return out


def specs(s):
    return [m.group(0) for m in SPEC.finditer(s) if m.group(0) != "%%"]


def lua_files():
    for base in CODE_DIRS:
        for dp, _, fns in os.walk(os.path.join(ROOT, base)):
            for fn in sorted(fns):
                p = os.path.join(dp, fn)
                rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
                if fn.endswith(".lua") and not any(s in "/" + rel for s in SKIP):
                    yield p, rel


def scan_code():
    used, literals, filescope = {}, set(), []
    for p, rel in lua_files():
        with open(p, encoding="utf-8") as f:
            text = f.read()
        for pattern in TRANSLATED_LITERALS.get(rel, ()):
            for m in pattern.finditer(text):
                used.setdefault(m.group(1), []).append((rel, text.count("\n", 0, m.start()) + 1))
        t = lex(text)
        depth = []
        for i, (k, v, ln) in enumerate(t):
            if k == "K":
                if v == "function":
                    depth.append("F")
                elif v in ("if", "do", "repeat"):
                    depth.append("B")
                elif v in ("end", "until") and depth:
                    depth.pop()
            if k == "S":
                literals.add(v)
            if (
                k == "N"
                and v == "L"
                and i + 3 < len(t)
                and t[i + 1][1] == "["
                and t[i - 1][1] != ":"
                and (t[i - 1][1] != "." or t[i - 2][1] in ("ns", "ui", "FrostAtomUI"))
                and t[i + 2][0] == "S"
                and t[i + 3][1] == "]"
            ):
                used.setdefault(t[i + 2][1], []).append((rel, ln))
                if "F" not in depth and rel.startswith(CORE_ADDON):
                    filescope.append((rel, ln, t[i + 2][1]))
    return used, literals, filescope


def load_locale(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        t = lex(f.read())
    defs = {}
    for i in range(len(t) - 4):
        if t[i][1] == "[" and t[i + 1][0] == "S" and t[i + 2][1] == "]" and t[i + 3][1] == "=" and t[i + 4][0] == "S":
            k, v, ln = t[i + 1][1], t[i + 4][1], t[i][2]
            if k in defs:
                report.error("duplicate key %r, first on line %d" % (k, defs[k][1]), path, ln)
            else:
                defs[k] = (v, ln)
    return defs


def check_translation(path, k, v, ln):
    if [x.replace("q", "s") for x in specs(k)] != [x.replace("q", "s") for x in specs(v)]:
        report.error("placeholders differ: %s vs %s in %r" % (specs(k), specs(v), k), path, ln)
    if BAD_PCT.search(v.replace("%%", "")) and not BAD_PCT.search(k.replace("%%", "")):
        report.error("bare '%%' in the translation %r, write %%%%" % v, path, ln)
    for word in re.findall("[A-Za-z%s]+" % CYR, SPEC.sub(" ", v)):
        if re.search("[%s]" % CYR, word) and re.search("[A-Za-z]", word):
            report.error("Latin letters inside the Cyrillic word %r" % word, path, ln)
    if re.search("[%s]" % CYR, k):
        report.error("Cyrillic inside the English key %r" % k, path, ln)
    for open_tag, close_tag in (("|c", "|r"), ("|T", "|t"), ("|H", "|h")):
        if (k.count(open_tag), k.count(close_tag)) != (v.count(open_tag), v.count(close_tag)):
            report.error("%s...%s escape count differs from the key %r" % (open_tag, close_tag, k), path, ln)
    if k.count("\n") != v.count("\n"):
        report.warning("line break count differs from the key %r" % k, path, ln)
    if (k != k.strip()) != (v != v.strip()):
        report.warning("leading/trailing space differs from the key %r" % k, path, ln)
    if re.search(r"%[-0-9.]*d (?!(с|мс|мин|ч|сек|на|за|из|до|от|и|в|по)\b)[а-яё]", v):
        report.warning("number + noun, check the Russian plural: %r" % v, path, ln)


def main():
    used, literals, filescope = scan_code()
    for rel, ln, key in filescope:
        if sum(1 for loc in used[key] if loc[0] == rel) < 2:
            report.error("L[%r] runs at file load, before ns.ApplyLocale: the value stays English" % key, rel, ln)
    for loc, path in LOCALE_FILES.items():
        defs = load_locale(path)
        for k in sorted(used):
            if k not in defs and re.search("[A-Za-z]", SPEC.sub("", k)):
                rel, ln = used[k][0]
                report.warning("[%s] missing translation: %r" % (loc, k), rel, ln)
        for k, (v, ln) in defs.items():
            check_translation(path, k, v, ln)
            if k not in used and k not in literals and not GENERATED.match(k):
                report.warning("unused key %r" % k, path, ln)
    report.finish(STRICT)


if __name__ == "__main__":
    main()
