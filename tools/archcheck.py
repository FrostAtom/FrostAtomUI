#!/usr/bin/env python3
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GITHUB = os.environ.get("GITHUB_ACTIONS") == "true"


def section(lines, title):
    out, inside = [], False
    for line in lines:
        if line.startswith("== "):
            inside = line.startswith("== " + title)
            continue
        if inside and line.strip():
            out.append(line.strip())
    return out


def main():
    with tempfile.TemporaryDirectory() as out:
        subprocess.run(
            [sys.executable, os.path.join(ROOT, "tools", "archcheck", "depgraph.py"), ROOT, out],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        with open(os.path.join(out, "depgraph.txt"), encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    errors = []
    for title in ("SCCs (cycles) on component graph", "SCCs on file graph"):
        for row in section(lines, title):
            errors.append("dependency cycle: " + row)
    for row in section(lines, "load-order inversions"):
        if not re.search(r"fs=\[\]$", row):
            errors.append("file-scope use of something defined later in the TOC: " + row)
    for message in errors:
        print(("::error::%s" if GITHUB else "error: %s") % message)
    print("archcheck: %d errors" % len(errors))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
