#!/usr/bin/env python3
"""Build figure documents (folders figures/<document>/) into build/<document>.pdf.

    python3 scripts/build.py <document> [<document> ...]
    python3 scripts/build.py --all

Runs latexmk once per document (job name = document name, \\SpecFigures = document name).
PDFs go to build/, intermediates to build/.aux/<document>/; build/ is created if
needed and is gitignored. --all builds every folder under figures/ that has a
document.tex, except the skeleton figures/empty. Prints a summary with the
LaTeX warnings per document; exits non-zero if a build fails (or, with --strict,
has warnings). Needs latexmk; standard library only.
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIGURES = ROOT / "figures"
BUILD = ROOT / "build"
MAIN = "spec_figures.tex"
SKELETON = "empty"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
# A warning runs from its first line to the next empty line (TeX wraps long lines).
WARNING_RE = re.compile(
    r"^(?:(?:LaTeX|Package|Class) [^\n]*Warning|pdfTeX warning).*?(?=\n\s*\n|\Z)",
    re.MULTILINE | re.DOTALL,
)
# An error: "! message" up to the "l.<line> ..." context line.
ERROR_RE = re.compile(r"^! .*?^l\.\d+[^\n]*", re.MULTILINE | re.DOTALL)


def all_documents() -> list:
    return sorted(
        d.name
        for d in FIGURES.iterdir()
        if d.is_dir() and d.name != SKELETON and (d / "document.tex").is_file()
    )


def latexmk_cmd(document: str, force: bool) -> list:
    cmd = [
        "latexmk",
        "-pdf",
        "-interaction=nonstopmode",
        "-halt-on-error",
        f"-jobname={document}",
        f"-outdir={BUILD.relative_to(ROOT)}",
        f"-auxdir={(BUILD / '.aux' / document).relative_to(ROOT)}",
        f"-usepretex=\\def\\SpecFigures{{{document}}}",
    ]
    if force:
        cmd.append("-g")
    return cmd + [MAIN]


def log_messages(document: str, pattern: re.Pattern) -> list:
    """Messages of the document's log matching pattern, each joined into one line."""
    log = BUILD / ".aux" / document / f"{document}.log"
    if not log.is_file():
        return []
    text = log.read_text(encoding="latin-1")
    return [" ".join(m.group(0).split()) for m in pattern.finditer(text)]


def plural(n: int, word: str) -> str:
    return f"{n} {word}" + ("" if n == 1 else "s")


def build(document: str, force: bool, verbose: bool) -> tuple:
    """Return (ok, messages): the errors if the build failed, else the warnings."""
    proc = subprocess.run(
        latexmk_cmd(document, force),
        check=False,
        cwd=ROOT,
        stdout=None if verbose else subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    pdf = BUILD / f"{document}.pdf"
    if proc.returncode == 0 and pdf.is_file():
        return True, log_messages(document, WARNING_RE)
    if pdf.is_file():
        pdf.unlink()  # no stale PDF of an earlier build next to the current ones
    errors = log_messages(document, ERROR_RE)
    if not errors and not verbose:  # failed before TeX ran: show latexmk's output
        errors = [line for line in proc.stdout.splitlines()[-15:] if line.strip()]
    return False, errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Build documents into build/<document>.pdf."
    )
    parser.add_argument(
        "documents",
        nargs="*",
        metavar="document",
        help="document folder names under figures/",
    )
    parser.add_argument(
        "--all", action="store_true", help=f"all documents except {SKELETON}"
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
    documents = list(args.documents)
    if args.all:
        documents += [u for u in all_documents() if u not in documents]
    if not documents:
        parser.error("name at least one document, or use --all")
    for document in documents:
        if (
            not NAME_RE.fullmatch(document)
            or not (FIGURES / document / "document.tex").is_file()
        ):
            print(
                f"error: figures/{document}/ is not a document folder (no document.tex)",
                file=sys.stderr,
            )
            return 1

    BUILD.mkdir(exist_ok=True)
    failed = []
    for document in documents:
        print(f"building {document} ...", flush=True)
        ok, messages = build(document, args.force, args.verbose)
        if ok:
            print(
                f"  ok      build/{document}.pdf  ({plural(len(messages), 'warning')})"
            )
        else:
            print(f"  FAILED  {document}: no PDF ({plural(len(messages), 'error')})")
        for line in messages:
            print(f"    {line}")
        if not ok or (args.strict and messages):
            failed.append(document)

    print(
        f"{len(documents) - len(failed)} of {len(documents)} documents built"
        + (f"; failed: {', '.join(failed)}" if failed else "")
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
