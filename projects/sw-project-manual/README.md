# sw-project-manual

LaTeX template for a **Software Project Manual**: one document per project that develops one software component. It holds the project plan (organisation and roles, process and tailoring, milestones and releases, work products and reviews, configuration and change management, quality assurance, risks, tools) and a developer manual (engineering rules, CI pipeline, Definition of Done, step-by-step how-tos), and ends with the project's open point list, converted from an export (e.g. by a chat LLM). It covers the plans expected by Automotive SPICE 4.0 MAN.3, MAN.5, SUP.1, SUP.8, SUP.9 and SUP.10. The functional safety plan (ISO 26262-2) is a separate document. The template addresses those processes; it does not make a project compliant: content, reviews and evidence remain the project's job.

Sister of [`sw-unit-test-spec`](../sw-unit-test-spec/) and [`sw-component-spec`](../sw-component-spec/), with the same content model, tooling and rules. Content is written as plain data commands in `manuals/<manual>/*.tex`, and all layout lives in `swpm.cls`. Tables, diagrams and the responsibility matrix are generated, and inconsistencies show in red. The manual lists the project's specifications as work products.

**Owner:** swdevos · **Status:** new, builds clean (TeX Live 2026 and 2022) · **License:** MIT (repo root)

## Files

```
sw_project_manual.tex     main file: chapter order, default manual
swpm.cls                  the template: all formatting and input commands
latexmkrc                 latexmk settings: -c also removes the free-text helper files, sty/ on TEXINPUTS, llm-context.md after each build
sty/                      packages found without install: specfig*.sty (see Diagrams)
sw_project_manual.pdf     the sample manual, built: a preview of what the template produces
scripts/new_manual.py     creates manuals/<manual>/ from manuals/empty/
scripts/build.py          builds manuals into build/<manual>.pdf
scripts/clean.py          removes build output (build/ and root LaTeX files)
scripts/gitlab_opl.py     writes a manual's opl.tex from a GitLab issue CSV export
scripts/new_figure.py     creates a specfig figure file from the example of its type (from spec-figures)
scripts/sf_figures.py     figure types and chat guides for the scripts (from spec-figures)
scripts/llm_prompt.py     builds a chat prompt so an LLM can help edit a manual's file
scripts/llm_context.py    writes manuals/<manual>/llm-context.md: whole manual + guides as one chat context (run after every build)
llm/                      the guides it uses: general rules + one per content file
scripts/continue_rules.py generates .continue/rules/ from llm/ (Continue chat in VS Code)
.continue/rules/          generated: the guides as Continue rules, one per content file
README-scripts.md         short usage of the scripts, incl. LLM chat help
figures/  data/  code/    shared by all manuals (a manual's own file of the same name wins)
packages.tex              project packages (\usepackage), loaded by the class for every manual
macros.tex                project macros for every manual (a manual's macros.tex may override them)
manuals/
  empty/                  skeleton for new manuals: commented command templates, no content
  sample/                 worked example (the project developing heater_ctrl)
    data/                 sample exports of a mockup planning tool (milestones, CSV) and risk tool (JSON), not in template format
  <manual>/               one folder per project:
    macros.tex            the manual's own macros, read before the content files
    metadata.tex …        content files (table below)
    figures/ data/ code/  the manual's own figures, data and source files
```

| Content file (in `manuals/<manual>/`) | Chapter |
|---|---|
| `metadata.tex` | title page, Document Control: document and project data, revision history |
| `introduction.tex` | 1 Introduction: purpose, scope, project identification, objectives, deliverables, references, terms |
| `organization.tex` | 2 Organization: roles + organisation chart, team, stakeholders, meetings, reporting |
| `lifecycle.tex` | 3 Process and Lifecycle: process reference, process tailoring, milestones and releases + timeline |
| `workproducts.tex` | 4 Work Products: list, reviews, responsibility matrix (RACI) |
| `configuration.tex` | 5 Configuration and Change Management: configuration items, branching, baselines, naming, change/problem workflows, release procedure |
| `quality.tex` | 6 Quality Assurance: activities, metrics, escalation |
| `risks.tex` | 7 Risk Management: risk matrix, risk register |
| `environment.tex` | 8 Tools and Environment: tools, classification, tool qualification |
| `development.tex` | 9 Developer Manual: engineering rules, CI pipeline, Definition of Done, how-tos |
| `opl.tex` | 10 Open Point List: top 5 (repeated), in progress, open, closed; top-5 points highlighted |

