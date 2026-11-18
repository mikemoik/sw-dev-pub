#!/usr/bin/env python3
"""Create a new figure document figures/<name>/ from the skeleton figures/empty/.

    python3 scripts/new_figures.py <name> [--from <document>]

Copies figures/empty/ (or another document with --from, e.g. sample) to
figures/<name>/ and sets the title in its document.tex to <name>. The name is
used as folder name and as build job name, so only letters, digits, '_', '-'
and '.' are allowed. Standard library only.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIGURES = ROOT / "figures"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
TITLE_RE = re.compile(r"^\\Title\{[^}\n]*\}", re.MULTILINE)


def set_title(document: Path, name: str) -> None:
    """Set the first argument of \\Title{...}{...} to name (adds \\Title if missing)."""
    text = document.read_text(encoding="utf-8")
    title = f"\\Title{{{name}}}"
    if TITLE_RE.search(text):
        text = TITLE_RE.sub(lambda _m: title, text, count=1)
    else:
        text = title + "{}\n\n" + text
    document.write_text(text, encoding="utf-8")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Create figures/<name>/ from figures/empty/ (or another document)."
    )
    parser.add_argument(
        "name", help="document name, used as folder name under figures/"
    )
    parser.add_argument(
        "--from",
        dest="source",
        default="empty",
        metavar="DOCUMENT",
        help="document to copy (default: empty, the skeleton)",
    )
    args = parser.parse_args(argv)

    for value in (args.name, args.source):
        if not NAME_RE.fullmatch(value):
            print(
                f"error: invalid document name {value!r}: use letters, digits, '_', '-', '.' "
                "(first character a letter or digit)",
                file=sys.stderr,
            )
            return 2
    source = FIGURES / args.source
    target = FIGURES / args.name
    if not (source / "document.tex").is_file():
        print(
            f"error: {source.relative_to(ROOT)} is not a figure document (no document.tex)",
            file=sys.stderr,
        )
        return 1
    if target.exists():
        print(f"error: {target.relative_to(ROOT)} already exists", file=sys.stderr)
        return 1

    shutil.copytree(source, target)
    set_title(target / "document.tex", args.name)

    print(f"created {target.relative_to(ROOT)}/ (copy of {source.relative_to(ROOT)}/)")
    print(f"build:  python3 scripts/build.py {args.name}   # -> build/{args.name}.pdf")
    return 0


if __name__ == "__main__":
    sys.exit(main())
