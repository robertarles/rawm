#!/usr/bin/env python3
"""Register Swift test files into the rawm-tests target in project.pbxproj.

Adds each given file (by basename, assumed to live in Tests/) to:
  1. PBXBuildFile section
  2. PBXFileReference section
  3. the Tests PBXGroup (children)
  4. the rawm-tests PBXSourcesBuildPhase (files)

Idempotent: a file already present (by basename) is skipped.

Usage:
  scripts/add-test-files.py Tests/FooTests.swift Tests/BarTests.swift
"""
import os
import re
import secrets
import sys

PBXPROJ = os.path.join(os.path.dirname(__file__), "..", "rawm.xcodeproj", "project.pbxproj")

# Anchors: existing RawmTests.swift entries in each of the four sections. New
# entries are inserted immediately after these unique lines.
ANCHOR_BUILDFILE = "9824702022AF9B7E0037B409 /* RawmTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 9824701F22AF9B7E0037B409 /* RawmTests.swift */; };"
ANCHOR_FILEREF   = '9824701F22AF9B7E0037B409 /* RawmTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RawmTests.swift; sourceTree = "<group>"; };'
ANCHOR_GROUP     = "9824701F22AF9B7E0037B409 /* RawmTests.swift */,"
ANCHOR_PHASE     = "9824702022AF9B7E0037B409 /* RawmTests.swift in Sources */,"


def uuid():
    return secrets.token_hex(12).upper()


def main(argv):
    if not argv:
        print("usage: add-test-files.py <Tests/File.swift> [...]", file=sys.stderr)
        return 2

    with open(PBXPROJ, "r") as f:
        text = f.read()

    for anchor in (ANCHOR_BUILDFILE, ANCHOR_FILEREF, ANCHOR_GROUP, ANCHOR_PHASE):
        if anchor not in text:
            print(f"ERROR: anchor not found in pbxproj:\n  {anchor}", file=sys.stderr)
            return 1

    added = []
    for path in argv:
        base = os.path.basename(path)
        # Skip if already registered (idempotent).
        if re.search(r"/\* %s \*/ = \{isa = PBXFileReference" % re.escape(base), text):
            print(f"skip (already registered): {base}")
            continue

        fileref = uuid()
        buildfile = uuid()

        bf_line  = f"\t\t{buildfile} /* {base} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileref} /* {base} */; }};"
        fr_line  = f'\t\t{fileref} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {base}; sourceTree = "<group>"; }};'
        grp_line = f"\t\t\t\t{fileref} /* {base} */,"
        ph_line  = f"\t\t\t\t{buildfile} /* {base} in Sources */,"

        text = text.replace(ANCHOR_BUILDFILE, ANCHOR_BUILDFILE + "\n" + bf_line, 1)
        text = text.replace(ANCHOR_FILEREF,   ANCHOR_FILEREF   + "\n" + fr_line, 1)
        text = text.replace(ANCHOR_GROUP,     ANCHOR_GROUP     + "\n" + grp_line, 1)
        text = text.replace(ANCHOR_PHASE,     ANCHOR_PHASE     + "\n" + ph_line, 1)
        added.append(base)

    with open(PBXPROJ, "w") as f:
        f.write(text)

    print(f"registered {len(added)} file(s): {', '.join(added) if added else '(none)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
