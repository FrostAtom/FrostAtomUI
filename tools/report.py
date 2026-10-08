"""Shared output for the repository checks: plain lines locally, workflow annotations on GitHub Actions."""
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

GITHUB = os.environ.get("GITHUB_ACTIONS") == "true"


class Report:
    def __init__(self, name):
        self.name = name
        self.errors = 0
        self.warnings = 0

    def _emit(self, level, message, path, line):
        if GITHUB:
            where = ",".join(x for x in (path and "file=" + path, line and "line=%d" % line) if x)
            print("::%s %s::%s" % (level, where, message) if where else "::%s::%s" % (level, message))
        else:
            loc = path + (":%d" % line if line else "") + ": " if path else ""
            print("%s: %s%s" % (level, loc, message))

    def error(self, message, path=None, line=None):
        self.errors += 1
        self._emit("error", message, path, line)

    def warning(self, message, path=None, line=None):
        self.warnings += 1
        self._emit("warning", message, path, line)

    def finish(self, strict=False):
        print("%s: %d errors, %d warnings" % (self.name, self.errors, self.warnings))
        sys.exit(1 if self.errors or (strict and self.warnings) else 0)
