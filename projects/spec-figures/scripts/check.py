#!/usr/bin/env python3
"""Test spec-figures: build sample and empty, check features, problem marks, rules, Mermaid.

    python3 scripts/check.py            # all checks
    python3 scripts/check.py --no-pdf   # keep the committed spec_figures.pdf untouched

1. The figure documents figures/sample/ (every type and feature) and
   figures/empty/ (skeleton) build with 0 warnings and 0 overfull boxes, as
   scripts/build.py builds them; sample's PDF is the committed preview
   spec_figures.pdf (copied unless --no-pdf).
2. The sample uses every command and option named in the TikZ part of the
   guides llm/<type>.md (in figures/sample/<type>*.tex) and every connection
   option of llm/_common.md.
3. tests/problems.tex (deliberate mistakes) gives exactly the specfig warnings
   listed in tests/problems.expected.
4. .continue/rules/ is up to date with llm/, figures/sample/ and mermaid/.
5. If mermaid-cli (mmdc) is on PATH: every mermaid/*.mmd renders; else skipped.

Needs latexmk and pdflatex; Python 3.6+ standard library only. Exit 1 on failure.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import latexmk_cmd
from continue_rules import RULES, sync
from llm_prompt import LLM, ROOT, TIKZ, TYPES

BUILD = ROOT / "build"
ENV = dict(os.environ, max_print_line="10000")  # one log line per message


def latexmk(tex: Path, outdir: Path) -> str:
    """Build tex into outdir, return the log text ('' if no log)."""
    outdir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "latexmk",
            "-pdf",
            "-interaction=nonstopmode",
            "-halt-on-error",
            f"-outdir={outdir}",
            str(tex),
        ],
        check=False,
        cwd=ROOT,
        env=ENV,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    log = outdir / (tex.stem + ".log")
    return log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""


def warnings(log: str) -> list:
    """LaTeX/package warnings, errors and overfull boxes of a log, continuation lines joined."""
    out = []
    lines = log.splitlines()
    for i, line in enumerate(lines):
        if re.match(
            r"^(! |LaTeX Warning|Package \S+ Warning|Class \S+ Warning|Overfull)", line
        ):
            text = line
            for cont in lines[i + 1 :]:
                m = re.match(r"^\((\S+)\)\s+(.*)$", cont)
                if not m:
                    break
                text += " " + m.group(2)
            out.append(text)
    return out


def check_document(name: str, copy_pdf: bool) -> bool:
    """Build figures/<name>/ as build.py does (forced); 0 warnings, 0 overfull boxes."""
    subprocess.run(
        latexmk_cmd(name, force=True),
        check=False,
        cwd=ROOT,
        env=ENV,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    log_file = BUILD / ".aux" / name / f"{name}.log"
    log = (
        log_file.read_text(encoding="utf-8", errors="replace")
        if log_file.is_file()
        else ""
    )
    found = warnings(log)
    pdf = BUILD / f"{name}.pdf"
    ok = bool(log) and not found and pdf.is_file()
    print(f"document {name}: {'ok' if ok else 'FAILED'} ({len(found)} warnings/errors)")
    for w in found:
        print(f"  {w}")
    if ok and copy_pdf:
        shutil.copyfile(pdf, ROOT / "spec_figures.pdf")
    return ok


# backticked commands in the guides that are not figure commands
IGNORED = {"begin", "end", "Cmd", "InputFigure"}


def guide_features(text: str) -> tuple:
    """Commands and options named in backticks in the TikZ part of a guide."""
    tikz = text.split("## TikZ", 1)[-1].split("\n## ", 1)[0]
    commands, options = set(), set()
    for code in re.findall(r"`([^`]+)`", tikz):
        commands.update(
            c for c in re.findall(r"\\([A-Za-z]+)", code) if c not in IGNORED
        )
    for line in tikz.splitlines():
        if line.startswith("- **Options:**"):
            for code in re.findall(r"`([^`]+)`", line):
                m = re.fullmatch(r"([a-z]+)(=.*)?", code)
                if m:
                    options.add(m.group(1))
    return commands, options


def check_features() -> bool:
    """Every command and option of the guides appears in the sample's figures."""
    missing = []
    every = "".join(p.read_text(encoding="utf-8") for p in sorted(TIKZ.glob("*.tex")))
    for kind in TYPES:
        text = "".join(
            p.read_text(encoding="utf-8")
            for p in sorted(TIKZ.glob(f"{kind}*.tex"))
            if p.stem == kind or p.stem.startswith(kind + "_")
        )
        if not text:
            missing.append(f"{kind}: no figures/sample/{kind}.tex")
            continue
        commands, options = guide_features(
            (LLM / f"{kind}.md").read_text(encoding="utf-8")
        )
        missing += [f"{kind}: \\{c}" for c in sorted(commands) if f"\\{c}" not in text]
        missing += [
            f"{kind}: option {o}" for o in sorted(options) if f"{o}=" not in text
        ]
    for opt in ("[hv]", "[vh]", "[left", "[right", "m1=", "m2=", "pos="):
        if opt not in every:
            missing.append(f"connection option {opt}")
    print(
        f"sample features: {'ok' if not missing else 'FAILED'} ({len(missing)} missing)"
    )
    for m in missing:
        print(f"  missing in figures/sample/: {m}")
    return not missing


def check_problems() -> bool:
    log = latexmk(ROOT / "tests" / "problems.tex", BUILD)
    got = []
    for w in warnings(log):
        m = re.match(r"^Package specfig Warning: (.*?)(?: on input line \d+\.)?$", w)
        if m:
            got.append(m.group(1).strip())
        elif not w.startswith(("Package specfig", "Overfull")):  # narrow test page
            got.append("(other) " + w)
    want = [
        line.strip()
        for line in (ROOT / "tests" / "problems.expected")
        .read_text(encoding="utf-8")
        .splitlines()
        if line.strip() and not line.startswith("#")
    ]
    missing = [w for w in want if w not in got]
    extra = [g for g in got if g not in want]
    ok = bool(log) and not missing and not extra
    print(
        f"problem marks: {'ok' if ok else 'FAILED'} ({len(got)} warnings, {len(want)} expected)"
    )
    for w in missing:
        print(f"  missing:    {w}")
    for g in extra:
        print(f"  unexpected: {g}")
    return ok


def check_mermaid() -> bool:
    mmdc = shutil.which("mmdc")
    if not mmdc:
        print("mermaid: skipped (mmdc not on PATH)")
        return True
    out = BUILD / "mermaid"
    out.mkdir(parents=True, exist_ok=True)
    failed = []
    files = sorted((ROOT / "mermaid").glob("*.mmd"))
    for mmd in files:
        r = subprocess.run(
            [mmdc, "-q", "-i", str(mmd), "-o", str(out / (mmd.stem + ".svg"))],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        if r.returncode:
            failed.append((mmd.name, r.stdout.strip().splitlines()[-1:] or ["?"]))
    print(
        f"mermaid: {'ok' if not failed else 'FAILED'} ({len(files) - len(failed)}/{len(files)} render)"
    )
    for name, msg in failed:
        print(f"  {name}: {msg[0]}")
    return not failed


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Test spec-figures.")
    parser.add_argument(
        "--no-pdf", action="store_true", help="don't update spec_figures.pdf"
    )
    args = parser.parse_args(argv)
    results = [
        check_document("sample", not args.no_pdf),
        check_document("empty", False),
        check_features(),
        check_problems(),
        sync(RULES, check=True) == 0,
        check_mermaid(),
    ]
    if not results[4]:
        print("rules: FAILED (run python3 scripts/continue_rules.py)")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
