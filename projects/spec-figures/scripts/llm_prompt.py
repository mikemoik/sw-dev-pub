#!/usr/bin/env python3
"""Assemble a chat prompt so an LLM can draw one figure.

    python3 scripts/llm_prompt.py <type> [--mermaid] [--edit FILE] [--add FILE ...] [-o OUT]

<type> is a figure type (the guides in llm/, e.g. sequence, state, gantt, risk).
The prompt is llm/_common.md + llm/<type>.md + the worked examples
(tikz/<type>.tex and mermaid/<type>.mmd) + optionally a figure to change (--edit)
and input files such as a table export (--add). Paste it as the first message of
a new chat; models without a system role (e.g. Gemma) work the same way.
Standard library only.
"""

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LLM = ROOT / "llm"
TIKZ = ROOT / "tikz"
MERMAID = ROOT / "mermaid"
TYPES = sorted(p.stem for p in LLM.glob("*.md") if not p.stem.startswith("_"))

CHARS_PER_TOKEN = 3.5  # rough estimate for English text and LaTeX


def fenced(title: str, text: str, lang: str = "") -> str:
    return f"## {title}\n\n```{lang}\n{text.rstrip()}\n```\n"


def examples(kind: str) -> list:
    """The worked examples of a figure type: TikZ, then Mermaid (or its Markdown twin)."""
    parts = []
    tikz = TIKZ / f"{kind}.tex"
    if tikz.is_file():
        parts.append(
            fenced(
                f"TikZ example (tikz/{kind}.tex)",
                tikz.read_text(encoding="utf-8"),
                "latex",
            )
        )
    for path, lang in (
        (MERMAID / f"{kind}.mmd", "mermaid"),
        (MERMAID / f"{kind}.md", "markdown"),
    ):
        if path.is_file():
            parts.append(
                fenced(
                    f"Mermaid / Markdown example (mermaid/{path.name})",
                    path.read_text(encoding="utf-8"),
                    lang,
                )
            )
    return parts


def build_prompt(kind: str, mermaid: bool, edit, extra: list) -> str:
    parts = [
        (LLM / "_common.md").read_text(encoding="utf-8").rstrip() + "\n",
        (LLM / f"{kind}.md").read_text(encoding="utf-8").rstrip() + "\n",
        "# Examples\n",
    ]
    parts += examples(kind)
    if edit is not None:
        lang = "mermaid" if edit.suffix == ".mmd" else "latex"
        parts.append(
            fenced(
                f"{edit.name} (the figure to change)",
                edit.read_text(encoding="utf-8"),
                lang,
            )
        )
    for path in extra:
        parts.append(
            fenced(
                f"{path.name} (provided by the engineer)",
                path.read_text(encoding="utf-8"),
            )
        )
    target = "Mermaid" if mermaid else "TikZ (specfig)"
    what = f"change `{edit.name}`" if edit is not None else f"draw a {kind} figure"
    parts.append(
        f"# Start\n\nWe {what} in {target}. "
        'Reply only "Ready." and wait for my first request.\n'
    )
    return "\n".join(parts)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Assemble a chat prompt for drawing one figure."
    )
    parser.add_argument("type", choices=TYPES, help="figure type")
    parser.add_argument(
        "--mermaid", action="store_true", help="answer in Mermaid instead of TikZ"
    )
    parser.add_argument(
        "--edit", type=Path, metavar="FILE", help="existing figure to change"
    )
    parser.add_argument(
        "--add",
        action="append",
        default=[],
        type=Path,
        metavar="FILE",
        help="input file, e.g. a CSV export or requirement text (repeatable)",
    )
    parser.add_argument(
        "-o", "--output", type=Path, help="write to a file instead of stdout"
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=32000,
        help="warn above this estimated prompt size (default 32000)",
    )
    args = parser.parse_args(argv)

    for path in args.add + ([args.edit] if args.edit else []):
        if not path.is_file():
            print(f"error: file not found: {path}", file=sys.stderr)
            return 2

    prompt = build_prompt(args.type, args.mermaid, args.edit, args.add)
    tokens = round(len(prompt) / CHARS_PER_TOKEN)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(prompt, encoding="utf-8")
    else:
        sys.stdout.write(prompt)
    print(f"~{tokens} tokens ({len(prompt)} characters)", file=sys.stderr)
    if tokens > args.max_tokens:
        print(
            f"warning: prompt is above {args.max_tokens} tokens; the chat may lose the "
            "beginning. Use a model with a larger context or shorten the --add files.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
