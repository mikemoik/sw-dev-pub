#!/usr/bin/env python3
"""specfig figures in this template: types, chat guides, figure menu, examples.

Copied from spec-figures (scripts/vendor.py); edit it there, not here. Reads
the figure rules .continue/rules/sf-*.md, which vendor.py also writes:
sf-00-menu.md (the list of figure types, for content files), sf-00-common.md
(rules for figure files) and sf-<type>.md (guide + worked examples per type).
Used by new_figure.py, llm_prompt.py and llm_context.py. Standard library only.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RULES = ROOT / ".continue" / "rules"
INSTANCE_DIRS = ("units", "components", "manuals")  # one of them per template


def types() -> list:
    """Figure types with a guide, e.g. ['activity', 'barchart', ...]."""
    return sorted(
        p.stem[3:] for p in RULES.glob("sf-*.md") if not p.stem.startswith("sf-00-")
    )


def rule_body(name: str) -> str:
    """Rule sf-<name>.md without its frontmatter and generated-file comment ('' if missing)."""
    path = RULES / f"sf-{name}.md"
    if not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.DOTALL)
    text = re.sub(r"\A<!--.*?-->\n", "", text, flags=re.DOTALL)
    return text.strip() + "\n"


def menu() -> str:
    """The figure menu: available types and how to ask for one."""
    return rule_body("00-menu")


def guides(kinds: list) -> str:
    """Figure rules plus the guide and examples of each type, for a chat prompt."""
    if not kinds:
        return ""
    parts = ["# Figure guides (requested types)\n", rule_body("00-common")]
    parts += [rule_body(k) for k in kinds]
    return "\n".join(parts)


def example(kind: str) -> str:
    """The worked TikZ example of a type (from its rule)."""
    m = re.search(
        r"^## TikZ example[^\n]*\n\n```latex\n(.*?)\n```",
        rule_body(kind),
        re.DOTALL | re.MULTILINE,
    )
    return m.group(1) + "\n" if m else ""


def instance_dir() -> Path:
    """units/, components/ or manuals/ of this template."""
    for name in INSTANCE_DIRS:
        if (ROOT / name).is_dir():
            return ROOT / name
    raise SystemExit(f"error: none of {', '.join(INSTANCE_DIRS)} in {ROOT}")
