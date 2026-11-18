#!/usr/bin/env python3
"""Write one chat context file with everything an LLM needs to edit a whole figure document.

    python3 scripts/llm_context.py <document> [-o OUT]   # -> figures/<document>/llm-context.md
    python3 scripts/llm_context.py --from-fls JOB.fls    # document taken from a LaTeX .fls (latexmk hook)
    python3 scripts/llm_context.py <document> --check    # exit 1 if the file is out of date

The file holds: the common rules, the guide for document.tex (llm/_document.md),
the guide of every figure type the document uses (with its worked example,
except in the sample, whose files are the examples), an index of the figure
files with their IDs, and the document's current files, each under its path.
Reference it in a chat (Continue: @llm-context.md) and ask for changes across
figures and text. It is a snapshot: latexmkrc rewrites it after every build, so
a new chat always gets the built state. figures/empty/ is skipped by the hook.
The file is written only when its content changes. Same idea as llm_context.py
in the document templates. Standard library only.
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from llm_prompt import CHARS_PER_TOKEN, LLM, ROOT, TYPES, examples, fenced

DOCS = ROOT / "figures"
KIND = "figure document"
OUT_NAME = "llm-context.md"
SKELETON = "empty"
SAMPLE = "sample"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
MAX_FIELD = 70  # index entries are cut after this many characters

# specfig environment -> figure type (guide llm/<type>.md)
SF_TYPES = {
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
# element commands whose first mandatory argument is an ID (\Cmd[pos]{ID}...)
ID_RE = re.compile(
    r"\\(Participant|Actor|Initial|Final|Choice|State|Start|End|Action|Object|"
    r"Decision|Merge|Fork|Join|UseCase|Class|AbstractClass|Interface|Enumeration|"
    r"Component|External|Node|Package|Block|Store|Terminal|Process|Subprocess|"
    r"InOut|Task|Milestone|Unit|Risk)(?![A-Za-z])\s*(?:\[[^\]]*\])?\s*\{([^{}]*)\}"
)
INCLUDE_RE = re.compile(r"\\(?:InputFigure|ShowFigure)(?:\[[^\]]*\])?\{([^}]*)\}")
FLS_RE = re.compile(
    r"^INPUT (?:.*/)?" + DOCS.name + r"/([^/]+)/document\.tex$", re.MULTILINE
)

PREFACE = """\
# This context

