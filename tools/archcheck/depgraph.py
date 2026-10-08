#!/usr/bin/env python3
"""Dependency graph for FrostAtomUI (track 01, architecture).

Collects per file:
  exports      ns.X / function ns.X / function ns:X, module tables (NewModule) and methods on them
  consumes     ns.X / ns:X (resolved to definer file), module methods via aliases, ns:GetModule
  config       ns.Config.<section>, GetConfig/SetConfig/WatchConfig/AnchorToConfig paths, configKey
  events       custom events fired / listened
  globals      named global frames created and referenced elsewhere
Outputs JSON + text tables.
"""
import json
import os
import re
import sys
from collections import defaultdict, Counter

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__))


def toc_files(toc_path, addon):
    files = []
    base = os.path.dirname(toc_path)
    with open(toc_path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            rel = line.replace("\\", "/")
            if rel.startswith("Libs/"):
                continue
            files.append(os.path.join(addon, rel))
    return files


CORE_FILES = toc_files(os.path.join(ROOT, "FrostAtomUI/FrostAtomUI.toc"), "FrostAtomUI")
CFG_FILES = toc_files(os.path.join(ROOT, "FrostAtomUI_Config/FrostAtomUI_Config.toc"), "FrostAtomUI_Config")
ALL_FILES = CORE_FILES + CFG_FILES
ORDER = {f: i for i, f in enumerate(ALL_FILES)}


# ---------------------------------------------------------------- lexing
def strip_lua(src):
    """Return (code, nostr): comments blanked; nostr also blanks string contents.
    Newlines preserved so offsets map to identical line numbers."""
    n = len(src)
    code = list(src)
    nostr = list(src)
    i = 0
    strings = []  # (start, end, value)

    def blank(arr, a, b):
        for k in range(a, b):
            if arr[k] != "\n":
                arr[k] = " "

    def long_bracket(pos):
        m = re.match(r"\[(=*)\[", src[pos:pos + 64])
        if not m:
            return None
        close = "]" + m.group(1) + "]"
        end = src.find(close, pos + len(m.group(0)))
        if end < 0:
            end = n
        else:
            end += len(close)
        return end, len(m.group(0)), len(close)

    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            lb = long_bracket(i + 2)
            if lb:
                end = lb[0]
            else:
                end = src.find("\n", i)
                if end < 0:
                    end = n
            blank(code, i, end)
            blank(nostr, i, end)
            i = end
            continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                elif src[j] == "\n":
                    break
                j += 1
            end = min(j + 1, n)
            strings.append((i, end, src[i + 1:end - 1]))
            blank(nostr, i + 1, end - 1)
            i = end
            continue
        if c == "[":
            lb = long_bracket(i)
            if lb:
                end, ol, cl = lb
                strings.append((i, end, src[i + ol:end - cl]))
                blank(nostr, i + ol, end - cl)
                i = end
                continue
        i += 1
    return "".join(code), "".join(nostr), strings


class LineIndex:
    def __init__(self, text):
        self.starts = [0]
        for m in re.finditer("\n", text):
            self.starts.append(m.end())

    def line(self, off):
        lo, hi = 0, len(self.starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.starts[mid] <= off:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1


def depth_map(nostr):
    """Approximate block depth per line using keywords (function/do/then/repeat vs end/until)."""
    depth = 0
    depths = []
    tok = re.compile(r"\b(function|do|then|repeat|end|until|elseif)\b")
    for line in nostr.split("\n"):
        depths.append(depth)
        for m in tok.finditer(line):
            w = m.group(1)
            if w in ("function", "do", "then", "repeat"):
                depth += 1
            elif w in ("end", "until"):
                depth -= 1
            elif w == "elseif":
                depth -= 1  # 'elseif ... then' re-opens
    return depths


# ---------------------------------------------------------------- component mapping
def component(path):
    if path.startswith("FrostAtomUI_Config/"):
        rest = path[len("FrostAtomUI_Config/"):]
        if rest.startswith("Pages/"):
            return "Config/Pages"
        return "Config/" + rest[:-4]
    rest = path[len("FrostAtomUI/"):]
    if rest.startswith("Core/"):
        return "Core/" + rest[5:-4]
    if rest.startswith("Locales/"):
        return "Locales"
    if rest.startswith("Modules/"):
        parts = rest[8:].split("/")
        if len(parts) == 1:
            return parts[0][:-4]
        return parts[0]
    return rest


# coarse layers (declared, used for "upward dependency" detection)
LAYER_OF = {}
L0 = ["Core/Init", "Core/Locale", "Locales", "Core/Util", "Core/Events", "Core/Pixel", "Core/Scheduler",
      "Core/Encode", "Core/DB", "Core/CVars", "Core/Bootstrap"]
L1 = ["Core/Skin", "Core/Media", "Core/Config", "Core/LayoutPresets", "Core/Movers", "Core/WorldChildren",
      "Core/PlateLayer", "Core/BubbleLayer", "CooldownTimer", "Core/Glyphs", "Core/GlyphData"]
L2 = ["CooldownData", "DRData", "LoseControlData", "SpellAlertData", "ProcData", "TotemData"]
L3 = ["Core/Auras", "Inspect", "Talents", "CooldownTracker", "InternalCooldowns",
      "DiminishingReturns", "HealPrediction"]
for c in L0:
    LAYER_OF[c] = 0
for c in L1:
    LAYER_OF[c] = 1
for c in L2:
    LAYER_OF[c] = 2
for c in L3:
    LAYER_OF[c] = 3
LAYER_NAMES = {0: "L0 platform", 1: "L1 framework/UI-kit", 2: "L2 data", 3: "L3 services",
               4: "L4 features", 5: "L5 settings UI"}


def layer(comp):
    if comp in LAYER_OF:
        return LAYER_OF[comp]
    if comp.startswith("Config/"):
        return 5
    return 4


# ---------------------------------------------------------------- per-file scan
ID = r"[A-Za-z_][A-Za-z0-9_]*"

files = {}
defs = defaultdict(list)          # ns symbol -> [(file, line)]
module_def = {}                   # module name -> file
module_methods = defaultdict(lambda: defaultdict(list))  # module -> method -> [(file,line)]
event_consts = {}                 # ns.CONST -> "string"
cfg_defs = defaultdict(list)      # config-addon ns symbol -> [(file,line)]
global_frames = {}                # name -> (file, line)

for path in ALL_FILES:
    full = os.path.join(ROOT, path)
    with open(full, encoding="utf-8") as fh:
        src = fh.read()
    code, nostr, strings = strip_lua(src)
    li = LineIndex(src)
    depths = depth_map(nostr)
    is_cfg = path.startswith("FrostAtomUI_Config/")
    core_name = r"(?:ui|FrostAtomUI)" if is_cfg else r"ns"
    rec = {
        "path": path, "comp": component(path), "lines": src.count("\n"), "cfg": is_cfg,
        "exports": [], "module_defs": [], "module_ext": [], "aliases": {}, "uses": [],
        "getmodule": [], "config_reads": [], "config_writes": [], "fires": [], "listens": [],
        "frames_created": [], "filescope_getmodule": [], "filescope_config": [],
        "filescope_frames": 0, "filescope_events": [], "cfg_exports": [],
    }
    files[path] = rec
    rec["_src"], rec["_code"], rec["_nostr"], rec["_li"], rec["_depths"] = src, code, nostr, li, depths

    # exports onto core ns (core files only)
    if not is_cfg:
        for m in re.finditer(r"(?m)^[ \t]*(?:local\s+)?function\s+ns([.:])(" + ID + r")((?:[.:]" + ID + r")*)\s*\(", nostr):
            sym = m.group(2)
            ln = li.line(m.start())
            rec["exports"].append((sym + m.group(3), ln))
            if not m.group(3):
                defs[sym].append((path, ln))
            else:
                rec.setdefault("extends", []).append((sym, m.group(3), ln))
        for m in re.finditer(r"(?<![.\w])ns\.(" + ID + r")((?:\." + ID + r")*)\s*=(?!=)", nostr):
            sym = m.group(1)
            ln = li.line(m.start())
            rec["exports"].append((sym + m.group(2), ln))
            if not m.group(2):
                defs[sym].append((path, ln))
                # event constant?
                tail = code[m.end():m.end() + 80]
                sm = re.match(r"\s*\"(FrostAtomUI_[A-Z_a-z0-9]+)\"", tail)
                if sm:
                    event_consts[sym] = sm.group(1)
            else:
                rec.setdefault("extends", []).append((sym, m.group(2), ln))
    else:
        for m in re.finditer(r"(?m)^[ \t]*function\s+ns([.:])(" + ID + r")\s*\(", nostr):
            cfg_defs[m.group(2)].append((path, li.line(m.start())))
            rec["cfg_exports"].append(m.group(2))
        for m in re.finditer(r"(?<![.\w])ns\.(" + ID + r")\s*=(?!=)", nostr):
            cfg_defs[m.group(1)].append((path, li.line(m.start())))
            rec["cfg_exports"].append(m.group(1))

    # module aliases
    for m in re.finditer(r"local\s+(" + ID + r")\s*=\s*" + core_name + r":NewModule\(\s*\"(" + ID + r")\"\s*\)", code):
        alias, mod = m.group(1), m.group(2)
        rec["aliases"][alias] = ("new", mod)
        rec["module_defs"].append(mod)
        module_def[mod] = path
    for m in re.finditer(r"local\s+(" + ID + r")\s*=\s*" + core_name + r":GetModule\(\s*\"(" + ID + r")\"\s*\)", code):
        alias, mod = m.group(1), m.group(2)
        ln = li.line(m.start())
        if alias not in rec["aliases"]:
            rec["aliases"][alias] = ("get", mod)
        if depths[ln - 1] == 0:
            rec["filescope_getmodule"].append((mod, ln))
    for m in re.finditer(core_name + r":GetModule\(\s*\"(" + ID + r")\"\s*\)", code):
        ln = li.line(m.start())
        rec["getmodule"].append((m.group(1), ln))
    for m in re.finditer(core_name + r":GetModule\(\s*(" + ID + r")\s*\)", code):  # dynamic
        rec.setdefault("dyn_getmodule", []).append((m.group(1), li.line(m.start())))

    # methods defined on module aliases
    for alias, (kind, mod) in rec["aliases"].items():
        pat = r"(?m)^[ \t]*(?:function\s+" + re.escape(alias) + r"([.:])(" + ID + r")\s*\(|" + re.escape(alias) + r"\.(" + ID + r")\s*=(?!=))"
        for m in re.finditer(pat, nostr):
            meth = m.group(2) or m.group(3)
            ln = li.line(m.start())
            module_methods[mod][meth].append((path, ln))
            if kind == "get":
                rec["module_ext"].append((mod, meth, ln))

    # local aliases of ns symbols:  local X = ns.Y  (consumption)
    rec["sym_alias"] = {}
    for m in re.finditer(r"local\s+(" + ID + r")\s*=\s*" + core_name + r"\.(" + ID + r")\s*(?:\n|$|--)", code):
        rec["sym_alias"][m.group(1)] = m.group(2)

    # config reads
    cfg_aliases = [a for a, s in rec["sym_alias"].items() if s == "Config"]
    for m in re.finditer(r"(?<![\w.])" + core_name + r"\.Config\.(" + ID + r")", nostr):
        rec["config_reads"].append((m.group(1), li.line(m.start()), "ns.Config"))
    for a in cfg_aliases:
        for m in re.finditer(r"(?<![\w.])" + re.escape(a) + r"\.(" + ID + r")", nostr):
            rec["config_reads"].append((m.group(1), li.line(m.start()), "alias"))
        for m in re.finditer(r"(?<![\w.])" + re.escape(a) + r"\[\s*(?:self\.)?(" + ID + r")", nostr):
            rec["config_reads"].append(("[" + m.group(1) + "]", li.line(m.start()), "alias-dyn"))
    for m in re.finditer(r"(?<![\w.])" + core_name + r"\.Config\[", nostr):
        rec["config_reads"].append(("[dyn]", li.line(m.start()), "ns.Config[]"))
    for m in re.finditer(r"(GetConfig|IsDefaultConfig|WatchConfig|AnchorToConfig|ApplyPoint)\(\s*(?:[A-Za-z_.]+\s*,\s*)?\"([A-Za-z0-9_]+)[.\"]", code):
        rec["config_reads"].append((m.group(2), li.line(m.start()), m.group(1)))
    for m in re.finditer(r"(SetConfig|ResetConfig)\(\s*\"([A-Za-z0-9_]+)[.\"]", code):
        rec["config_writes"].append((m.group(2), li.line(m.start()), m.group(1)))
    for m in re.finditer(r"configKey\s*=\s*\"(" + ID + r")\"", code):
        rec["configKey"] = m.group(1)
    if is_cfg:
        for m in re.finditer(r"\bpath\s*=\s*\"([A-Za-z0-9_]+)[.\"]", code):
            rec["config_writes"].append((m.group(1), li.line(m.start()), "schema"))

    # file-scope reads of ns.Config.X (before DB_LOADED → defaults only)
    for (sec, ln, how) in rec["config_reads"]:
        if depths[ln - 1] == 0 and how in ("ns.Config", "alias", "GetConfig"):
            rec["filescope_config"].append((sec, ln))

    # events fired / listened
    for m in re.finditer(r"(?<![\w.])" + core_name + r":Fire\(\s*(?:" + core_name + r"\.(" + ID + r")|\"([^\"]+)\"|(" + ID + r"))", code):
        ev = m.group(1) and ("ns." + m.group(1)) or (m.group(2) and '"' + m.group(2) + '"') or ("var:" + m.group(3))
        rec["fires"].append((ev, li.line(m.start())))
    for m in re.finditer(r":Register(?:Unit)?Event\(\s*(?:" + core_name + r"\.(" + ID + r")|\"(FrostAtomUI_[^\"]+)\")", code):
        ev = m.group(1) and ("ns." + m.group(1)) or ('"' + m.group(2) + '"')
        ln = li.line(m.start())
        rec["listens"].append((ev, ln))
    for m in re.finditer(r":WatchConfig\(|:AnchorToConfig\(", code):
        rec["listens"].append(("ns.CONFIG_CHANGED(watch)", li.line(m.start())))
    # file-scope event registration
    for m in re.finditer(r"(?m)^(" + ID + r"):RegisterEvent\(\s*(?:" + core_name + r"\.(" + ID + r")|\"([A-Z_]+)\")", code):
        ln = li.line(m.start())
        if depths[ln - 1] == 0:
            rec["filescope_events"].append((m.group(2) and "ns." + m.group(2) or m.group(3), ln))

    # named global frames created
    for m in re.finditer(r"CreateFrame\(\s*\"(" + ID + r")\"\s*,\s*(\"(" + ID + r")\"|ADDON_NAME\s*\.\.\s*\"(" + ID + r")\")", code):
        name = m.group(3) or (("FrostAtomUI_Config" if is_cfg else "FrostAtomUI") + m.group(4))
        ln = li.line(m.start())
        rec["frames_created"].append((name, ln))
        global_frames.setdefault(name, (path, ln))
    for m in re.finditer(r"(?m)^(?:local\s+)?" + ID + r"\s*=\s*CreateFrame\(", code):
        ln = li.line(m.start())
        if depths[ln - 1] == 0:
            rec["filescope_frames"] += 1
    rec["filescope_frames_total"] = sum(1 for m in re.finditer(r"CreateFrame\(", code) if depths[li.line(m.start()) - 1] == 0)

# ---------------------------------------------------------------- resolve consumption
def definer(sym):
    lst = defs.get(sym)
    if not lst:
        return None
    return min(lst, key=lambda d: ORDER[d[0]])[0]


edges = defaultdict(lambda: defaultdict(list))   # src file -> dst file -> [reasons]
unresolved = Counter()

for path, rec in files.items():
    nostr, li, depths = rec["_nostr"], rec["_li"], rec["_depths"]
    is_cfg = rec["cfg"]
    core_name = r"(?:ui|FrostAtomUI)" if is_cfg else r"ns"
    own = {e[0].split(".")[0].split(":")[0] for e in rec["exports"]}
    # ns.X / ns:X
    for m in re.finditer(r"(?<![\w.])" + core_name + r"([.:])(" + ID + r")", nostr):
        sym = m.group(2)
        if sym in ("GetModule", "NewModule"):
            continue
        d = definer(sym)
        ln = li.line(m.start())
        if d is None:
            unresolved[(sym, path)] += 1
            continue
        if d != path:
            edges[path][d].append(("sym", sym, ln, depths[ln - 1] == 0))
        rec["uses"].append((sym, ln))
    # GetModule("X") → module file (+ method resolution)
    for mod, ln in rec["getmodule"]:
        d = module_def.get(mod)
        if d and d != path:
            edges[path][d].append(("module", mod, ln, depths[ln - 1] == 0))
    # alias.method usage → defining file of the method
    for alias, (kind, mod) in rec["aliases"].items():
        if kind != "get":
            continue
        for m in re.finditer(r"(?<![\w.])" + re.escape(alias) + r"([.:])(" + ID + r")", nostr):
            meth = m.group(2)
            ln = li.line(m.start())
            locs = module_methods.get(mod, {}).get(meth)
            if locs:
                for (f, _l) in locs:
                    if f != path:
                        edges[path][f].append(("method", mod + "." + meth, ln, depths[ln - 1] == 0))
    # inline ns:GetModule("X"):Method / .Field
    for m in re.finditer(core_name + r":GetModule\(\s*\"(" + ID + r")\"\s*\)([.:])(" + ID + r")", rec["_code"]):
        mod, meth = m.group(1), m.group(3)
        ln = li.line(m.start())
        rec.setdefault("inline_module_calls", []).append((mod, meth, ln))
        for (f, _l) in module_methods.get(mod, {}).get(meth, []):
            if f != path:
                edges[path][f].append(("method", mod + "." + meth, ln, depths[ln - 1] == 0))
    # config sections → owner (section defined in Defaults; owner = module with configKey or schema)
# custom events: who fires / who listens
ev_fire = defaultdict(set)
ev_listen = defaultdict(set)
for path, rec in files.items():
    for ev, ln in rec["fires"]:
        ev_fire[ev].add(rec["comp"])
    for ev, ln in rec["listens"]:
        ev_listen[ev.replace("(watch)", "")].add(rec["comp"])

# global frame references from other files
frame_refs = defaultdict(list)
for name, (dfile, dln) in global_frames.items():
    pat = re.compile(r"(?<![\w.\"])" + re.escape(name) + r"(?![\w])")
    spat = re.compile(r"\"" + re.escape(name) + r"\"")
    for path, rec in files.items():
        if path == dfile:
            continue
        hits = [rec["_li"].line(m.start()) for m in pat.finditer(rec["_nostr"])]
        hits += [rec["_li"].line(m.start()) for m in spat.finditer(rec["_code"])]
        if hits:
            frame_refs[name].append((path, sorted(set(hits))))
            for h in hits:
                edges[path][dfile].append(("gframe", name, h, False))

# ---------------------------------------------------------------- aggregate by component
comp_edges = defaultdict(Counter)
comp_edge_kinds = defaultdict(lambda: defaultdict(Counter))
for src, dsts in edges.items():
    cs = files[src]["comp"]
    for dst, reasons in dsts.items():
        cd = files[dst]["comp"]
        if cs == cd:
            continue
        comp_edges[cs][cd] += len(reasons)
        for r in reasons:
            comp_edge_kinds[cs][cd][r[0]] += 1

comps = sorted({r["comp"] for r in files.values()}, key=lambda c: min(ORDER[f] for f, r in files.items() if r["comp"] == c))
fan_out = {c: len(comp_edges[c]) for c in comps}
fan_in = Counter()
for cs, dd in comp_edges.items():
    for cd in dd:
        fan_in[cd] += 1
comp_lines = Counter()
comp_files = Counter()
for r in files.values():
    comp_lines[r["comp"]] += r["lines"]
    comp_files[r["comp"]] += 1

# cycles (Tarjan SCC on component graph)
def tarjan(nodes, adj):
    index = {}
    low = {}
    stack = []
    on = set()
    res = []
    counter = [0]
    sys.setrecursionlimit(10000)

    def strong(v):
        index[v] = low[v] = counter[0]
        counter[0] += 1
        stack.append(v)
        on.add(v)
        for w in adj.get(v, ()):
            if w not in index:
                strong(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            res.append(comp)

    for v in nodes:
        if v not in index:
            strong(v)
    return res


sccs = [s for s in tarjan(comps, {c: list(comp_edges[c].keys()) for c in comps}) if len(s) > 1]
file_adj = {f: [d for d in edges[f].keys()] for f in files}
file_sccs = [s for s in tarjan(list(files.keys()), file_adj) if len(s) > 1]

# upward deps (lower layer depends on higher layer)
upward = []
for cs, dd in comp_edges.items():
    for cd, n in dd.items():
        if layer(cs) < layer(cd):
            upward.append((cs, cd, n, layer(cs), layer(cd)))
upward.sort(key=lambda x: (x[3], -x[2]))

# load-order inversions: file uses symbol/module defined in a later file at FILE SCOPE (definite failure)
# or anywhere (runtime-only, relies on Initialize ordering)
inversions = []
for src, dsts in edges.items():
    for dst, reasons in dsts.items():
        if files[src]["cfg"] != files[dst]["cfg"]:
            continue
        if ORDER[dst] > ORDER[src]:
            fs = [r for r in reasons if r[3]]
            inversions.append((src, dst, len(reasons), len(fs), reasons[:3], fs[:3]))

# config section ownership
section_owner = {}
for path, rec in files.items():
    if rec.get("configKey"):
        section_owner.setdefault(rec["configKey"], rec["comp"])
# sections referenced by components
sec_users = defaultdict(lambda: defaultdict(set))
for path, rec in files.items():
    if rec["cfg"]:
        continue
    for sec, ln, how in rec["config_reads"]:
        sec_users[sec][rec["comp"]].add(ln)

# ---------------------------------------------------------------- core <-> config boundary
cfg_core_syms = Counter()
cfg_core_sym_files = defaultdict(set)
cfg_module_calls = []
for path, rec in files.items():
    if not rec["cfg"]:
        continue
    for sym, ln in rec["uses"]:
        cfg_core_syms[sym] += 1
        cfg_core_sym_files[sym].add(path)
    for mod, ln in rec["getmodule"]:
        cfg_module_calls.append((path, ln, mod))
    for alias, (kind, mod) in rec["aliases"].items():
        pass

# ---------------------------------------------------------------- report
def w(fh, *a):
    print(*a, file=fh)


with open(os.path.join(OUT, "depgraph.txt"), "w", encoding="utf-8") as fh:
    w(fh, "FILES:", len(files), "core:", len(CORE_FILES), "config:", len(CFG_FILES))
    w(fh, "ns symbols defined:", len(defs), " modules:", len(module_def), " event consts:", len(event_consts))
    multi = {s: l for s, l in defs.items() if len({f for f, _ in l}) > 1}
    w(fh, "\n== ns symbols defined in >1 file ==")
    for s, l in sorted(multi.items()):
        w(fh, " ", s, sorted({f"{f}:{ln}" for f, ln in l}))
    w(fh, "\n== exports per component (top-level ns symbols) ==")
    exp_by_comp = Counter()
    for s, l in defs.items():
        d = definer(s)
        exp_by_comp[files[d]["comp"]] += 1
    for c, n in exp_by_comp.most_common():
        w(fh, f"  {c:28s} {n}")
    w(fh, "\n== component table: lines, files, fan-out, fan-in, layer ==")
    w(fh, f"  {'component':28s} {'lines':>6s} {'files':>5s} {'out':>4s} {'in':>4s}  layer")
    for c in sorted(comps, key=lambda c: -(fan_in[c] + fan_out[c])):
        w(fh, f"  {c:28s} {comp_lines[c]:6d} {comp_files[c]:5d} {fan_out[c]:4d} {fan_in[c]:4d}  {LAYER_NAMES[layer(c)]}")
    w(fh, "\n== component edges (src -> dst : refs [kinds]) ==")
    for cs in comps:
        for cd, n in comp_edges[cs].most_common():
            w(fh, f"  {cs} -> {cd}: {n} {dict(comp_edge_kinds[cs][cd])}")
    w(fh, "\n== SCCs (cycles) on component graph ==")
    for s in sccs:
        w(fh, "  ", len(s), sorted(s))
    w(fh, "\n== SCCs on file graph ==")
    for s in file_sccs:
        w(fh, "  ", len(s), sorted(s))
    w(fh, "\n== upward dependencies (lower layer -> higher layer) ==")
    for cs, cd, n, ls, ld in upward:
        w(fh, f"  [{ls}->{ld}] {cs} -> {cd}: {n}")
        # detail
        for src, dsts in edges.items():
            if files[src]["comp"] != cs:
                continue
            for dst, reasons in dsts.items():
                if files[dst]["comp"] == cd:
                    for r in reasons[:6]:
                        w(fh, f"        {src}:{r[2]} {r[0]} {r[1]}")
    w(fh, "\n== load-order inversions (file uses something defined LATER in TOC) ==")
    for src, dst, n, nfs, rs, fs in sorted(inversions, key=lambda x: (-x[3], ORDER[x[0]])):
        w(fh, f"  {src} -> {dst}: {n} refs, file-scope {nfs}; e.g. {[(r[0], r[1], r[2]) for r in rs]} fs={[(r[0], r[1], r[2]) for r in fs]}")
    w(fh, "\n== modules: definer + extension files (methods attached from other files) ==")
    ext = defaultdict(lambda: defaultdict(int))
    for path, rec in files.items():
        for mod, meth, ln in rec["module_ext"]:
            ext[mod][path] += 1
    for mod in sorted(module_def):
        exts = ext.get(mod, {})
        nmeth = len(module_methods[mod])
        w(fh, f"  {mod:20s} def={module_def[mod]}  methods={nmeth}  ext_files={len(exts)} {dict(exts) if exts else ''}")
    w(fh, "\n== GetModule targets: number of distinct files fetching each module ==")
    gm = defaultdict(set)
    gm_fs = defaultdict(set)
    for path, rec in files.items():
        for mod, ln in rec["getmodule"]:
            gm[mod].add(path)
        for mod, ln in rec["filescope_getmodule"]:
            gm_fs[mod].add(path)
    for mod, s in sorted(gm.items(), key=lambda x: -len(x[1])):
        w(fh, f"  {mod:20s} files={len(s):3d} filescope={len(gm_fs[mod]):3d}  {sorted({files[p]['comp'] for p in s})}")
    w(fh, "\n== dynamic GetModule ==")
    for path, rec in files.items():
        for v, ln in rec.get("dyn_getmodule", []):
            w(fh, f"  {path}:{ln} GetModule({v})")
    w(fh, "\n== custom events ==")
    w(fh, "  constants:", event_consts)
    allev = set(ev_fire) | set(ev_listen)
    for ev in sorted(allev):
        w(fh, f"  {ev:40s} fire={sorted(ev_fire.get(ev, []))}  listen={sorted(ev_listen.get(ev, []))}")
    w(fh, "\n== named global frames referenced from other files ==")
    for name, refs in sorted(frame_refs.items()):
        w(fh, f"  {name} (def {global_frames[name][0]}:{global_frames[name][1]}) <- {[(p, l[:4]) for p, l in refs]}")
    w(fh, "\n== config sections read by components other than owner ==")
    for sec in sorted(sec_users):
        users = sec_users[sec]
        if len(users) > 1 or (section_owner.get(sec) and section_owner.get(sec) not in users):
            w(fh, f"  {sec:22s} owner={section_owner.get(sec)}  users={ {c: sorted(l)[:4] for c, l in users.items()} }")
    w(fh, "\n== file-scope ns.Config reads (evaluated with Defaults before DB_LOADED) ==")
    for path, rec in files.items():
        if rec["filescope_config"]:
            w(fh, f"  {path}: {rec['filescope_config'][:8]}")
    w(fh, "\n== file-scope frames / events per file (load-time side effects) ==")
    tot_frames = 0
    for path, rec in files.items():
        tot_frames += rec["filescope_frames_total"]
        if rec["filescope_frames_total"] or rec["filescope_events"]:
            w(fh, f"  {path}: frames={rec['filescope_frames_total']} events={rec['filescope_events'][:6]}")
    w(fh, "  TOTAL file-scope CreateFrame calls:", tot_frames)
    w(fh, "\n== Config addon -> core symbols (count, files) ==")
    for sym, n in cfg_core_syms.most_common():
        w(fh, f"  {sym:28s} {n:4d}  def={definer(sym)}  files={len(cfg_core_sym_files[sym])}")
    w(fh, "\n== Config addon GetModule calls ==")
    for p, ln, mod in cfg_module_calls:
        w(fh, f"  {p}:{ln} {mod}")
    w(fh, "\n== Config addon inline module calls ==")
    for path, rec in files.items():
        if rec["cfg"]:
            for x in rec.get("inline_module_calls", []):
                w(fh, f"  {path}:{x[2]} {x[0]}.{x[1]}")
    w(fh, "\n== core files that extend ns tables of other files (ns.X.Y = / function ns.X:Y) ==")
    for path, rec in files.items():
        for sym, tail, ln in rec.get("extends", []):
            d = definer(sym)
            if d and d != path:
                w(fh, f"  {path}:{ln} ns.{sym}{tail}  (X defined in {d})")
    w(fh, "\n== unresolved ns symbols (used but no definition found) ==")
    for (sym, path), n in sorted(unresolved.items()):
        w(fh, f"  {sym} in {path} x{n}")

# json dump for later use
dump = {
    "comp_edges": {c: dict(d) for c, d in comp_edges.items()},
    "comp_lines": comp_lines, "fan_in": fan_in, "fan_out": fan_out,
    "layers": {c: layer(c) for c in comps},
    "file_edges": {s: {d: len(r) for d, r in dd.items()} for s, dd in edges.items()},
}
with open(os.path.join(OUT, "depgraph.json"), "w", encoding="utf-8") as fh:
    json.dump(dump, fh, indent=1, default=list)
print("ok", len(files), "files")
