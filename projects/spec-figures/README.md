# spec-figures

Templates for the figures that software specifications and project manuals commonly need, written so that a chat LLM can create them from free text or a pasted table. Each figure type has two independent templates:

- **TikZ** via the LaTeX package **specfig**: one environment per figure, holding plain data commands (one command = one element or connection). The layout, the drawing and the consistency checks are generated, and problems show in red under the figure.
- **Mermaid** for Markdown pages (Mermaid 10 or newer). There is no conversion between the two.

Supporting project of [`sw-unit-test-spec`](../sw-unit-test-spec/), [`sw-component-spec`](../sw-component-spec/) and [`sw-project-manual`](../sw-project-manual/), which carry a copy of specfig in their `sty/`.

**Owner:** swdevos · **Status:** new, builds clean (TeX Live 2026 and 2022) · **License:** MIT (repo root)

## Figure types

| Type | Environment | Mermaid twin |
|---|---|---|
| `sequence` | `sfSequence` | `sequenceDiagram` |
| `state` | `sfStateMachine` | `stateDiagram-v2` |
| `activity` | `sfActivity` | `flowchart TD` |
| `usecase` | `sfUseCase` | `flowchart LR` |
| `class` | `sfClassDiagram` | `classDiagram` |
| `component` | `sfComponent` | `flowchart LR` |
| `deployment` | `sfDeployment` | `flowchart LR` |
| `package` | `sfPackage` | `flowchart LR` |
| `block` (block / context) | `sfBlock` | `flowchart LR` |
| `flowchart` | `sfFlowchart` | `flowchart TD` |
| `gantt` | `sfGantt` | `gantt` |
| `timeline` (milestones) | `sfTimeline` | `timeline` |
| `orgchart` | `sfOrgChart` | `flowchart TD` |
| `raci` (a table) | `sfRaci` | Markdown table (`mermaid/raci.md`) |
| `risk` (risk matrix) | `sfRiskMatrix` | `quadrantChart` |
| `timing` | `sfTiming` | none |
| `barchart` | `sfBarChart` | `xychart-beta` |
| `linechart` | `sfLineChart` | `xychart-beta` |

**Command reference:** `llm/<type>.md` (one guide per type, also used by the LLM), with the worked examples `figures/sample/<type>.tex` and `mermaid/<type>.mmd`. `spec_figures.pdf` (the sample document) shows every figure and feature next to its sources, with a how-to.

## Files

```
sty/specfig.sty           core + UML and block diagrams (loads the two below)
sty/specfig-plan.sty      Gantt, timeline, organisation chart, RACI
sty/specfig-chart.sty     risk matrix, timing diagram, bar and line charts
spec_figures.tex          main file: document commands, default document (\LoadFigures{sample})
spec_figures.pdf          the sample document, built: committed preview
figures/
  sample/                 every type and feature + how-to; <type>.tex = worked example per type
  empty/                  skeleton for new documents
  <document>/             one folder per figure document: document.tex + one file per figure
mermaid/<type>.mmd        Mermaid twin per type
llm/                      LLM guides: _common.md, _document.md (document.tex) + one per type
tests/problems.*          deliberate mistakes and the warnings they must give
scripts/new_figures.py    creates figures/<document>/ from figures/empty/
scripts/build.py          builds documents into build/<document>.pdf
scripts/clean.py          removes build output (build/ and root LaTeX files)
scripts/check.py          test: sample + empty 0 warnings, sample covers every feature, problem marks, rules, Mermaid (if mmdc)
scripts/llm_prompt.py     chat prompt for one figure type
scripts/llm_context.py    writes figures/<document>/llm-context.md: whole document as one chat context (run after every build)
scripts/continue_rules.py generates .continue/rules/sf-*.md from llm/, figures/sample/, mermaid/
scripts/vendor.py         copies specfig and the rules into a template
```

## Figure documents

A figure document is a folder `figures/<document>/`: `document.tex` (ordinary LaTeX text) plus one file per figure, built by `spec_figures.tex`. Use one to draft the figures of a specification, or as a figure collection of its own. `figures/sample/` is the reference and the test: if it builds without warnings, specfig works on that checkout and machine.

