#!/usr/bin/env python3
"""Create a specfig figure file from the worked example of its type.

    python3 scripts/new_figure.py <instance> <type> <name>     # -> <instance dir>/figures/<type>_<name>.tex
    python3 scripts/new_figure.py --shared <type> <name>       # -> figures/<type>_<name>.tex (all instances)
    python3 scripts/new_figure.py --list                       # the figure types

<instance> is the unit, component or manual folder. The new file holds the
type's worked example: replace its content. The file name starts with the type,
so Continue adds the type's chat guide when the file is in the chat. Include it
in a free-text block with \\InputFigure{<type>_<name>}. Copied from
spec-figures (scripts/vendor.py); edit it there. Standard library only.
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sf_figures import ROOT, example, instance_dir, rule_body, types

NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*")


def describe(kind: str) -> str:
    m = re.search(r"^# Figure: (.*)$", rule_body(kind), re.MULTILINE)
    return m.group(1) if m else ""


def main(argv=None) -> int:
    kinds = types()
    parser = argparse.ArgumentParser(
        description="Create a specfig figure file from the example of its type."
    )
    parser.add_argument("args", nargs="*", help="[<instance>] <type> <name>")
    parser.add_argument(
        "--shared", action="store_true", help="in the shared figures/ folder"
    )
    parser.add_argument("--list", action="store_true", help="list the figure types")
    args = parser.parse_args(argv)

    if args.list:
        for kind in kinds:
            print(f"{kind:12} {describe(kind)}")
        return 0
    want = 2 if args.shared else 3
    if len(args.args) != want:
        parser.error("give <type> <name> with --shared, else <instance> <type> <name>")
    *inst, kind, name = args.args
    if kind not in kinds:
        print(
            f"error: unknown figure type {kind!r}; types: {', '.join(kinds)}",
            file=sys.stderr,
        )
        return 2
    if not NAME_RE.fullmatch(name):
        print(
            f"error: invalid name {name!r}: letters, digits, '_', '-'", file=sys.stderr
        )
        return 2
    if args.shared:
        folder = ROOT / "figures"
    else:
        base = instance_dir()
        if (
            not NAME_RE.fullmatch(inst[0])
            or not (base / inst[0] / "metadata.tex").is_file()
        ):
            print(f"error: no {inst[0]!r} under {base.name}/", file=sys.stderr)
            return 2
        folder = base / inst[0] / "figures"
    stem = name if name.startswith(kind + "_") else f"{kind}_{name}"
    target = folder / f"{stem}.tex"
    if target.exists():
        print(f"error: {target.relative_to(ROOT)} already exists", file=sys.stderr)
        return 1
    body = example(kind)
    if not body:
        print(
            f"error: no example for {kind} in .continue/rules/sf-{kind}.md",
            file=sys.stderr,
        )
        return 1
    folder.mkdir(parents=True, exist_ok=True)
    target.write_text(
        f"% {describe(kind)}: started from the worked example, replace its content.\n"
        f"% Guide: .continue/rules/sf-{kind}.md (Continue adds it when this file is in the chat).\n"
        + body,
        encoding="utf-8",
    )
    print(f"created {target.relative_to(ROOT)}")
    hint = (
        "inside a table or center environment"
        if kind == "raci"
        else "in a figure environment"
    )
    print(f"include it in a free-text block, {hint}:  \\InputFigure{{{stem}}}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
