"""Both TOCs carry the same ## Version, and every settings `new = "x.y.z"` marker is not newer than it.

Usage: check_versions.py [root] [--release] [--tag vX.Y.Z]; markers newer than the TOC are errors only with --release.
"""
import os
import re
import sys

from report import Report

ARGS = sys.argv[1:]
RELEASE = "--release" in ARGS
TAG = ARGS[ARGS.index("--tag") + 1] if "--tag" in ARGS else None
POSITIONAL = [a for i, a in enumerate(ARGS) if not a.startswith("--") and (i == 0 or ARGS[i - 1] != "--tag")]
ROOT = os.path.abspath(POSITIONAL[0] if POSITIONAL else os.path.join(os.path.dirname(__file__), ".."))
TOCS = ("FrostAtomUI/FrostAtomUI.toc", "FrostAtomUI_Config/FrostAtomUI_Config.toc")
MARKER_DIR = "FrostAtomUI_Config"
VERSION = re.compile(r"^\d+\.\d+\.\d+$")
MARKER = re.compile(r'\bnew\s*=\s*((?:[^,}"\n]|"[^"\n]*")*)')

report = Report("check_versions")


def parse(v):
    return tuple(int(x) for x in v.split("."))


def toc_version(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            m = re.match(r"##\s*Version:\s*(\S+)", line)
            if m:
                return m.group(1), n
    return None, None


def main():
    versions = {}
    for rel in TOCS:
        v, n = toc_version(rel)
        if v is None:
            report.error("no ## Version", rel, 1)
        elif not VERSION.match(v):
            report.error("## Version %s is not x.y.z" % v, rel, n)
        else:
            versions[rel] = (v, n)
    if len(set(v for v, _ in versions.values())) > 1:
        for rel, (v, n) in versions.items():
            report.error("## Version %s differs between the TOCs" % v, rel, n)
    if not versions:
        report.finish()
    current_rel, (current, _) = next(iter(versions.items()))
    if TAG is not None and TAG.lstrip("v") != current:
        report.error("tag %s does not match ## Version %s" % (TAG, current), current_rel)
    markers, newer = 0, {}
    for dp, _, fns in os.walk(os.path.join(ROOT, MARKER_DIR)):
        for fn in sorted(fns):
            if not fn.endswith(".lua"):
                continue
            p = os.path.join(dp, fn)
            rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
            with open(p, encoding="utf-8") as f:
                for n, line in enumerate(f, 1):
                    code = line.split("--", 1)[0]
                    m = MARKER.search(code)
                    if not m:
                        continue
                    for v in re.findall(r'"([^"]*)"', m.group(1)):
                        markers += 1
                        if not VERSION.match(v):
                            report.error('new = "%s" is not x.y.z' % v, rel, n)
                        elif parse(v) > parse(current):
                            if RELEASE:
                                report.error('new = "%s" is newer than ## Version %s' % (v, current), rel, n)
                            else:
                                newer.setdefault(v, []).append((rel, n))
    for v, places in sorted(newer.items()):
        rel, n = places[0]
        msg = '%d markers new = "%s" are newer than ## Version %s; a release (--release) fails on them'
        report.warning(msg % (len(places), v, current), rel, n)
    print("%d markers, ## Version %s" % (markers, current))
    report.finish()


if __name__ == "__main__":
    main()
