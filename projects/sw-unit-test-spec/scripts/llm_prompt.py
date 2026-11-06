#!/usr/bin/env python3
"""Assemble a chat prompt so an LLM can help edit one content file of a unit.

    python3 scripts/llm_prompt.py <unit> <file> [--add PATH ...] [-o OUT]

<file> is a content file name without .tex (testcases, requirements, unit,
design, introduction, metadata, approach, environment, results). The prompt is
llm/_common.md + llm/<file>.md + the command reference (units/empty/<file>.tex)
+ a worked example (units/sample/<file>.tex, left out with --no-example or when
working on the sample) + the unit's file and the related files it needs + any
--add files (e.g. a header or an SRS excerpt). Paste it as the first message of a new chat; models
without a system role (e.g. Gemma) work the same way. Standard library only.
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNITS = ROOT / "units"
LLM = ROOT / "llm"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")

# content file -> files of the same unit the model also needs to see
RELATED = {
    "metadata": [],
    "introduction": ["metadata", "unit"],
    "unit": ["metadata"],
    "design": ["unit"],
    "requirements": ["unit"],
    "approach": ["metadata", "testcases"],
    "environment": ["metadata", "unit"],
    "testcases": ["requirements", "unit"],
    "results": ["approach", "testcases"],
}

CHARS_PER_TOKEN = 3.5  # rough estimate for English text and LaTeX


def fenced(title: str, text: str, lang: str = "latex") -> str:
    return f"## {title}\n\n```{lang}\n{text.rstrip()}\n```\n"


def build_prompt(unit: str, file: str, extra: list, example: bool = True) -> str:
    unit_dir = UNITS / unit
    parts = [
        (LLM / "_common.md").read_text(encoding="utf-8").rstrip() + "\n",
        (LLM / f"{file}.md").read_text(encoding="utf-8").rstrip() + "\n",
        "# Files\n",
        fenced(
            f"Command reference (units/empty/{file}.tex)",
            (UNITS / "empty" / f"{file}.tex").read_text(encoding="utf-8"),
        ),
    ]
    sample = UNITS / "sample" / f"{file}.tex"
    if example and unit != "sample" and sample.is_file():
        parts.append(
            fenced(
                f"Worked example from another unit (units/sample/{file}.tex)",
                sample.read_text(encoding="utf-8"),
            )
        )
    for name in [file] + RELATED[file]:
        path = unit_dir / f"{name}.tex"
        label = "the file to edit" if name == file else "for reference, don't edit"
        text = (
            path.read_text(encoding="utf-8") if path.is_file() else "% (file missing)"
        )
        parts.append(fenced(f"units/{unit}/{name}.tex ({label})", text))
    for path in extra:
        lang = "latex" if path.suffix == ".tex" else ""
        parts.append(
            fenced(
                f"{path.name} (provided by the engineer)",
                path.read_text(encoding="utf-8"),
                lang,
            )
        )
    parts.append(
        f"# Start\n\nWe work on `units/{unit}/{file}.tex`. "
        'Reply only "Ready." and wait for my first request.\n'
    )
    return "\n".join(parts)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Assemble a chat prompt for editing units/<unit>/<file>.tex with an LLM."
    )
    parser.add_argument("unit", help="unit folder name under units/")
    parser.add_argument("file", choices=sorted(RELATED), help="content file to work on")
    parser.add_argument(
        "--add",
        action="append",
        default=[],
        type=Path,
        metavar="PATH",
        help="extra file to include, e.g. a header or requirement excerpt (repeatable)",
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
    parser.add_argument(
        "--no-example",
        action="store_true",
        help="leave out the worked example from units/sample/",
    )
    args = parser.parse_args(argv)

    if (
        not NAME_RE.fullmatch(args.unit)
        or not (UNITS / args.unit / "metadata.tex").is_file()
    ):
        print(f"error: no unit {args.unit!r} under {UNITS}", file=sys.stderr)
        return 2
    for path in args.add:
        if not path.is_file():
            print(f"error: --add file not found: {path}", file=sys.stderr)
            return 2

    prompt = build_prompt(args.unit, args.file, args.add, not args.no_example)
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
