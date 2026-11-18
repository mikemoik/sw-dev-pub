#!/usr/bin/env python3
"""Remove build output so that the next build starts clean.

    python3 scripts/clean.py                    # everything
    python3 scripts/clean.py <document> [<document> ...]
    python3 scripts/clean.py -n ...             # only list what would go

Covers both ways of building:
- scripts/build.py: build/<document>.pdf and build/.aux/<document>/
  (everything: build/).
- an IDE or plain latexmk in the root folder: <job>.pdf and the LaTeX
  intermediates (<job>.aux, .log, ...) next to the main file,
  with job = document name (-jobname=<document>) or spec_figures (no
  -jobname; builds the document named in \\LoadFigures, so it counts as
  that document).

Removes only files with these job names and extensions, nothing else.
Never removes spec_figures.pdf, the committed preview.
Standard library only.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIGURES = ROOT / "figures"
BUILD = ROOT / "build"
MAIN = "spec_figures.tex"
PREVIEW = ROOT / (Path(MAIN).stem + ".pdf")  # committed, kept
DEFAULT_RE = re.compile(r"^\s*\\LoadFigures\{([^}]*)\}", re.MULTILINE)
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
# Output of pdflatex/latexmk/SyncTeX.
SUFFIXES = [
    ".pdf",
    ".aux",
    ".fdb_latexmk",
    ".fls",
    ".log",
    ".ltc",
    ".out",
    ".toc",
    ".xdv",
    ".synctex.gz",
    ".synctex(busy)",
    ".synctex.gz(busy)",
    ".synctex",
    ".lof",
    ".lot",
    ".bbl",
    ".blg",
    ".run.xml",
    ".bcf",
]


def default_document() -> str:
    m = DEFAULT_RE.search((ROOT / MAIN).read_text(encoding="utf-8"))
    return m.group(1).strip() if m else ""


def job_files(job: str) -> list:
    """Root-folder files of LaTeX job `job`."""
    return sorted(
        p
        for p in ROOT.glob(f"{glob_escape(job)}.*")
        if p.is_file() and p.name[len(job) :] in SUFFIXES
    )


def glob_escape(name: str) -> str:
    return re.sub(r"([*?\[])", r"[\1]", name)


def remove(path: Path, dry_run: bool) -> None:
    print(
        ("would remove " if dry_run else "removed ")
        + str(path.relative_to(ROOT))
        + ("/" if path.is_dir() else "")
    )
    if dry_run:
        return
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Remove build output (build/ and LaTeX files in the root)."
    )
    parser.add_argument(
        "documents",
        nargs="*",
        metavar="document",
        help="document names (default: everything)",
    )
    parser.add_argument(
        "-n", "--dry-run", action="store_true", help="only list what would be removed"
    )
    args = parser.parse_args(argv)
    for document in args.documents:
        if not NAME_RE.fullmatch(document):
            print(f"error: not a document name: {document}", file=sys.stderr)
            return 1

    main_job = Path(MAIN).stem
    targets = []
    if args.documents:
        for document in args.documents:
            targets += [BUILD / f"{document}.pdf", BUILD / ".aux" / document]
            targets += job_files(document)
            if document == default_document():
                targets += job_files(main_job)
    else:
        targets.append(BUILD)
        jobs = {main_job} | {d.name for d in FIGURES.iterdir() if d.is_dir()}
        for job in sorted(jobs):
            targets += job_files(job)

    found = [p for p in dict.fromkeys(targets) if p.exists() and p != PREVIEW]
    for path in found:
        remove(path, args.dry_run)
    if not found:
        print("nothing to remove")
    return 0


if __name__ == "__main__":
    sys.exit(main())
