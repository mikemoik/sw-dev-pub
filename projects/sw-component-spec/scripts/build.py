#!/usr/bin/env python3
"""Build component specifications into build/<component>.pdf.

    python3 scripts/build.py <component> [<component> ...]
    python3 scripts/build.py --all

Runs latexmk once per component (job name = component name, \\SpecComponent = component name).
PDFs go to build/, intermediates to build/.aux/<component>/; build/ is created if
needed and is gitignored. --all builds every folder under components/ that has a
metadata.tex, except the skeleton components/empty. Prints a summary with the
LaTeX warnings per component; exits non-zero if a build fails (or, with --strict,
has warnings). Needs latexmk; standard library only.
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = ROOT / "components"
BUILD = ROOT / "build"
MAIN = "sw_component_spec.tex"
SKELETON = "empty"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
# A warning runs from its first line to the next empty line (TeX wraps long lines).
WARNING_RE = re.compile(
    r"^(?:(?:LaTeX|Package|Class) [^\n]*Warning|pdfTeX warning).*?(?=\n\s*\n|\Z)",
    re.MULTILINE | re.DOTALL,
)
# An error: "! message" up to the "l.<line> ..." context line.
ERROR_RE = re.compile(r"^! .*?^l\.\d+[^\n]*", re.MULTILINE | re.DOTALL)


def all_components() -> list:
    return sorted(
        d.name
        for d in COMPONENTS.iterdir()
        if d.is_dir() and d.name != SKELETON and (d / "metadata.tex").is_file()
    )


def latexmk_cmd(component: str, force: bool) -> list:
    cmd = [
        "latexmk",
        "-pdf",
        "-interaction=nonstopmode",
        "-halt-on-error",
        f"-jobname={component}",
        f"-outdir={BUILD.relative_to(ROOT)}",
        f"-auxdir={(BUILD / '.aux' / component).relative_to(ROOT)}",
        f"-usepretex=\\def\\SpecComponent{{{component}}}",
    ]
    if force:
        cmd.append("-g")
    return cmd + [MAIN]


def log_messages(component: str, pattern: re.Pattern) -> list:
    """Messages of the component's log matching pattern, each joined into one line."""
    log = BUILD / ".aux" / component / f"{component}.log"
    if not log.is_file():
        return []
    text = log.read_text(encoding="latin-1")
    return [" ".join(m.group(0).split()) for m in pattern.finditer(text)]


def plural(n: int, word: str) -> str:
    return f"{n} {word}" + ("" if n == 1 else "s")


def build(component: str, force: bool, verbose: bool) -> tuple:
    """Return (ok, messages): the errors if the build failed, else the warnings."""
    proc = subprocess.run(
        latexmk_cmd(component, force),
        check=False,
        cwd=ROOT,
        stdout=None if verbose else subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    pdf = BUILD / f"{component}.pdf"
    if proc.returncode == 0 and pdf.is_file():
        return True, log_messages(component, WARNING_RE)
    if pdf.is_file():
        pdf.unlink()  # no stale PDF of an earlier build next to the current ones
    errors = log_messages(component, ERROR_RE)
    if not errors and not verbose:  # failed before TeX ran: show latexmk's output
        errors = [line for line in proc.stdout.splitlines()[-15:] if line.strip()]
    return False, errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Build components into build/<component>.pdf.")
    parser.add_argument(
        "components", nargs="*", metavar="component", help="component folder names under components/"
    )
    parser.add_argument(
        "--all", action="store_true", help=f"all components except {SKELETON}"
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
    components = list(args.components)
    if args.all:
        components += [u for u in all_components() if u not in components]
    if not components:
        parser.error("name at least one component, or use --all")
    for component in components:
        if not NAME_RE.fullmatch(component) or not (COMPONENTS / component / "metadata.tex").is_file():
            print(
                f"error: components/{component}/ is not a component folder (no metadata.tex)",
                file=sys.stderr,
            )
            return 1

    BUILD.mkdir(exist_ok=True)
    failed = []
    for component in components:
        print(f"building {component} ...", flush=True)
        ok, messages = build(component, args.force, args.verbose)
        if ok:
            print(f"  ok      build/{component}.pdf  ({plural(len(messages), 'warning')})")
        else:
            print(f"  FAILED  {component}: no PDF ({plural(len(messages), 'error')})")
        for line in messages:
            print(f"    {line}")
        if not ok or (args.strict and messages):
            failed.append(component)

    print(
        f"{len(components) - len(failed)} of {len(components)} components built"
        + (f"; failed: {', '.join(failed)}" if failed else "")
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
