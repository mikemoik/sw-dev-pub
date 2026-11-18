#!/usr/bin/env python3
"""Create a new manual folder manuals/<name>/ from the skeleton manuals/empty/.

    python3 scripts/new_manual.py <name> [--from <manual>]

Copies manuals/empty/ (or another manual with --from) to manuals/<name>/, including
its figures/, data/ and code/ folders, and sets \\ComponentName{<name>} in
metadata.tex (one project develops one component; change it if the manual is
named differently). The name is used as folder name and as build job name, so only
letters, digits, '_', '-' and '.' are allowed. Standard library only.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANUALS = ROOT / "manuals"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
COMPNAME_RE = re.compile(r"^%?[ \t]*\\ComponentName\{[^}\n]*\}.*$", re.MULTILINE)


def set_component_name(metadata: Path, name: str) -> None:
    """Set \\ComponentName{name} in metadata.tex (uncomments or replaces the line)."""
    line = f"\\ComponentName{{{name}}}"
    text = metadata.read_text(encoding="utf-8") if metadata.exists() else ""
    if COMPNAME_RE.search(text):
        text = COMPNAME_RE.sub(lambda _m: line, text, count=1)
    else:
        text = text + ("" if text.endswith("\n") or not text else "\n") + line + "\n"
    metadata.write_text(text, encoding="utf-8")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Create manuals/<name>/ from manuals/empty/ (or another manual)."
    )
    parser.add_argument("name", help="manual name, used as folder name under manuals/")
    parser.add_argument(
        "--from",
        dest="source",
        default="empty",
        metavar="MANUAL",
        help="manual to copy (default: empty, the skeleton)",
    )
    args = parser.parse_args(argv)

    name = args.name
    for value in (name, args.source):
        if not NAME_RE.fullmatch(value):
            print(
                f"error: invalid manual name {value!r}: use letters, digits, '_', '-', '.' "
                "(first character a letter or digit)",
                file=sys.stderr,
            )
            return 2
    source = MANUALS / args.source
    target = MANUALS / name
    if not (source / "metadata.tex").is_file():
        print(
            f"error: {source.relative_to(ROOT)} is not a manual folder (no metadata.tex)",
            file=sys.stderr,
        )
        return 1
    if target.exists():
        print(f"error: {target.relative_to(ROOT)} already exists", file=sys.stderr)
        return 1

    # llm-context.md is the source manual's chat context; the first build writes the new one
    shutil.copytree(source, target, ignore=shutil.ignore_patterns("llm-context.md"))
    for sub in ("figures", "data", "code"):  # also when --from lacks one
        folder = target / sub
        folder.mkdir(exist_ok=True)
        if not any(folder.iterdir()):  # git keeps no empty folders
            (folder / ".gitkeep").touch()
    set_component_name(target / "metadata.tex", name)

    print(f"created {target.relative_to(ROOT)}/ (copy of {source.relative_to(ROOT)}/)")
    print(
        f"build:  latexmk -pdf -jobname={name} -usepretex='\\def\\SpecManual{{{name}}}' "
        "sw_project_manual.tex"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
