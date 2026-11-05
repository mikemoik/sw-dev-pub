#!/usr/bin/env python3
"""Create a new unit folder units/<name>/ from the skeleton units/empty/.

    python3 scripts/new_unit.py <name> [--from <unit>]

Copies units/empty/ (or another unit with --from) to units/<name>/, including
its figures/, data/ and code/ folders, and sets \\UnitName{<name>} in
metadata.tex. The name is used as folder name and as build job name, so only
letters, digits, '_', '-' and '.' are allowed. Standard library only.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNITS = ROOT / "units"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
UNITNAME_RE = re.compile(r"^%?[ \t]*\\UnitName\{[^}\n]*\}.*$", re.MULTILINE)


def set_unit_name(metadata: Path, name: str) -> None:
    """Set \\UnitName{name} in metadata.tex (uncomments or replaces the line)."""
    line = f"\\UnitName{{{name}}}"
    text = metadata.read_text(encoding="utf-8") if metadata.exists() else ""
    if UNITNAME_RE.search(text):
        text = UNITNAME_RE.sub(lambda _m: line, text, count=1)
    else:
        text = text + ("" if text.endswith("\n") or not text else "\n") + line + "\n"
    metadata.write_text(text, encoding="utf-8")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Create units/<name>/ from units/empty/ (or another unit)."
    )
    parser.add_argument("name", help="unit name, used as folder name under units/")
    parser.add_argument(
        "--from",
        dest="source",
        default="empty",
        metavar="UNIT",
        help="unit to copy (default: empty, the skeleton)",
    )
    args = parser.parse_args(argv)

    name = args.name
    for value in (name, args.source):
        if not NAME_RE.fullmatch(value):
            print(
                f"error: invalid unit name {value!r}: use letters, digits, '_', '-', '.' "
                "(first character a letter or digit)",
                file=sys.stderr,
            )
            return 2
    source = UNITS / args.source
    target = UNITS / name
    if not (source / "metadata.tex").is_file():
        print(
            f"error: {source.relative_to(ROOT)} is not a unit folder (no metadata.tex)",
            file=sys.stderr,
        )
        return 1
    if target.exists():
        print(f"error: {target.relative_to(ROOT)} already exists", file=sys.stderr)
        return 1

    shutil.copytree(source, target)
    for sub in ("figures", "data", "code"):  # also when --from lacks one
        folder = target / sub
        folder.mkdir(exist_ok=True)
        if not any(folder.iterdir()):  # git keeps no empty folders
            (folder / ".gitkeep").touch()
    set_unit_name(target / "metadata.tex", name)

    print(f"created {target.relative_to(ROOT)}/ (copy of {source.relative_to(ROOT)}/)")
    print(
        f"build:  latexmk -pdf -jobname={name} -usepretex='\\def\\SpecUnit{{{name}}}' "
        "sw_unit_test_spec.tex"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
