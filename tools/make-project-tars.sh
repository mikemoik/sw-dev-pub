#!/usr/bin/env bash
# make-project-tars.sh — package sw-dev-pub subprojects as standalone tarballs.
#
#   tools/make-project-tars.sh [-r REV] [-s SUFFIX] [-o OUTDIR] [PROJECT ...]
#
#   PROJECT  name(s) under projects/ (default: all)
#   -r REV   git revision to package (default: HEAD) — committed content only
#   -s SUF   name suffix: <project><SUF>.tar.gz, e.g. -s -1.0.0 (default: none)
#   -o DIR   output dir (default: project-tars/, gitignored)
#
# Each tarball unpacks to <project>/ and contains exactly the tracked files of
# projects/<project>/ at REV (git archive, file times = commit time, gzip -n),
# so the same REV always gives a byte-identical file. Needs git >= 2.41. A <name>.tar.gz.sha256 is written next to each.
set -euo pipefail

rev=HEAD suffix="" out=project-tars
while getopts "r:s:o:h" opt; do
    case $opt in
        r) rev=$OPTARG ;;
        s) suffix=$OPTARG ;;
        o) out=$OPTARG ;;
        *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

root=$(git rev-parse --show-toplevel)
cd "$root"
git rev-parse --verify --quiet "$rev^{commit}" >/dev/null || { echo "unknown revision: $rev" >&2; exit 1; }

if [ $# -eq 0 ]; then
    mapfile -t projects < <(git ls-tree -d --name-only "$rev:projects")
else
    projects=("$@")
fi
[ ${#projects[@]} -gt 0 ] || { echo "no projects at $rev" >&2; exit 1; }

mtime=$(git log -1 --format=%cI "$rev")   # pin file times to the commit -> reproducible
mkdir -p "$out"
for p in "${projects[@]}"; do
    git cat-file -e "$rev:projects/$p" 2>/dev/null || { echo "no project '$p' at $rev" >&2; exit 1; }
    name="$p$suffix.tar.gz"
    git archive --format=tar --mtime="$mtime" --prefix="$p/" "$rev:projects/$p" | gzip -n -9 > "$out/$name"
    (cd "$out" && sha256sum "$name" > "$name.sha256")
    echo "$out/$name"
done
