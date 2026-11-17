#!/usr/bin/env python3
"""Copy specfig into a document template (vendoring, nothing is installed).

    python3 scripts/vendor.py <template dir>           # copy / update
    python3 scripts/vendor.py <template dir> --check   # exit 1 if out of date

Copies sty/specfig*.sty to <template dir>/sty/ and writes the figure rules for
Continue (sf-*.md) to <template dir>/.continue/rules/. The template then
needs sty/ on TeX's search path (latexmkrc: ensure_path('TEXINPUTS', './sty//');)
and \\usepackage{specfig} after its \\documentclass. Standard library only.
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from continue_rules import sync
from llm_prompt import ROOT


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Copy specfig into a document template."
    )
    parser.add_argument("template", type=Path, help="root folder of the template")
    parser.add_argument(
        "--check", action="store_true", help="don't write; exit 1 if out of date"
    )
    args = parser.parse_args(argv)

    target = args.template.resolve()
    if not target.is_dir() or target == ROOT:
        print(f"error: not a template folder: {args.template}", file=sys.stderr)
        return 2
    rc = 0
    for src in sorted((ROOT / "sty").glob("specfig*.sty")):
        dst = target / "sty" / src.name
        same = dst.is_file() and dst.read_bytes() == src.read_bytes()
        if args.check:
            if not same:
                print(f"out of date: {dst}", file=sys.stderr)
                rc = 1
        elif not same:
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(src.read_bytes())
            print(f"copied {src.name} -> {dst}")
    rc |= sync(target / ".continue" / "rules", args.check)
    latexmkrc = target / "latexmkrc"
    if not (latexmkrc.is_file() and "./sty//" in latexmkrc.read_text(encoding="utf-8")):
        print(
            f"note: {latexmkrc} does not put sty/ on TEXINPUTS; add: "
            "ensure_path('TEXINPUTS', './sty//');",
            file=sys.stderr,
        )
    if rc and args.check:
        print(f"run: python3 scripts/vendor.py {args.template}", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main())
