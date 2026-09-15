#!/usr/bin/env python3
"""Summarize KASAN report fields for a defensive triage exercise."""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: python3 triage.py REPORT.txt")

report = Path(sys.argv[1]).read_text(errors="replace")
bug = re.search(r"BUG: KASAN: ([^\n]+)", report)
access = re.search(r"(Read|Write) of size (\d+)", report)

markers = (
    ("access_stack", re.compile(r"^Call Trace:")),
    ("allocation_stack", re.compile(r"^Allocated by task")),
    ("free_stack", re.compile(r"^Freed by task")),
)
lines = report.splitlines()


def collect(start):
    frames = []
    for line in lines[start + 1:]:
        if not line.strip() or any(p.match(line) for _, p in markers):
            break
        frames.append(line.strip())
    return frames


sections = {}
for name, pattern in markers:
    index = next((i for i, line in enumerate(lines) if pattern.match(line)), None)
    sections[name] = collect(index) if index is not None else []

print("bug:", bug.group(1) if bug else "not found")
print("access:", " ".join(access.groups()) if access else "not found")
for name, frames in sections.items():
    print(name + ":")
    for frame in frames:
        print("  " + frame)
