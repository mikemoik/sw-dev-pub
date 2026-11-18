#!/usr/bin/env python3
"""Write one chat context file with everything an LLM needs to edit a whole manual.

    python3 scripts/llm_context.py <manual> [-o OUT]     # -> manuals/<manual>/llm-context.md
    python3 scripts/llm_context.py --from-fls JOB.fls    # manual taken from a LaTeX .fls (latexmk hook)
    python3 scripts/llm_context.py <manual> --check      # exit 1 if the file is out of date

The file holds: the common rules, the guide and command reference
(manuals/empty/) of every content file, the figure guides (.continue/rules/sf-*.md)
of the specfig types the manual uses, an index of the declared IDs, and the
manual's current content and figure files, each under its path. Reference it in a
chat (Continue: @llm-context.md) and ask for changes across chapters and figures.
It is a snapshot: latexmkrc rewrites it after every build, so a new chat always
gets the built state. manuals/empty/ is skipped by the hook. The file is written
only when its content changes. Standard library only.
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from llm_prompt import CHARS_PER_TOKEN, LLM, MANUALS, NAME_RE, RELATED, ROOT, fenced

OUT_NAME = "llm-context.md"
SKELETON = "empty"
RULES = ROOT / ".continue" / "rules"
CHAPTERS = list(RELATED)  # chapter order of the manual

# specfig environment -> its chat rule .continue/rules/sf-<name>.md
SF_RULES = {
    "sfActivity": "activity",
    "sfBarChart": "barchart",
    "sfBlock": "block",
    "sfClassDiagram": "class",
    "sfComponent": "component",
    "sfDeployment": "deployment",
    "sfFlowchart": "flowchart",
    "sfGantt": "gantt",
    "sfLineChart": "linechart",
    "sfOrgChart": "orgchart",
    "sfPackage": "package",
    "sfRaci": "raci",
    "sfRiskMatrix": "risk",
    "sfSequence": "sequence",
    "sfStateMachine": "state",
    "sfTimeline": "timeline",
    "sfTiming": "timing",
    "sfUseCase": "usecase",
}
SF_RE = re.compile(r"\\begin\{(sf[A-Za-z]+)\}")
INPUT_FIGURE_RE = re.compile(r"\\InputFigure(?:\[[^\]]*\])?\{([^}]*)\}")
FLS_RE = re.compile(r"^INPUT (?:.*/)?manuals/([^/]+)/metadata\.tex$", re.M)

# declaration command -> (index title, argument positions shown: ID first)
INDEX = {
    "Role": ("Roles", (0, 1)),
    "Member": ("Members (name, roles)", (0, 1)),
    "Process": ("Processes (ID, name, applied)", (0, 1, 2)),
    "Milestone": ("Milestones (ID, date, name)", (0, 1, 2)),
    "Release": ("Releases (version, date, milestone)", (0, 1, 3)),
    "WorkProduct": ("Work products (ID, name, responsible role)", (0, 1, 3)),
    "Baseline": ("Baselines", (0, 1)),
    "Workflow": ("Workflows", (0, 1)),
    "Tool": ("Tools (name, version)", (0, 2)),
    "Risk": ("Risks", (0, 1)),
    "Reference": ("References (key for \\DocRef, document)", (0, 2)),
    "OpenPoint": ("Open points (ID, topic, status)", (0, 1, 2)),
    "HowTo": ("How-tos", (0, 1)),
}

PREFACE = """\
# This context

This file holds the **whole manual `{manual}`** as of its last build: the rules and
guides of the template, then the manual's files, each under a heading with its path.
A request may need changes in several files (e.g. a new work product in
`workproducts.tex` and its milestone in `lifecycle.tex`) or in a figure: give one
separately labelled code block per file, each with the line saying where it goes.
Take IDs, names and dates from the *ID index* and the files below. If the engineer
says a file changed since, ask them to paste it; the pasted version wins.

The guides below were written for one content file at a time; here they apply to
every file of the manual.
"""


def strip_comments(text: str) -> str:
    return re.sub(r"(?<!\\)%.*", "", text)


def braced(text: str, pos: int):
    """Return (content, end) of the {...} group starting at text[pos], else None."""
    if pos >= len(text) or text[pos] != "{":
        return None
    depth = 0
    for i in range(pos, len(text)):
        c = text[i]
        if c == "\\":
            continue
        if c == "{" and text[i - 1] != "\\":
            depth += 1
        elif c == "}" and text[i - 1] != "\\":
            depth -= 1
            if depth == 0:
                return text[pos + 1 : i], i + 1
    return None


def declarations(text: str, command: str) -> list:
    """Argument lists of every \\command[opt]{..}{..}... (or \\begin{HowTo}{..}{..})."""
    text = strip_comments(text)
    head = r"\\begin\{HowTo\}" if command == "HowTo" else r"\\" + command + r"(?![A-Za-z])"
    found = []
    for m in re.finditer(head + r"\s*(?:\[[^\]]*\])?\s*", text):
        args, pos = [], m.end()
        while True:
            group = braced(text, pos)
            if group is None:
                break
            args.append(" ".join(group[0].split()))
            pos = group[1]
            while pos < len(text) and text[pos] in " \t\n":
                pos += 1
        if args:
            found.append(args)
    return found


def id_index(files: dict) -> str:
    text = "\n".join(files.values())
    lines = ["# ID index (generated from the content files below)\n"]
    for command, (title, cols) in INDEX.items():
        rows = declarations(text, command)
        if not rows:
            continue
        lines.append(f"- **{title}:** " + "; ".join(
            " | ".join(r[c] if c < len(r) and r[c] else "-" for c in cols) for r in rows
        ))
    return "\n".join(lines) + "\n"


def rule_body(path: Path) -> str:
    """A Continue rule without its frontmatter and generated-file comment."""
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    text = re.sub(r"\A<!--.*?-->\n", "", text, flags=re.S)
    return text.strip() + "\n"


def figure_files(manual_dir: Path, texts: list) -> dict:
    """The manual's figures/*.tex plus shared figures/<name>.tex it inputs."""
    found = {}
    for path in sorted((manual_dir / "figures").glob("*.tex")):
        found[path.relative_to(ROOT).as_posix()] = path.read_text(encoding="utf-8")
    for name in sorted({n for t in texts for n in INPUT_FIGURE_RE.findall(strip_comments(t))}):
        if (manual_dir / "figures" / f"{name}.tex").is_file():
            continue
        shared = ROOT / "figures" / f"{name}.tex"
        if shared.is_file():
            found[shared.relative_to(ROOT).as_posix()] = shared.read_text(encoding="utf-8")
    return found


