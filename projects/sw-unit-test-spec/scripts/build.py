#!/usr/bin/env python3
"""Build unit test specifications into build/<unit>.pdf.

    python3 scripts/build.py <unit> [<unit> ...]
    python3 scripts/build.py --all

Runs latexmk once per unit (job name = unit name, \\SpecUnit = unit name).
PDFs go to build/, intermediates to build/.aux/<unit>/; build/ is created if
needed and is gitignored. --all builds every folder under units/ that has a
metadata.tex, except the skeleton units/empty. Prints a summary with the
LaTeX warnings per unit; exits non-zero if a build fails (or, with --strict,
has warnings). Needs latexmk; standard library only.
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNITS = ROOT / "units"
BUILD = ROOT / "build"
MAIN = "sw_unit_test_spec.tex"
SKELETON = "empty"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
# A warning runs from its first line to the next empty line (TeX wraps long lines).
WARNING_RE = re.compile(
    r"^(?:(?:LaTeX|Package|Class) [^\n]*Warning|pdfTeX warning).*?(?=\n\s*\n|\Z)",
    re.MULTILINE | re.DOTALL,
)
# An error: "! message" up to the "l.<line> ..." context line.
ERROR_RE = re.compile(r"^! .*?^l\.\d+[^\n]*", re.MULTILINE | re.DOTALL)


def all_units() -> list:
    return sorted(
        d.name
        for d in UNITS.iterdir()
        if d.is_dir() and d.name != SKELETON and (d / "metadata.tex").is_file()
    )


def latexmk_cmd(unit: str, force: bool) -> list:
    cmd = [
        "latexmk",
        "-pdf",
        "-interaction=nonstopmode",
        "-halt-on-error",
        f"-jobname={unit}",
        f"-outdir={BUILD.relative_to(ROOT)}",
        f"-auxdir={(BUILD / '.aux' / unit).relative_to(ROOT)}",
        f"-usepretex=\\def\\SpecUnit{{{unit}}}",
    ]
    if force:
        cmd.append("-g")
    return cmd + [MAIN]


def log_messages(unit: str, pattern: re.Pattern) -> list:
    """Messages of the unit's log matching pattern, each joined into one line."""
    log = BUILD / ".aux" / unit / f"{unit}.log"
    if not log.is_file():
        return []
    text = log.read_text(encoding="latin-1")
    return [" ".join(m.group(0).split()) for m in pattern.finditer(text)]


def plural(n: int, word: str) -> str:
    return f"{n} {word}" + ("" if n == 1 else "s")


def build(unit: str, force: bool, verbose: bool) -> tuple:
    """Return (ok, messages): the errors if the build failed, else the warnings."""
    proc = subprocess.run(
        latexmk_cmd(unit, force),
        check=False,
        cwd=ROOT,
        stdout=None if verbose else subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    pdf = BUILD / f"{unit}.pdf"
    if proc.returncode == 0 and pdf.is_file():
        return True, log_messages(unit, WARNING_RE)
    if pdf.is_file():
        pdf.unlink()  # no stale PDF of an earlier build next to the current ones
    errors = log_messages(unit, ERROR_RE)
    if not errors and not verbose:  # failed before TeX ran: show latexmk's output
        errors = [line for line in proc.stdout.splitlines()[-15:] if line.strip()]
    return False, errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Build units into build/<unit>.pdf.")
    parser.add_argument(
        "units", nargs="*", metavar="unit", help="unit folder names under units/"
    )
    parser.add_argument(
        "--all", action="store_true", help=f"all units except {SKELETON}"
    )
    parser.add_argument(
        "--force", action="store_true", help="rebuild even if up to date (-g)"
    )
    parser.add_argument(
        "--strict", action="store_true", help="fail on LaTeX warnings too"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="show the latexmk output"
    )
    args = parser.parse_args(argv)

    if shutil.which("latexmk") is None:
        print("error: latexmk not found", file=sys.stderr)
        return 1
    units = list(args.units)
    if args.all:
        units += [u for u in all_units() if u not in units]
    if not units:
        parser.error("name at least one unit, or use --all")
    for unit in units:
        if not NAME_RE.fullmatch(unit) or not (UNITS / unit / "metadata.tex").is_file():
            print(
                f"error: units/{unit}/ is not a unit folder (no metadata.tex)",
                file=sys.stderr,
            )
            return 1

    BUILD.mkdir(exist_ok=True)
    failed = []
    for unit in units:
        print(f"building {unit} ...", flush=True)
        ok, messages = build(unit, args.force, args.verbose)
        if ok:
            print(f"  ok      build/{unit}.pdf  ({plural(len(messages), 'warning')})")
        else:
            print(f"  FAILED  {unit}: no PDF ({plural(len(messages), 'error')})")
        for line in messages:
            print(f"    {line}")
        if not ok or (args.strict and messages):
            failed.append(unit)

    print(
        f"{len(units) - len(failed)} of {len(units)} units built"
        + (f"; failed: {', '.join(failed)}" if failed else "")
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
