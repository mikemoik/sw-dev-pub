#!/usr/bin/env python3
"""Create a new component folder components/<name>/ from the skeleton components/empty/.

    python3 scripts/new_component.py <name> [--from <component>]

Copies components/empty/ (or another component with --from) to components/<name>/, including
its figures/, data/ and code/ folders, and sets \\ComponentName{<name>} in
metadata.tex. The name is used as folder name and as build job name, so only
letters, digits, '_', '-' and '.' are allowed. Standard library only.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = ROOT / "components"
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
        description="Create components/<name>/ from components/empty/ (or another component)."
    )
    parser.add_argument("name", help="component name, used as folder name under components/")
    parser.add_argument(
        "--from",
        dest="source",
        default="empty",
        metavar="UNIT",
        help="component to copy (default: empty, the skeleton)",
    )
    args = parser.parse_args(argv)

    name = args.name
    for value in (name, args.source):
        if not NAME_RE.fullmatch(value):
            print(
                f"error: invalid component name {value!r}: use letters, digits, '_', '-', '.' "
                "(first character a letter or digit)",
                file=sys.stderr,
            )
            return 2
    source = COMPONENTS / args.source
    target = COMPONENTS / name
    if not (source / "metadata.tex").is_file():
        print(
            f"error: {source.relative_to(ROOT)} is not a component folder (no metadata.tex)",
            file=sys.stderr,
        )
        return 1
    if target.exists():
        print(f"error: {target.relative_to(ROOT)} already exists", file=sys.stderr)
        return 1

    # llm-context.md is the source component's chat context; the first build writes the new one
    shutil.copytree(source, target, ignore=shutil.ignore_patterns("llm-context.md"))
    for sub in ("figures", "data", "code"):  # also when --from lacks one
        folder = target / sub
        folder.mkdir(exist_ok=True)
        if not any(folder.iterdir()):  # git keeps no empty folders
            (folder / ".gitkeep").touch()
    set_component_name(target / "metadata.tex", name)

    print(f"created {target.relative_to(ROOT)}/ (copy of {source.relative_to(ROOT)}/)")
    print(
        f"build:  latexmk -pdf -jobname={name} -usepretex='\\def\\SpecComponent{{{name}}}' "
        "sw_component_spec.tex"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