def other_files(manual_dir: Path, shown: set) -> list:
    names = []
    for base in (manual_dir, ROOT):
        for sub in ("figures", "data", "code"):
            for path in sorted((base / sub).glob("*")):
                rel = path.relative_to(ROOT).as_posix()
                if path.is_file() and path.name != ".gitkeep" and rel not in shown:
                    names.append(rel)
    return names


def build_context(manual: str) -> str:
    manual_dir = MANUALS / manual
    content = {}
    for name in CHAPTERS:
        path = manual_dir / f"{name}.tex"
        content[f"manuals/{manual}/{name}.tex"] = (
            path.read_text(encoding="utf-8") if path.is_file() else "% (file missing)"
        )
    figures = figure_files(manual_dir, list(content.values()))
    sf_types = sorted(
        {SF_RULES[e] for t in list(content.values()) + list(figures.values())
         for e in SF_RE.findall(strip_comments(t)) if e in SF_RULES}
    )

    parts = [
        f"<!-- Generated by scripts/llm_context.py from manuals/{manual}/ -- "
        "rewritten on every build, don't edit. -->\n",
        PREFACE.format(manual=manual),
        (LLM / "_common.md").read_text(encoding="utf-8").rstrip() + "\n",
        "# Guides and command reference per content file\n",
    ]
    for name in CHAPTERS:
        parts.append((LLM / f"{name}.md").read_text(encoding="utf-8").rstrip() + "\n")
        parts.append(
            fenced(
                f"Command reference (manuals/empty/{name}.tex)",
                (MANUALS / SKELETON / f"{name}.tex").read_text(encoding="utf-8"),
            )
        )
    if sf_types:
        parts.append("# Figure guides (specfig types used in this manual)\n")
        for rule in ["00-common"] + sf_types:
            path = RULES / f"sf-{rule}.md"
            if path.is_file():
                parts.append(rule_body(path))
    parts.append(id_index(content))  # not figures: specfig reuses \Milestone etc.
    parts.append(f"# Files of manual {manual}\n")
    for rel, text in {**content, **figures}.items():
        parts.append(fenced(rel, text))
    others = other_files(manual_dir, set(figures))
    if others:
        parts.append(
            "Other files available to `\\InputFigure`, `\\includegraphics` and "
            "`\\InputCode` (content not shown): " + ", ".join(f"`{o}`" for o in others) + "\n"
        )
    parts.append(
        f"# Start\n\nWe work on manual `{manual}`. "
        'Reply only "Ready." and wait for my first request.\n'
    )
    return "\n".join(parts)


def manual_from_fls(fls: Path):
    if not fls.is_file():
        return None
    m = FLS_RE.search(fls.read_text(encoding="utf-8", errors="replace"))
    return m.group(1) if m else None


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Write one chat context file for editing a whole manual with an LLM."
    )
    parser.add_argument("manual", nargs="?", help="manual folder name under manuals/")
    parser.add_argument(
        "--from-fls", type=Path, metavar="FLS",
        help="take the manual from a LaTeX .fls file (used by latexmkrc); skips manuals/empty",
    )
    parser.add_argument("-o", "--output", type=Path, help=f"default: manuals/<manual>/{OUT_NAME}")
    parser.add_argument("--check", action="store_true", help="exit 1 if the file is out of date")
    parser.add_argument("-q", "--quiet", action="store_true", help="print only warnings")
    parser.add_argument(
        "--max-tokens", type=int, default=32000,
        help="warn above this estimated size (default 32000)",
    )
    args = parser.parse_args(argv)

    manual = args.manual
    if args.from_fls:
        manual = manual_from_fls(args.from_fls)
        if manual is None or manual == SKELETON:
            return 0  # not a manual build, or the skeleton: nothing to do
    if (
        not manual
        or not NAME_RE.fullmatch(manual)
        or not (MANUALS / manual / "metadata.tex").is_file()
    ):
        print(f"error: no manual {manual!r} under {MANUALS}", file=sys.stderr)
        return 2

    text = build_context(manual)
    out = args.output or MANUALS / manual / OUT_NAME
    old = out.read_text(encoding="utf-8") if out.is_file() else None
    try:
        shown = out.resolve().relative_to(ROOT)
    except ValueError:
        shown = out
    if args.check:
        if old != text:
            print(f"{shown} is out of date: run scripts/llm_context.py {manual}", file=sys.stderr)
            return 1
        return 0
    if old != text:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
    tokens = round(len(text) / CHARS_PER_TOKEN)
    if not args.quiet:
        state = "updated" if old != text else "unchanged"
        print(f"{shown}: {state}, ~{tokens} tokens ({len(text)} characters)", file=sys.stderr)
    if tokens > args.max_tokens:
        print(
            f"warning: {shown} is ~{tokens} tokens, above {args.max_tokens}; "
            "the chat may lose the beginning. Prefer the per-file rules or a larger context.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
