#!/usr/bin/env python3
"""Create a new component folder components/<name>/ from the skeleton components/empty/.

    python3 scripts/new_component.py <name> [--from <component>]
    python3 scripts/new_component.py --add-missing <component> [<component> ...] | --all

Copies components/empty/ (or another component with --from) to components/<name>/, including
its figures/, data/ and code/ folders, and sets \\ComponentName{<name>} in
metadata.tex. The name is used as folder name and as build job name, so only
letters, digits, '_', '-' and '.' are allowed.

--add-missing updates existing components (e.g. made with an older template):
it copies every file of components/empty/ that the component does not have yet and
never changes an existing file. Standard library only.
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


def add_missing(target: Path) -> list:
    """Copy the files of components/empty/ that target lacks; returns their paths."""
    skeleton = COMPONENTS / "empty"
    added = []
    for src in sorted(skeleton.rglob("*")):
        rel = src.relative_to(skeleton)
        dst = target / rel
        if not src.is_file() or rel.name == "llm-context.md" or dst.exists():
            continue
        if rel.name == ".gitkeep" and dst.parent.is_dir() and any(dst.parent.iterdir()):
            continue  # folder exists and is not empty
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        added.append(dst)
    return added


def main_add_missing(names, all_docs) -> int:
    if all_docs:
        names = sorted(
            d.name for d in COMPONENTS.iterdir()
            if d.name != "empty" and (d / "metadata.tex").is_file()
        )
    if not names:
        print("error: give component names or --all", file=sys.stderr)
        return 2
    status = 0
    for name in names:
        target = COMPONENTS / name
        if not NAME_RE.fullmatch(name) or not (target / "metadata.tex").is_file():
            print(f"error: components/{name} is not a component folder (no metadata.tex)", file=sys.stderr)
            status = 1
            continue
        if name == "empty":
            print("error: components/empty is the skeleton itself", file=sys.stderr)
            status = 1
            continue
        added = add_missing(target)
        for path in added:
            print(f"added {path.relative_to(ROOT).as_posix()}")
        if not added:
            print(f"components/{name}: nothing missing")
    return status


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Create components/<name>/ from components/empty/ (or another component)."
    )
    parser.add_argument("name", nargs="*", help="component name, used as folder name under components/")
    parser.add_argument(
        "--add-missing",
        action="store_true",
        help="existing components: copy the files of components/empty/ they lack (none is changed)",
    )
    parser.add_argument("--all", action="store_true", help="with --add-missing: every component")
    parser.add_argument(
        "--from",
        dest="source",
        default="empty",
        metavar="UNIT",
        help="component to copy (default: empty, the skeleton)",
    )
    args = parser.parse_args(argv)

    if args.add_missing:
        if args.source != "empty":
            parser.error("--from does not apply to --add-missing")
        return main_add_missing(args.name, args.all)
    if args.all or len(args.name) != 1:
        parser.error("give exactly one component name (--all only with --add-missing)")
    name = args.name[0]
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
