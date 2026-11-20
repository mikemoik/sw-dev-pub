#!/usr/bin/env python3
"""Create a new unit folder units/<name>/ from the skeleton units/empty/.

    python3 scripts/new_unit.py <name> [--from <unit>]
    python3 scripts/new_unit.py --add-missing <unit> [<unit> ...] | --all

Copies units/empty/ (or another unit with --from) to units/<name>/, including
its figures/, data/ and code/ folders, sets \\UnitName{<name>} in
metadata.tex and `unit:` in knowledge.md. With --from, knowledge.md starts
from the skeleton: the other unit's knowledge is not copied. The name is used as folder name and as build job name, so only
letters, digits, '_', '-' and '.' are allowed.

--add-missing updates existing units (e.g. made with an older template):
it copies every file of units/empty/ that the unit does not have yet and never
changes an existing file. Standard library only.
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
KNOWLEDGE_UNIT_RE = re.compile(r"^unit:.*$", re.MULTILINE)


def set_unit_name(metadata: Path, name: str) -> None:
    """Set \\UnitName{name} in metadata.tex (uncomments or replaces the line)."""
    line = f"\\UnitName{{{name}}}"
    text = metadata.read_text(encoding="utf-8") if metadata.exists() else ""
    if UNITNAME_RE.search(text):
        text = UNITNAME_RE.sub(lambda _m: line, text, count=1)
    else:
        text = text + ("" if text.endswith("\n") or not text else "\n") + line + "\n"
    metadata.write_text(text, encoding="utf-8")


def reset_knowledge(target: Path, name: str) -> None:
    """knowledge.md from the skeleton, with unit: <name> (no file if the skeleton has none)."""
    skeleton = UNITS / "empty" / "knowledge.md"
    if not skeleton.is_file():
        return
    text = KNOWLEDGE_UNIT_RE.sub(f"unit: {name}", skeleton.read_text(encoding="utf-8"), count=1)
    (target / "knowledge.md").write_text(text, encoding="utf-8")


def add_missing(target: Path) -> list:
    """Copy the files of units/empty/ that target lacks; returns their paths."""
    skeleton = UNITS / "empty"
    added = []
    for src in sorted(skeleton.rglob("*")):
        rel = src.relative_to(skeleton)
        dst = target / rel
        if not src.is_file() or rel.name == "llm-context.md" or dst.exists():
            continue
        if rel.name == ".gitkeep" and dst.parent.is_dir() and any(dst.parent.iterdir()):
            continue  # folder exists and is not empty
        dst.parent.mkdir(parents=True, exist_ok=True)
        if rel.as_posix() == "knowledge.md":
            reset_knowledge(target, target.name)
        else:
            shutil.copy2(src, dst)
        added.append(dst)
    return added


def main_add_missing(names, all_units) -> int:
    if all_units:
        names = sorted(
            d.name for d in UNITS.iterdir()
            if d.name != "empty" and (d / "metadata.tex").is_file()
        )
    if not names:
        print("error: give unit names or --all", file=sys.stderr)
        return 2
    status = 0
    for name in names:
        target = UNITS / name
        if not NAME_RE.fullmatch(name) or not (target / "metadata.tex").is_file():
            print(f"error: units/{name} is not a unit folder (no metadata.tex)", file=sys.stderr)
            status = 1
            continue
        if name == "empty":
            print("error: units/empty is the skeleton itself", file=sys.stderr)
            status = 1
            continue
        added = add_missing(target)
        for path in added:
            print(f"added {path.relative_to(ROOT).as_posix()}")
        if not added:
            print(f"units/{name}: nothing missing")
    return status


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Create units/<name>/ from units/empty/ (or another unit), "
        "or add the skeleton files existing units lack."
    )
    parser.add_argument("name", nargs="*", help="unit name, used as folder name under units/")
    parser.add_argument(
        "--add-missing",
        action="store_true",
        help="existing units: copy the files of units/empty/ they lack (none is changed)",
    )
    parser.add_argument("--all", action="store_true", help="with --add-missing: every unit")
    parser.add_argument(
        "--from",
        dest="source",
        default="empty",
        metavar="UNIT",
        help="unit to copy (default: empty, the skeleton)",
    )
    args = parser.parse_args(argv)

    if args.add_missing:
        if args.source != "empty":
            parser.error("--from does not apply to --add-missing")
        return main_add_missing(args.name, args.all)
    if args.all or len(args.name) != 1:
        parser.error("give exactly one unit name (--all only with --add-missing)")
    name = args.name[0]
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

    # llm-context.md is the source unit's chat context; the first build writes the new one
    shutil.copytree(source, target, ignore=shutil.ignore_patterns("llm-context.md"))
    for sub in ("figures", "data", "code"):  # also when --from lacks one
        folder = target / sub
        folder.mkdir(exist_ok=True)
        if not any(folder.iterdir()):  # git keeps no empty folders
            (folder / ".gitkeep").touch()
    set_unit_name(target / "metadata.tex", name)
    reset_knowledge(target, name)

    print(f"created {target.relative_to(ROOT)}/ (copy of {source.relative_to(ROOT)}/)")
    print(
        f"build:  latexmk -pdf -jobname={name} -usepretex='\\def\\SpecUnit{{{name}}}' "
        "sw_unit_test_spec.tex"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