## Build

Same requirements as `sw-unit-test-spec`: a TeX distribution with `latexmk` and `xltabular`, `enumitem`, `fancyhdr`, `lastpage`, `underscore`, `microtype`, `fancyvrb`, `tikz` (pgf), `adjustbox`, `needspace`; Python 3.6+ (standard library only). Run everything from the template's root folder.

```sh
python3 scripts/new_manual.py brake_mon     # new manual: copies manuals/empty/
python3 scripts/build.py brake_mon          # -> build/brake_mon.pdf
python3 scripts/build.py --all              # every manual except manuals/empty
latexmk -pdf sw_project_manual.tex          # the default manual (\LoadManual{sample}) -> sw_project_manual.pdf
```

`\SpecManual` selects the manual at build time (`-usepretex='\def\SpecManual{brake_mon}'`, one job name per manual, as `build.py` does). `sw_project_manual.pdf` is committed as a preview of the sample; rebuild it whenever the template or the sample changes.

## Using it for a project

Exactly as `sw-unit-test-spec` (README there, *Using it for a project*), with `manuals/` for `units/`, `new_manual.py` for `new_unit.py` and `\LoadManual` for `\LoadUnit`. Reference the project's unit test specs and component spec with `\Reference` and list them as `\WorkProduct`s.

## Writing content

Replace the text inside `{…}`. Underscores need no escaping; escape only `\%` `\&` `\#` `\$` `\{ \}`. Anything left out shows as a grey `⟨placeholder⟩` or `none`. Values for your own text: `\TheProject`, `\TheComponent`, `\TheIntegrityLevel`. Cite a reference with `\DocRef{key}`.

Roles, processes, milestones and work products are declared with an ID; tools with their name. Every other command refers to them by that ID or name:

```latex
\Role[PL]{SWA}{Software architect}{Requirements analysis, architecture}      % organization.tex
\Member{John Roe}{SWA}{Example Corp}
\Process{SWE.2}{Software architectural design}{yes}{}                        % lifecycle.tex
\Milestone{M2}{2027-02-12}{Architecture released}{WP-SWCS}
\WorkProduct{WP-SWCS}{Software component specification}{SWE.2, SWE.5}{SWA}{sw-component-spec template}
\Review{WP-SWCS}{Inspection with checklist}{DEV, TST}{PL}                    % R=SWA, A=PL, C=DEV,TST
\Tool{cppcheck}{MISRA C:2012 static analysis}{2.16}{TI2, TD2: TCL2}          % environment.tex
\CIStage{Static analysis}{MISRA check}{cppcheck}{yes}                        % development.tex
```

How-tos take one `\Step{action}{command}` per step; the command is printed in typewriter on its own line:

```latex
\begin{HowTo}{HT-SETUP}{Set up the workspace}
  \Goal{A fresh clone that builds and runs the tests.}
  \Tools{CMake, GCC}
  \Step{Configure the host build.}{cmake --preset host}
  \Step{Build and run all tests.}{cmake --build --preset host \&\& ctest --preset host}
\end{HowTo}
```

## Diagrams

Generated with TikZ from the data you already enter. Each diagram only appears when its data exists.

| Diagram | Where | Built from |
|---|---|---|
| **Organisation chart**: roles as a tree, members in the boxes | 2.1 *Roles* | `\Role[reports to]`, `\Member` |
| **Timeline**: milestones above the line, releases below; to scale if all dates are YYYY-MM-DD, else evenly spaced | 3.3 | `\Milestone`, `\Release` |
| **Workflow**: states left to right, one chain per workflow | 5.5 | `\Workflow` |
| **Risk matrix**: probability × impact, risk IDs in green/yellow/red cells | 7 | `\Risk` |
| **CI pipeline**: stages left to right with their tools | 9.2 | `\CIStage` |

Tables generated beyond the plain lists: work products per process (3.2), the RACI matrix (4.3).

### specfig figures