```sh
python3 scripts/new_figures.py brake_mon                 # copies figures/empty/ (--from sample: the sample)
python3 scripts/build.py brake_mon                       # -> build/brake_mon.pdf; --all, --strict, --force, -v
python3 scripts/clean.py                                 # everything; or: clean.py brake_mon; -n lists only
latexmk -pdf spec_figures.tex                            # the document in \LoadFigures -> spec_figures.pdf
```

In `document.tex`: `\InputFigure[max width]{name}` (figure file `name.tex`, or an image `name.pdf/.png/.jpg`, as in the templates), `\ShowFigure{name}` (figure + source), `\ShowSource{file}`, `\ShowMermaid{type}`, `\Title{title}{subtitle}`, `\FigDir`. `\SpecFigures` selects the document at build time (`-usepretex='\def\SpecFigures{brake_mon}'`, one job name per document, as `build.py` does).

## Use in a document

Requirements: pdfLaTeX, TeX Live 2022 or newer, T1 font encoding (`\usepackage[T1]{fontenc}`). Put `sty/` on TeX's search path (`latexmkrc`: `ensure_path('TEXINPUTS', './sty//');`) and load the package after the document class (before `underscore`, if used):

```latex
\usepackage{specfig}
```

A figure is its environment, e.g. in `figures/sequence_ctrl_cycle.tex`, included with `\InputFigure{sequence_ctrl_cycle}` in the templates:

```latex
\begin{sfSequence}
  \Participant{sched}{Scheduler}
  \Participant{ctrl}{heater_ctrl}
  \Message{sched}{ctrl}{heater_ctrl_step()}
  \Reply{ctrl}{sched}{status}
\end{sfSequence}
```

The data commands exist only inside their environment, so they don't clash with a document's own `\Milestone`, `\Risk` and so on. Diagrams with boxes place elements on a grid `[column,row]`; without a position, an element goes next to the previous one.

**In the templates:** `python3 scripts/vendor.py ../sw-project-manual` copies `sty/specfig*.sty` and the Continue rules there (`--check` reports whether they are up to date). Rerun it after every change here. The templates don't load specfig themselves: add `\usepackage{specfig}` after `\documentclass{…}` in the main file.

## Chat with an LLM

As in the templates (chat only, e.g. Gemma 4 in Continue). Name figure files after their type (`figures/brake_mon/gantt_plan.tex`, `gantt_plan.mmd`): with such a file in the chat, Continue adds the common rules and the guide and examples for that type; with `document.tex` in the chat, the rules for the document text (`llm/_document.md`). Without Continue, use:

```sh
python3 scripts/llm_prompt.py sequence -o build/prompt.md               # TikZ
python3 scripts/llm_prompt.py gantt --mermaid --add plan.csv -o build/prompt.md
python3 scripts/llm_prompt.py state --edit figures/brake_mon/state_modes.tex -o build/prompt.md
```

A prompt is about 2K–3K tokens plus the `--add` files.

**Whole figure document in one file:** every build (`build.py`, `latexmk`, also each `-pvc` rebuild) rewrites `figures/<document>/llm-context.md` through `latexmkrc`: the rules, the document guide, the guides (and examples) of the figure types the document uses, an index of the figure files with their IDs, and all files of the document. In Continue, reference only that file (`@llm-context.md`) for requests that touch several figures or the text. About 3K–6K tokens for a few figures, ~23K for the sample. The file is the state of the last build: after applying an answer, save, rebuild, and start a new chat.

```sh
python3 scripts/llm_context.py brake_mon            # write it without building
python3 scripts/llm_context.py brake_mon --check    # exit 1 if out of date
```

After changing `llm/`, `figures/sample/<type>.tex` or `mermaid/`, run `python3 scripts/continue_rules.py` and `vendor.py` for each template (the templates get every rule except the one for `document.tex`).

## Test

```sh
python3 scripts/check.py           # rebuilds spec_figures.pdf; --no-pdf leaves it alone
```

It builds `sample` and `empty` as `build.py --strict` does (also no overfull boxes), checks that the sample uses every command and option of the guides, the problem marks of `tests/problems.tex`, and that the rules and `figures/sample/llm-context.md` are up to date. A new feature needs a figure in `figures/sample/` and a line in its guide.

The Mermaid check runs only if `mmdc` (mermaid-cli) is on the PATH.
