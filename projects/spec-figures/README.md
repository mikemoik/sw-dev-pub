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

**Command reference:** `llm/<type>.md` (one guide per type, also used by the LLM), with the worked examples `tikz/<type>.tex` and `mermaid/<type>.mmd`. `spec_figures.pdf` shows every figure next to its sources.

## Files

```
sty/specfig.sty           core + UML and block diagrams (loads the two below)
sty/specfig-plan.sty      Gantt, timeline, organisation chart, RACI
sty/specfig-chart.sty     risk matrix, timing diagram, bar and line charts
tikz/<type>.tex           worked TikZ example per type
mermaid/<type>.mmd        Mermaid twin per type
llm/                      LLM guides: _common.md + one per type
spec_figures.tex / .pdf   catalogue: every figure with its sources (PDF committed as preview)
tests/problems.*          deliberate mistakes and the warnings they must give
scripts/check.py          test: catalogue 0 warnings, problem marks, rules up to date, Mermaid (if mmdc)
scripts/llm_prompt.py     chat prompt for one figure type
scripts/continue_rules.py generates .continue/rules/sf-*.md from llm/, tikz/, mermaid/
scripts/vendor.py         copies specfig and the rules into a template
```

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

As in the templates (chat only). Name figure files after their type (`figures/gantt_plan.tex`, `gantt_plan.mmd`): with such a file in the chat, Continue adds the common rules and the guide and examples for that type. Without Continue, use:

```sh
python3 scripts/llm_prompt.py sequence -o build/prompt.md               # TikZ
python3 scripts/llm_prompt.py gantt --mermaid --add plan.csv -o build/prompt.md
python3 scripts/llm_prompt.py state --edit figures/state_modes.tex -o build/prompt.md
```

A prompt is about 2K–3K tokens plus the `--add` files. After changing `llm/`, `tikz/` or `mermaid/`, run `python3 scripts/continue_rules.py` and `vendor.py` for each template.

## Test

```sh
python3 scripts/check.py           # rebuilds spec_figures.pdf; --no-pdf leaves it alone
```

The Mermaid check runs only if `mmdc` (mermaid-cli) is on the PATH.
