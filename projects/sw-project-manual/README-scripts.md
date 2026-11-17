# Scripts: new manuals and building

Run from the template's root folder. Python 3.6+ (standard library only) and `latexmk` are needed.

## Shipped manuals

- `manuals/empty/`: the skeleton for new manuals. It holds commented command templates and no content. `new_manual.py` copies it.
- `manuals/sample/`: a fully filled worked example (the project developing `heater_ctrl`). Use it to check that your setup builds (`python3 scripts/build.py sample`), and as a reference for how each content command and free-text block is used.

## New manual

```sh
python3 scripts/new_manual.py brake_mon                 # copies manuals/empty/ to manuals/brake_mon/
python3 scripts/new_manual.py brake_mon --from sample   # copies another manual instead
```

Manual names: letters, digits, `_`, `-`, `.`. The script also sets `\ComponentName{brake_mon}` (one project develops one component; change it if the names differ). Then fill in the files in `manuals/brake_mon/`.

## Build

```sh
python3 scripts/build.py brake_mon          # -> build/brake_mon.pdf
python3 scripts/build.py brake_mon sample   # several manuals
python3 scripts/build.py --all              # all manuals except manuals/empty
```

| Option | Effect |
|---|---|
| `--force` | rebuild even if up to date |
| `--strict` | LaTeX warnings count as failure (e.g. CI) |
| `-v` | show the latexmk output |

PDFs go to `build/<manual>.pdf` (gitignored, safe to delete). At the end you get a summary of each manual's warnings and errors. If a manual fails, its PDF is removed and the script exits non-zero.

## Clean

```sh
python3 scripts/clean.py              # everything
python3 scripts/clean.py sample       # one manual
python3 scripts/clean.py -n           # only list what would be removed
```

Removes the PDFs and LaTeX intermediates of `build.py` (`build/`) and of IDE or `latexmk` builds in the root folder (`<manual>.*`, `sw_project_manual.*`). The committed preview `sw_project_manual.pdf` is kept.

## Open point list from GitLab

```sh
python3 scripts/gitlab_opl.py brake_mon issues.csv --date 2026-11-30               # -> manuals/brake_mon/opl.tex
python3 scripts/gitlab_opl.py brake_mon issues.csv --date 2026-11-30 --comment Milestone
```

Input: the CSV of *Issues → Export as CSV*. Conventions: label `workflow::in progress` marks in-progress issues, `top::1` … `top::5` the top 5. Closed issues take the date of *Closed At*. `--date` is the export date (default today); due dates before it are marked overdue. The script rewrites `opl.tex` on every run. It refuses to overwrite one that has open points it did not write, unless you pass `--force`.

Exports that don't follow the conventions: `--slim issues_slim.csv` keeps only the needed columns, then use the LLM chat below with `opl` (`--add issues_slim.csv`).

## Chat with an LLM

Guides in `llm/` tell a chat model how the template works, so it can help fill in a manual's content files ("add a risk for a late supplier release"). The model asks for missing facts and answers with LaTeX lines to paste.

**VS Code with Continue:** with the template folder open as workspace, Continue loads the matching context (common rules, the guide for that file, command reference, example) automatically when a content file such as `manuals/<manual>/risks.tex` is in the chat. Use Chat mode only.

**Any other chat:** `scripts/llm_prompt.py` puts the same rules, the guide, the manual's file and the related files into one prompt to paste as the first chat message:

```sh
python3 scripts/llm_prompt.py brake_mon risks -o build/prompt.md
python3 scripts/llm_prompt.py brake_mon development --add ../.gitlab-ci.yml -o build/prompt.md   # with extra input
python3 scripts/llm_prompt.py brake_mon opl --add opl_export.csv -o build/prompt.md                 # open point list from an export
```

The prompt is about 2.5K–4.5K tokens plus `--add` files. Above 32000 it warns (`--max-tokens`). `--no-example` leaves out the worked example from `manuals/sample/`.

**Maintainers:** `llm/_common.md` (role, chat protocol, LaTeX rules, shared helpers) and `llm/<file>.md` (one guide per content file) are the source. `.continue/rules/` is generated from them plus `manuals/empty/` and `manuals/sample/`, and committed. After changing any of these:

```sh
python3 scripts/continue_rules.py           # regenerate .continue/rules/
python3 scripts/continue_rules.py --check   # exit 1 if out of date (e.g. in CI)
```

More details are in [README.md](README.md).
