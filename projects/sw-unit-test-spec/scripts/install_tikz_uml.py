#!/usr/bin/env python3
"""Install tikz-uml.sty into the user's TeX tree (it is not on CTAN / in TeX Live).

    python3 scripts/install_tikz_uml.py [--file tikz-uml.sty] [--texmf DIR] [--force]

Downloads the pinned release of TikZ-UML (N. Kielbasiewicz, LPPL 1.3) and
writes it to <TEXMFHOME>/tex/latex/tikz-uml/tikz-uml.sty, where every LaTeX
run of this user finds it. No root rights, nothing else is changed. The file
is checked against a SHA-256 before it is installed. Without internet access,
download the file by hand (URL below) and pass it with --file.
Standard library only.
"""

import argparse
import hashlib
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "v1.1"
URL = f"https://plmlab.math.cnrs.fr/tikzuml/tikzuml/-/raw/{VERSION}/tikz-uml.sty"
SHA256 = "8e6e1c41d8cabc3036bf353384aac549005fc503d5269c001419b5c8018e1a69"
NAME = "tikz-uml.sty"


def kpsewhich(*args: str) -> str:
    """Output of kpsewhich, '' if nothing was found."""
    result = subprocess.run(
        ["kpsewhich", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return result.stdout.strip()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description=f"Install {NAME} {VERSION} into the user's TeX tree (TEXMFHOME)."
    )
    parser.add_argument(
        "--file",
        type=Path,
        metavar="FILE",
        help=f"use this {NAME} instead of downloading {URL}",
    )
    parser.add_argument(
        "--texmf",
        type=Path,
        metavar="DIR",
        help="TeX tree to install into (default: TEXMFHOME)",
    )
    parser.add_argument(
        "--force", action="store_true", help="replace an installed file"
    )
    args = parser.parse_args(argv)

    try:
        texmf = args.texmf or Path(kpsewhich("-var-value", "TEXMFHOME") or "")
        found = kpsewhich(NAME)
    except FileNotFoundError:
        print(
            "error: kpsewhich not found: is a TeX distribution installed?",
            file=sys.stderr,
        )
        return 1
    if not texmf.parts:
        print("error: TEXMFHOME is not set: pass --texmf DIR", file=sys.stderr)
        return 1
    target = texmf.expanduser() / "tex" / "latex" / "tikz-uml" / NAME

    if not args.force and (found or target.exists()):
        print(f"{NAME} is already installed: {found or target} (--force replaces it)")
        return 0

    try:
        if args.file:
            data = args.file.read_bytes()
        else:
            print(f"downloading {URL}")
            with urllib.request.urlopen(URL, timeout=60) as response:
                data = response.read()
    except OSError as err:
        print(f"error: cannot read {args.file or URL}: {err}", file=sys.stderr)
        return 1
    digest = hashlib.sha256(data).hexdigest()
    if digest != SHA256:
        print(
            f"error: not {NAME} {VERSION}: SHA-256 is {digest}, expected {SHA256}",
            file=sys.stderr,
        )
        return 1

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"installed {NAME} {VERSION}: {target}")
    if found and Path(found).resolve() != target.resolve():
        print(f"warning: LaTeX still uses {found}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