This file holds the **whole {kind} `{name}`** as of its last build: the rules and
guides, then the document's files, each under a heading with its path. A request may
need changes in several files (e.g. a new figure file and the line in `document.tex`
that includes it): give one separately labelled code block per file, each with the
line saying where it goes. Take IDs, names and dates from the *Figure index* and the
files below. If the engineer says a file changed since, ask them to paste it; the
pasted version wins.
"""


def strip_comments(text: str) -> str:
    return re.sub(r"(?<!\\)%.*", "", text)


def cut(value: str) -> str:
    value = " ".join(value.split())
    return value if len(value) <= MAX_FIELD else value[: MAX_FIELD - 3].rstrip() + "..."


def figure_index(doc_text: str, figures: dict) -> str:
    """One line per figure file: type(s), IDs, whether document.tex includes it."""
    included = set(INCLUDE_RE.findall(strip_comments(doc_text)))
    lines = ["# Figure index (generated from the files below)\n"]
    for rel, text in figures.items():
        body = strip_comments(text)
        envs = [SF_TYPES.get(e, e) for e in SF_RE.findall(body)] or [
            "no specfig figure"
        ]
        ids = list(dict.fromkeys(m.group(2).strip() for m in ID_RE.finditer(body)))
        stem = Path(rel).stem
        use = "included" if stem in included else "not included in document.tex"
        line = f"- `{rel}`: {', '.join(envs)}; {use}"
        if ids:
            line += "; IDs: " + cut(", ".join(ids))
        lines.append(line)
    missing = sorted(
        n for n in included if f"{n}.tex" not in {Path(r).name for r in figures}
    )
    for name in missing:
        lines.append(
            f"- `{name}`: included but no `{name}.tex` here (image or missing)"
        )
    return "\n".join(lines) + "\n"


def build_context(name: str) -> str:
    doc_dir = DOCS / name
    rel_dir = f"{DOCS.name}/{name}"
    doc_text = (doc_dir / "document.tex").read_text(encoding="utf-8")
    figures = {
        p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8")
        for p in sorted(doc_dir.glob("*.tex"))
        if p.name != "document.tex"
    }
    used = sorted(
        {
            SF_TYPES[e]
            for t in [doc_text, *figures.values()]
            for e in SF_RE.findall(strip_comments(t))
            if e in SF_TYPES
        }
    )

    parts = [
        (
            f"<!-- Generated by scripts/llm_context.py from {rel_dir}/ -- "
            "rewritten on every build, don't edit. -->\n"
        ),
        PREFACE.format(kind=KIND, name=name),
        (LLM / "_common.md").read_text(encoding="utf-8").rstrip() + "\n",
        (LLM / "_document.md").read_text(encoding="utf-8").rstrip() + "\n",
    ]
    if used:
        parts.append(f"# Figure guides (types used in this {KIND})\n")
        for kind in used:
            if kind not in TYPES:
                continue
            parts.append(
                (LLM / f"{kind}.md").read_text(encoding="utf-8").rstrip() + "\n"
            )
            if name != SAMPLE:  # the sample's own files are the examples
                parts += examples(kind)
    parts.append(figure_index(doc_text, figures))
    parts.append(f"# Files of {KIND} {name}\n")
    parts.append(fenced(f"{rel_dir}/document.tex", doc_text, "latex"))
    for rel, text in figures.items():
        parts.append(fenced(rel, text, "latex"))
    others = sorted(
        p.relative_to(ROOT).as_posix()
        for p in doc_dir.iterdir()
        if p.is_file() and p.suffix != ".tex" and p.name not in (OUT_NAME, ".gitkeep")
    )
    if others:
        parts.append(
            "Other files in the folder (content not shown): "
            + ", ".join(f"`{o}`" for o in others)
            + "\n"
        )
    parts.append(
        f"# Start\n\nWe work on {KIND} `{name}`. "
        'Reply only "Ready." and wait for my first request.\n'
    )
    return "\n".join(parts)


def name_from_fls(fls: Path):
    if not fls.is_file():
        return None
    m = FLS_RE.search(fls.read_text(encoding="utf-8", errors="replace"))
    return m.group(1) if m else None


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Write one chat context file for editing a whole figure document with an LLM."
    )
    parser.add_argument(
        "name",
        nargs="?",
        metavar="document",
        help="document folder name under figures/",
    )
    parser.add_argument(
        "--from-fls",
        type=Path,
        metavar="FLS",
        help="take the document from a LaTeX .fls file (used by latexmkrc); skips figures/empty",
    )
    parser.add_argument(
        "-o", "--output", type=Path, help=f"default: figures/<document>/{OUT_NAME}"
    )
    parser.add_argument(
        "--check", action="store_true", help="exit 1 if the file is out of date"
    )
    parser.add_argument(
        "-q", "--quiet", action="store_true", help="print only warnings"
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=32000,
        help="warn above this estimated size (default 32000)",
    )
    args = parser.parse_args(argv)

    name = args.name
    if args.from_fls:
        name = name_from_fls(args.from_fls)
        if name is None or name == SKELETON:
            return 0  # not a figure document build, or the skeleton: nothing to do
    if (
        not name
        or not NAME_RE.fullmatch(name)
        or not (DOCS / name / "document.tex").is_file()
    ):
        print(f"error: no {KIND} {name!r} under {DOCS}", file=sys.stderr)
        return 2

    text = build_context(name)
    out = args.output or DOCS / name / OUT_NAME
    old = out.read_text(encoding="utf-8") if out.is_file() else None
    try:
        shown = out.resolve().relative_to(ROOT)
    except ValueError:
        shown = out
    if args.check:
        if old != text:
            print(
                f"{shown} is out of date: run scripts/llm_context.py {name}",
                file=sys.stderr,
            )
            return 1
        return 0
    if old != text:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
    tokens = round(len(text) / CHARS_PER_TOKEN)
    if not args.quiet:
        state = "updated" if old != text else "unchanged"
        print(
            f"{shown}: {state}, ~{tokens} tokens ({len(text)} characters)",
            file=sys.stderr,
        )
    if tokens > args.max_tokens:
        print(
            f"warning: {shown} is ~{tokens} tokens, above {args.max_tokens}; "
            "the chat may lose the beginning. Prefer the per-figure rules or a larger context.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