[`spec-figures`](../spec-figures/) draws 18 figure types (UML, block and flow diagrams, Gantt chart, timeline, organisation chart, RACI, risk matrix, timing diagram, bar and line charts) from plain data commands, with problems in red. `swpm.cls` loads it. Its packages (`sty/specfig*.sty`), chat rules (`.continue/rules/sf-*.md`) and `scripts/new_figure.py` + `scripts/sf_figures.py` come from there: don't edit them here, refresh them with spec-figures' `scripts/vendor.py`. A figure is a file `figures/<type>_<name>.tex` in the manual's folder, started from the type's worked example:

```sh
python3 scripts/new_figure.py --list                      # the types
python3 scripts/new_figure.py brake_mon sequence cycle   # -> manuals/brake_mon/figures/sequence_cycle.tex
```

Include it in a free-text block with `\InputFigure{sequence_cycle}` in a `figure` environment; the sample does this in `lifecycle.tex` (`figures/gantt_plan.tex`). Command reference: the spec-figures guides and its sample document.

## Free text, figures, code and data

As in `sw-unit-test-spec` (README there, *Free text* and *Figures, code and data*), with `\ManualDir` for `\UnitDir`. A `FreeText` block is printed at the end of its file's chapter. The sample lists a CI configuration from its `code/` folder with `\InputCode`.

## Command reference

The text commands `\Purpose`, `\Scope`, `\Communication`, `\ProcessReference`, `\BranchingModel`, `\ReleaseProcedure`, `\Escalation` and `\ToolQualification` also work as environments with any LaTeX inside (`\end{...}` on its own line). Given twice, the last one is used (warning).

| File | Command | Produces |
|---|---|---|
| metadata | `\DocID{}` `\DocVersion{}` `\DocStatus{}` `\DocDate{}` `\DocTitle{}` `\ProjectName{}` `\ProjectID{}` `\Customer{}` `\Company{}` | title page, header/footer, identification |
| | `\Author{}` `\Reviewer{}` `\Approver{}` | title page, approval table |
| | `\ComponentName{}` `\IntegrityLevel{}` `\ProjectStart{}` `\ProjectEnd{}` `\Repository{}` | identification table |
| | `\Revision{version}{date}{author}{change}` | revision history row |
| introduction | `\Purpose{}` `\Scope{}` | text |
| | `\ProjectObjective{text}` | objectives list |
| | `\Deliverable{deliverable}{recipient}{milestone IDs}` | deliverables row |
| | `\Reference{key}{internal/external}{document}{version}` | row `[Rn]`; cite with `\DocRef{key}` |
| | `\Term{term}{definition}` | terms row |
| organization | `\Role[reports to]{ID}{name}{responsibility}` | roles row, box in the organisation chart, RACI column |
| | `\Member{name}{role IDs}{organisation / contact}` | team row, names in roles table and chart |
| | `\Stakeholder{stakeholder}{interest / interface}{contact role}` | stakeholders row |
| | `\Meeting{meeting}{cadence}{participant roles}{purpose / output}` | meetings row |
| | `\Communication{text}` | reporting and communication |
| lifecycle | `\ProcessReference{text}` | process reference |
| | `\Process{ID}{name}{yes/no/tailored}{rationale}` | tailoring row with its work products |
| | `\Milestone{ID}{date}{name}{work product IDs}` | milestones row, timeline |
| | `\Release{version}{date}{content}{milestone}` | releases row, timeline |
| workproducts | `\WorkProduct{ID}{name}{process IDs}{responsible role}{template / location}` | work product row, RACI row (R) |
| | `\Review{work product}{method}{reviewer roles}{approver role}` | reviews row, RACI (C, A) |
| | `\Informed{work product}{roles}` | RACI (I) |
| configuration | `\ConfigItem{item}{location}{controlled by}` | configuration items row |
| | `\BranchingModel{text}` `\ReleaseProcedure{text}` | text |
| | `\Baseline{ID}{when}{content}{label}` `\Naming{object}{rule}{example}` | rows |
| | `\Workflow{ID}{name}{states}{tool / where}` | workflow chain |
| quality | `\QAActivity{activity}{when}{roles}{evidence}` `\Metric{metric}{target}{measured by}` | rows |
| | `\Escalation{text}` | text |
| risks | `\Risk{ID}{risk}{probability}{impact}{mitigation}{owner role}` | register row, matrix cell (`low`/`medium`/`high`) |
| environment | `\Tool{name}{purpose}{version}{classification}` `\ToolQualification{text}` | tools row, text |
| development | `\Rule{area}{rule}{enforced by: tools}` | rules row (empty tools: review) |
| | `\CIStage{stage}{does / checks}{tools}{blocking yes/no}` | pipeline chain and row |
| | `\DoneCriterion{text}` | Definition of Done item |
| | `\begin{HowTo}{ID}{title}` … `\end{HowTo}` with `\Goal{}` `\Tools{tools}` `\Step{action}{command}` | how-to subsection, numbered steps |
| opl | `\OpenPointExport{date}{source}` | as-of date (overdue check) and source line |
| | `\OpenPoint[top 1–5]{ID}{topic}{open / in progress / closed}{responsible}{due or closed date}{comment}` | row in Top 5 (by rank) and in its status list |
| any | `\InputFigure[max width]{name}` `\InputCode[options]{file}` `\ManualDir` `FreeText` | as in `sw-unit-test-spec` |
| main file | `\LoadManual{manual}` | loads `manuals/<manual>/` (overridden by `\SpecManual`) |

Consistency checks, shown in red in the PDF:

- an undeclared role, process, milestone, work product or tool where one is referenced
- a role without a member; a work product whose responsible role has no member
- a member, meeting, work product or QA activity without a role; a review without reviewers
- an applied process (`yes`/`tailored`) without a work product
- a milestone or release date that is not YYYY-MM-DD
- a risk without mitigation or owner
- an open point with an unknown status, a top rank not 1–5, given twice or on a closed point, no responsible or due date (open, in progress), a date that is not YYYY-MM-DD, a due date before the as-of date (`\OpenPointExport`, else `\DocDate`)
- a tool without classification when the integrity level is an ASIL
- `\DocRef` to an unknown key, a missing figure or code file

LaTeX warnings: duplicate IDs (roles, processes, milestones, work products, risks, tools, open points), an unknown `[reports to]` role (drawn as a top role), an unknown process scope or risk level, an unknown reference type, a text command given twice.

## Customizing

**Own packages and macros** go to optional files, all read in the preamble; a missing one is skipped:

| File | Read | For |
|---|---|---|
| `packages.tex` (root) | by `swpm.cls`, before `underscore` | `\usepackage` for all manuals (TeX Live 2022; others into `sty/`) |
| `macros.tex` (root) | first when the manual is loaded | macros, colours, TikZ styles for all manuals |
| `manuals/<manual>/macros.tex` | next, before `metadata.tex` | the manual's macros; `\renewcommand` overrides a root one |

`\newcommand` stops on a name the template already uses. Example: `manuals/sample/macros.tex` (`\Repo`, used in `development.tex`). Manuals made with an older template get the new skeleton files with `scripts/new_manual.py --add-missing --all` (existing files are not changed).

In `sw_project_manual.tex` you can reorder or drop the chapter commands (`\SpecTitlePage`, `\SpecDocumentControl`, `\SpecContents`, `\SpecIntroduction`, `\SpecOrganization`, `\SpecLifecycle`, `\SpecWorkProducts`, `\SpecConfiguration`, `\SpecQuality`, `\SpecRisks`, `\SpecEnvironment`, `\SpecDevelopment`, `\SpecOpenPoints`), and add own sections. Class options go to `article`.

## Test

"Test" = it builds without errors or warnings: `latexmk -pdf sw_project_manual.tex` (the sample, also the committed preview) and `python3 scripts/build.py --strict --force sample empty`. A manual created by `scripts/new_manual.py` builds the same way. After changing `llm/`, `manuals/empty/` or `manuals/sample/`: `python3 scripts/continue_rules.py` (`--check` in CI). `manuals/sample/llm-context.md` is committed like the preview PDF: `python3 scripts/llm_context.py sample --check` must pass. In the sw-dev-pub checkout, `python3 ../spec-figures/scripts/vendor.py . --check` must pass too (specfig copies up to date).
