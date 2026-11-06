# sw-unit-test-spec

LaTeX template for a **Software Unit Test Specification**. Structure follows ISO/IEC/IEEE 29119-3 (test design / test case specification) and covers the work products expected by Automotive SPICE SWE.4 (software unit verification) and ISO 26262-6 clause 9 (software unit verification). Drop the safety-specific parts if they don't apply. The template addresses those clauses; it does not make a project compliant — content, reviews and evidence remain the project's job.

**Content is separated from the template:** you write only data and plain text into the unit's `units/<unit>/*.tex` — no tables, no `&`/`\\`, no environments except `TestCase` — plus optional `FreeText` blocks for anything else (see *Free text*). All layout lives in `suts.cls`. Traceability tables, the uncovered-requirements list, test case count, reference numbers, the list of test cases and three UML diagrams (see *Diagrams*) are generated.

**Owner:** swdevos · **Status:** stable, builds clean (TeX Live 2026) · **License:** MIT (repo root)

## Files

```
sw_unit_test_spec.tex     main file: chapter order, default unit
suts.cls                  the template: all formatting and input commands
latexmkrc                 lets latexmk -c also remove the free-text helper files
sw_unit_test_spec.pdf     the sample unit, built: a preview of what the template produces
scripts/new_unit.py       creates units/<unit>/ from units/empty/
scripts/build.py          builds units into build/<unit>.pdf (build/ is gitignored)
README-scripts.md         short usage of the two scripts
figures/  data/  code/    shared by all units (a unit's own file of the same name wins)
units/
  empty/                  skeleton for new units: commented command templates, no content
  sample/                 worked example (unit setpoint_ctrl)
  <unit>/                 one folder per unit:
    metadata.tex …        content files (table below)
    figures/ data/ code/  the unit's own figures, data and source files
```

| Content file (in `units/<unit>/`) | What |
|---|---|
| `metadata.tex` | document data, unit identification, revision history |
| `introduction.tex` | scope, references, terms |
| `requirements.tex` | stakeholder and internal requirements (functional / non-functional), rationale for untested ones |
| `unit.tex` | functional description, interfaces, dependencies/mocks, callers |
| `design.tex` | free-text sections *Intended Behavior*, *Internal Architecture*, *Algorithm Description* |
| `approach.tex` | verification methods, derivation, coverage targets, entry/exit, pass/fail |
| `environment.tex` | tools and versions, tool qualification |
| `testcases.tex` | the test cases |
| `results.tex` | execution results, achieved coverage, deviations (optional) |

You edit only `units/<unit>/` and the shared `figures/`, `data/`, `code/`. `suts.cls`, `latexmkrc` and `scripts/` are not edited in a project; `sw_unit_test_spec.tex` rarely (see *Customizing*).

## Build

Needs a TeX distribution with `latexmk` and the packages `tcolorbox`, `xltabular`, `enumitem`, `fancyhdr`, `lastpage`, `underscore`, `microtype`, `fancyvrb`, `tikz` (pgf), `adjustbox` (TeX Live: `texlive-latexextra` or equivalent), and Python 3.6+ for `scripts/` (standard library only). Run everything from the template's root folder.

```sh
python3 scripts/new_unit.py nvm_mgr          # new unit: copies units/empty/ to units/nvm_mgr/
python3 scripts/build.py nvm_mgr             # -> build/nvm_mgr.pdf
python3 scripts/build.py nvm_mgr sample      # several units -> build/nvm_mgr.pdf, build/sample.pdf
python3 scripts/build.py --all               # every unit except units/empty
```

`build.py` creates `build/` if needed; PDFs go to `build/<unit>.pdf`, intermediates to `build/.aux/<unit>/`, the root stays clean. `build/` is gitignored, so delete it at any time. Each unit is built with its own job name, so an unchanged unit is skipped (`--force` rebuilds). The summary lists the LaTeX warnings of each unit, and the errors of a failed one, whose PDF is removed so that no stale PDF is left behind. The script continues with the remaining units and exits non-zero if one failed. Options: `--strict` (warnings count as failure, e.g. in CI), `--force`, `-v` (latexmk output).

Behind it is one latexmk call per unit, which you can also run directly, e.g. for a live preview:

```sh
latexmk -pdf -pvc -jobname=nvm_mgr -outdir=build -auxdir=build/.aux/nvm_mgr \
        -usepretex='\def\SpecUnit{nvm_mgr}' sw_unit_test_spec.tex
latexmk -pdf sw_unit_test_spec.tex           # the default unit (\LoadUnit{sample}) -> sw_unit_test_spec.pdf in the root
```

- **`\SpecUnit` selects the unit** (its folder name under `units/`). Without it, the unit named in `\LoadUnit{…}` in `sw_unit_test_spec.tex` is built.
- **One job name per unit** (`-jobname=<unit>`, as `build.py` does). latexmk does not count `-usepretex` code as input. Under a shared job name, a build of another unit finds the previous PDF up to date and does nothing (force it with `-g`).
- A unit folder without `metadata.tex` gives the warning `Unit folder … has no metadata.tex` (typo guard). The log names the folder used: `suts: content folder …`.
- Plain `pdflatex` without latexmk: `pdflatex -jobname=nvm_mgr '\def\SpecUnit{nvm_mgr}\input{sw_unit_test_spec}'` (three runs).
- `new_unit.py <unit> --from <other>` copies another unit instead of the skeleton, e.g. for a similar unit. Unit names: letters, digits, `_`, `-`, `.`.

`sw_unit_test_spec.pdf` is committed as a preview of the sample unit; rebuild it whenever the template or the sample changes.

## Using it for a project

The template is used as its own repository (the *upstream*). A project gets **one copy of it, with all units on `main`**, each in its own `units/<unit>/` folder:

```
upstream (this template)  ──merge──▶  main of <project>-unit-test-specs
  template + units/empty + units/sample        template + units/empty (with project defaults)
                                               + units/<unit>/ per unit (PDFs built, not committed)
                                               + shared figures/ data/ code/
```

- **`units/empty/`** holds what is the same for all units of the project: `\Company`, `\ProjectName`, approver, common references and terms, test approach, test environment. `new_unit.py` copies it, so every new unit starts with these defaults.
- **Shared files** — figures, data and source files used by several units — go to the root `figures/`, `data/`, `code/`. A change there reaches every unit with its next build.
- **`units/<unit>/`** holds one unit's content and its own figures, data and code. PDFs are build output (`build/`, gitignored): built by `scripts/build.py` from any commit, the released ones filed from the baseline tag (step 5).
- Changes flow one way only: **upstream → `main`**. Template fixes go to upstream (not edited in the copy).

**Outside the code repository.** Keep the spec repository separate from the unit's source code, not as a folder or submodule in it. The spec is a work product with its own versions, tags and releases (`\DocVersion`, `<unit>-v<version>`, review and approval). Its life cycle differs from the code's: a spec is often baselined before the code exists, and a code release does not imply a new spec version. To link the two, reference the code baseline under test in the spec (`\UnitBaseline`, `\SourceFiles`, a `\Reference` to the code repository and tag), never the other way round. Copies of source files for listings (`code/`) are excerpts for reading, not the code under test.

**A private copy, not a GitHub fork.** A fork of a public repository is public. For project work, create an empty **private** repository (e.g. `<project>-unit-test-specs`) and push the template into it, keeping upstream as a second remote.

### 1. Set up the project repository (once)

```sh
git clone <template-url> <project>-unit-test-specs && cd <project>-unit-test-specs
git remote rename origin upstream
git remote add origin <url of the new private repo>
git rm -r -q units/sample sw_unit_test_spec.pdf figures/test_process.tex   # the worked example
```

In `sw_unit_test_spec.tex`, change `\LoadUnit{sample}` to `\LoadUnit{empty}`. Put the project-wide defaults into `units/empty/*.tex` (uncomment the lines and fill them in) and shared files into `figures/`, `data/`, `code/`. Then check and push:

```sh
python3 scripts/build.py --strict empty            # check: units/empty builds, 0 warnings
git add -A && git commit -m "Project setup: project-wide defaults"
git push -u origin main
```

### 2. Start a unit

```sh
git pull
python3 scripts/new_unit.py setpoint_ctrl        # units/setpoint_ctrl/, \UnitName set
# fill units/setpoint_ctrl/*.tex in this order:
#   metadata (baseline, …) → requirements → unit → design
#   → approach/environment (unit specifics) → testcases → results (after execution)
python3 scripts/build.py setpoint_ctrl          # -> build/setpoint_ctrl.pdf
git add units/setpoint_ctrl && git commit -m "setpoint_ctrl: initial spec"
git push
```

Prefix commit messages with the unit name. Reviewers build the PDF themselves (`scripts/build.py <unit>`) or get it from CI (`scripts/build.py --all --strict`, `build/*.pdf` as artifacts). For a review, compare against the last baseline: `git diff setpoint_ctrl-v1.0 -- units/setpoint_ctrl/` (see step 5).

### 3. Project-wide change (e.g. a new tool version)

- Shared files in `figures/`, `data/`, `code/`: change them once; every unit that uses them picks it up with its next build (`scripts/build.py --all`).
- Text that every unit carries (e.g. `\Tool` lines in `environment.tex`): change it in `units/empty/` for future units, and in each existing unit that should take it over. Each unit is a separate document with its own version — changing it means a new revision of that unit's spec.

### 4. Take over template updates from upstream

```sh
git fetch upstream && git merge upstream/main
```

Expect these conflicts, resolved the same way every time:

| Conflict | Why | Resolve |
|---|---|---|
| `units/sample/*`, `figures/test_process.tex`, `sw_unit_test_spec.pdf` (modify/delete) | upstream changed its worked example; the project removed it | `git rm` them |
| `units/empty/*.tex` | upstream changed the skeleton; the project filled in its defaults | keep ours and take over new commented commands by hand |
| `sw_unit_test_spec.tex` (`\LoadUnit`) | only if upstream changed the same line | keep `\LoadUnit{empty}` |

```sh
git rm -r -q --ignore-unmatch units/sample figures/test_process.tex sw_unit_test_spec.pdf
git checkout --ours -- units/empty/ && git add units/empty/
git commit -m "Merge template update from upstream" && git push
```

`suts.cls`, `latexmkrc`, `scripts/` and `.gitignore` merge cleanly, because they are not edited in the copy. Check the upstream changes to `units/empty/` (a new content file or command is shown there) and to `sw_unit_test_spec.tex`. Then rebuild every unit: `scripts/build.py --all --strict`.

### 5. Baseline a unit's spec

Set `\DocVersion` and `\DocStatus` in the unit's `metadata.tex` and add a `\Revision` row. Build it (`scripts/build.py --strict setpoint_ctrl`), commit, then tag:

```sh
git tag -a setpoint_ctrl-v1.0 -m "setpoint_ctrl unit test spec v1.0"   # tag version = \DocVersion
git push origin setpoint_ctrl-v1.0
```

The tagged commit's `units/setpoint_ctrl/` is the released document's source; the other units in that commit are not part of it. File `build/setpoint_ctrl.pdf`, built from the tagged commit, in the project's document management, as the released PDF is not in git. Never move a tag; fix forward with a new version.

**Template from sw-dev-pub.** Until the template has its own repository, `git subtree split --prefix=projects/sw-unit-test-spec -b sw-unit-test-spec` in a sw-dev-pub clone produces a branch with the template's history, ready to push as upstream. The split is deterministic, so later splits continue the same history and step 4 keeps working.

## Writing content — the rules

- Replace the text inside `{…}`. Empty lines inside an argument start a new paragraph.
- Underscores need no escaping: `SetpointCtrl_Init()`, `unit_name`.
- Escape only these: `\%` `\&` `\#` `\$` `\{ \}` (a bare `%` starts a comment). Plain numbers given as coverage values get the `%` added for you.
- Anything left out shows up as a grey `⟨placeholder⟩` or `none` — the document always builds. Missing content files in a unit folder are skipped.
- Formatting is optional and up to you: `\textbf{…}`, `\emph{…}`, `\code{…}` (typewriter, for identifiers and command lines), lists etc. work in the text arguments.
- Values for use in your own text: `\TheUnit`, `\TheBaseline`, `\TheIntegrityLevel`; cite a reference with `\DocRef{key}` → `[R2]`.

## Document structure

| Chapter | Content from |
|---|---|
| Title page, Document Control | `metadata.tex` |
| 1 Introduction — Purpose, Scope, Stakeholders and Use Cases, References, Terms | `introduction.tex` |
| 2 Requirements — 2.1 Stakeholder (Functional, Non-Functional), 2.2 Internal (Functional, Non-Functional) | `requirements.tex` |
| 3 Unit Under Test — Identification, Functional Description, **Intended Behavior**, Context, Interfaces, Dependencies, **Internal Architecture**, **Algorithm Description** | `metadata.tex`, `unit.tex`, `design.tex` |
| 4 Test Approach, 5 Test Environment | `approach.tex`, `environment.tex` |
| 6 Test Cases | `testcases.tex` |
| 7 Traceability — requirements → test cases, uncovered requirements | generated |
| 8 Test Results Summary | `results.tex` |

### Requirements

```latex
\StakeholderRequirement{STK-011}{functional}{The selected setpoint is kept across ignition cycles.}{Vehicle occupant}
\InternalRequirement{SWR-0120}{functional}{If NvM cannot be read, the unit enters DEGRADED ...}{STK-011, STK-021}
\InternalRequirement{SWR-0130}{non-functional}{The effective setpoint changes by at most 2 K/s.}{STK-020}
\NotUnitTested{SWR-0130}{Timing behaviour, verified in integration test ITS-SPC-007}
```

Kind is `functional` or `non-functional` (also `f` / `nf`). Stakeholder requirements carry their **source**, internal ones the stakeholder requirements they are **derived from** (may be empty). *Verified by* is generated: an internal requirement's test cases (from `\Verifies`), and for a stakeholder requirement its own test cases plus *via* the verified internal requirements derived from it. Unknown parent IDs are shown in red.

### Design sections (free text)

*Intended Behavior*, *Internal Architecture* and *Algorithm Description* are always present in chapter 3 and filled from `design.tex` — free-text blocks like `FreeText` (any LaTeX: subsubsections, formulas, TikZ, tables, verbatim), each placed in its own subsection:

```latex
\begin{IntendedBehavior}
The unit has two operating states ... \begin{tikzpicture} ... \end{tikzpicture}
\end{IntendedBehavior}

\begin{InternalArchitecture} ... \end{InternalArchitecture}   % \end{...} on its own line
\begin{AlgorithmDescription} ... \end{AlgorithmDescription}
```

A missing block shows a placeholder. They work in any content file except `testcases.tex` (warning, block ignored).

## Diagrams

Generated with TikZ from the data you already enter — nothing to draw. Each diagram (and its subsection) only appears when its data exists.

| Diagram | Where | Built from |
|---|---|---|
| **Use cases** — actors (stick figures), use cases inside the `«system»` boundary (= `\ProjectName`) | 1.x *Stakeholders and Use Cases*, after Scope | `\UseCase{use case}{actor, actor}` (+ optional `\UseCaseNote{text}`) in `introduction.tex`. System-level context, usually taken over from the SRS — leave it out if not wanted. |
| **Context** — the unit's neighbours: callers → `«unit»` → used components, arrows labelled with the interfaces used | 3.x *Context*, after Intended Behavior | `\Caller{component}{interfaces it calls}` + `\Dependency[component]{…}` in `unit.tex` |
| **Test harness** — test driver → `«UUT»` → test doubles (`«mock»`, `«stub»`, … from *replaced by*) | top of 5 *Test Environment* | `\Interface` names + `\Dependency` entries — no extra input |

`\Dependency[NvM]{NvM_ReadBlock()}…` and `\Dependency[NvM]{NvM_WriteBlock()}…` share one `NvM` box; without `[component]` each function gets its own box. For any other diagram (sequence, state machine, own TikZ or an included image) use a `FreeText` block.

## Free text

Every content file may contain any number of free-text blocks with **any LaTeX** — own (sub)subsections, formulas (`amsmath` is loaded: `equation`, `align`, `cases`, `\eqref`), tables, figures, `verbatim`, listings; normal LaTeX rules apply inside (`%` is a comment, `\&` etc.):

```latex
\begin{FreeText}
\subsection{Public API (excerpt)}
\begin{verbatim}
Std_ReturnType SetpointCtrl_Set(uint8 sp);   /* 0..100 */
\end{verbatim}
\end{FreeText}
```

Write `\end{FreeText}` on its own line. Where a block appears:

| Block in | Printed at the end of |
|---|---|
| `metadata.tex` | Document Control |
| `introduction.tex` | 1 Introduction |
| `requirements.tex` | 2 Requirements |
| `unit.tex`, `design.tex` | 3 Unit Under Test |
| `approach.tex` | 4 Test Approach |
| `environment.tex` | 5 Test Environment |
| `testcases.tex` | — exactly where it stands (between test cases / groups) |
| `results.tex` | 8 Test Results Summary |
| `sw_unit_test_spec.tex` (document body) | — exactly where it stands |

Start the block with `\subsection{…}` if it should get its own heading. The example content has blocks in `design.tex` (state diagram + table; architecture diagram + list; *Algorithm Description* with subsubsections, `cases`, `align`, `\eqref` and a PDF figure; *Internal Architecture* also a TikZ figure), `unit.tex` (API excerpt from `code/` with `\InputCode`), `approach.tex` (shared TikZ figure, own table, displayed formula) and `testcases.tex` (paragraph with formulas between the test groups). Not allowed inside a `TestCase` (use the text fields there). Each block is copied to a helper file `<jobname>.free-*.tex` during the build (gitignored, removed by `latexmk -c`).

### Figures, code and data

Each unit has its own `figures/`, `data/` and `code/`; the folders of the same name at root level hold files shared by all units. A file is found by name alone, **unit folder first, then the shared folder** — so a unit can override a shared figure by a file of the same name.

| Kind | File | Include with | Typical source |
|---|---|---|---|
| Image file | `figures/<name>.pdf` (also `.png`, `.jpg`) | `\includegraphics[width=…]{<name>}` | exported plot (MATLAB, Python), modelling tool export, screenshot |
| Figure code | `figures/<name>.tex` — a bare `tikzpicture`, no preamble or `\begin{document}` | `\InputFigure[max width]{<name>}` | hand-written TikZ: sequence and state diagrams, block diagrams |
| Source file | `code/<file>` (any extension) | `\InputCode[fancyvrb options]{<file>}` | header or source excerpt, configuration, test code |
| Data file | `data/<file>` | by name with `\input{…}` and any package that uses LaTeX's file search, or as `\UnitDir/data/<file>` | CSV tables, measurement data, generated test vectors |

```latex
\begin{figure}[htbp]
  \centering
  \includegraphics[width=0.75\linewidth]{ramp_response}   % units/sample/figures/ramp_response.pdf
  \caption{Ramp limitation: step request from 20 to 100.}
  \label{fig:ramp}
\end{figure}

\begin{figure}[htbp]
  \centering
  \InputFigure{init_sequence}                             % units/sample/figures/init_sequence.tex
  \caption{Start-up sequence of \texttt{SetpointCtrl\_Init()}.}
  \label{fig:init-seq}
\end{figure}

\InputCode{setpoint_ctrl.h}                               % units/sample/code/setpoint_ctrl.h
\InputFigure{test_process}                                % shared: figures/test_process.tex
```

Reference figures with `Figure~\ref{fig:ramp}`. Subfolders work with a relative name (`{nvm/sequence}` → `figures/nvm/sequence.pdf`). A file found in neither folder gives a warning and a red *missing* box in the PDF. latexmk only watches files that were read: after **adding** a unit file that overrides a shared one, rebuild once with `-g`.

- **Image file:** prefer vector PDF over PNG/JPG and keep files small (they are committed with the spec). Older pdfTeX (TeX Live 2022) warns for PDF versions above 1.5. Export as PDF 1.5 if your tool allows.
- **Figure code** is typeset as part of the document: the template's colours (`accent`, `sutsunit`, `sutsdouble`, …), TikZ libraries (`arrows.meta`, `positioning`, `fit`, `calc`, `shapes.geometric`) and fonts apply, and the text stays searchable. A figure wider than the text is shrunk to `\linewidth`, or to the optional `[max width]`, but never enlarged. Prefix own TikZ style names (`tp proc/.style`): short names such as `step` or `out` are TikZ keys already. Short TikZ can also stay inline in the `FreeText` block, as the state diagram in *Intended Behavior* does.
- **Source file:** listed verbatim in a small typewriter font; options go to fancyvrb's `\VerbatimInput`, e.g. `\InputCode[firstline=5, lastline=12, numbers=left]{setpoint_ctrl.h}`.
- **Data file:** `data/` and `code/` (unit, then shared) are added to LaTeX's input path, so `\input{nvm_table}` finds `data/nvm_table.tex`. Packages that need a path get it from `\UnitDir` (expands to `units/<unit>`), e.g. `\UnitDir/data/vectors.csv`, or use `data/vectors.csv` for a shared file.

## Command reference

| File | Command | Produces |
|---|---|---|
| metadata | `\DocID{}` `\DocVersion{}` `\DocStatus{}` `\DocDate{}` `\DocTitle{}` `\ProjectName{}` `\Company{}` | title page, header/footer (`\DocStatus` default Draft, `\DocDate` default today) |
| | `\Author{}` `\Reviewer{}` `\Approver{}` | title page, approval table |
| | `\UnitName{}` `\UnitBaseline{}` `\IntegrityLevel{}` `\SourceFiles{}` `\Language{}` `\DesignReference{}` | title page, identification table |
| | `\Revision{version}{date}{author}{change}` | one row of the revision history |
| introduction | `\Purpose{text}` | overrides the default purpose paragraph |
| | `\Scope{text}` | scope |
| | `\Reference{key}{internal/external}{document}{version}` | row `[Rn]` with type column, numbered in order; cite with `\DocRef{key}` (type also `int`/`ext`, `i`/`e`) |
| | `\Term{term}{definition}` | terms table row |
| | `\UseCase{use case}{actor, actor}` `\UseCaseNote{text}` | use case diagram (actors collected automatically) |
| unit | `\FunctionalDescription{text}` | functional description |
| | `\Interface{name}{direction}{type / range}{description}` | interfaces table row |
| | `\Dependency[component]{name}{replaced by}{behaviour in test}` | stubs/mocks table row; `[component]` (optional) groups functions in the diagrams |
| | `\Caller{component}{interfaces it calls}` | caller box in the context diagram |
| approach | `\VerificationMethod{method}{yes/no}{remark}` | methods table row with ☒ / ☐ |
| | `\DerivationTechnique{text}` | list item |
| | `\Coverage{metric}{target}{justification if not met}` | coverage targets row (`100` → `100 %`) |
| | `\EntryCriterion{text}` `\ExitCriterion{text}` | list items |
| | `\PassFailCriteria{text}` | pass/fail criteria |
| environment | `\Tool{item}{description}{version}` | environment table row |
| | `\ToolQualification{text}` | paragraph below the table |
| requirements | `\StakeholderRequirement{ID}{kind}{text}{source}` | row in 2.1.x; traceability row |
| | `\InternalRequirement{ID}{kind}{text}{derived from IDs}` | row in 2.2.x; traceability row; test cases filled in automatically |
| | `\NotUnitTested{ID}{rationale / verified instead by}` | uncovered-requirements row |
| design | `IntendedBehavior` `InternalArchitecture` `AlgorithmDescription` environments | the three design subsections of chapter 3 |
| any (free text) | `\InputFigure[max width]{name}` | figure code `figures/name.tex`, unit first, then shared |
| | `\InputCode[options]{file}` | verbatim listing of `code/file`, unit first, then shared |
| | `\UnitDir` | expands to the unit folder, `units/<unit>` |
| main file | `\LoadUnit{unit}` | loads `units/<unit>/` (overridden by `\SpecUnit` at build time); `\LoadContent{folder}` loads any folder |
| testcases | `\TestGroup{title}` | sub-heading |
| | `\begin{TestCase}{ID}{title}` … `\end{TestCase}` | one test case box, entry in *List of Test Cases*, link target |
| | inside: `\Objective{}` `\Verifies{REQ, REQ}` `\Method{}` `\Priority{}` `\Preconditions{}` `\InputData{}` `\Postconditions{}` `\Implementation{}` | fields — all optional, any order, printed in a fixed order |
| | inside: `\InputValue{name}{value}{class}` | one input value row |
| | inside: `\Step{action}{expected result}` | one numbered test step |
| results | `\Executed{n}` `\Passed{n}` `\Failed{n}` `\ResultsNote{text}` | results summary (test case and deviation counts are automatic) |
| | `\CoverageResult{metric}{achieved}` | achieved coverage row |
| | `\Deviation{ID}{test case}{description}{status}` | deviations table row |

Consistency checks, shown in red in the PDF: a requirement in `\Verifies` that is not declared in `requirements.tex`; a declared requirement with no test case and no `\NotUnitTested` rationale (a stakeholder requirement defers to its derived requirements); an unknown *derived from* ID; `\DocRef` to an unknown key (also a LaTeX warning); a reference type other than internal/external (also a warning). Duplicate test case or requirement IDs and an unknown requirement kind give a LaTeX warning.

## Customizing

In `sw_unit_test_spec.tex` you can reorder or drop the chapter commands (`\SpecTitlePage`, `\SpecDocumentControl`, `\SpecContents`, `\SpecIntroduction`, `\SpecRequirements`, `\SpecUnitUnderTest`, `\SpecTestApproach`, `\SpecTestEnvironment`, `\SpecTestCases`, `\SpecTraceability`, `\SpecResults`), load your own packages, and add own sections (`\section{…}` + `\input{\UnitDir/my_extra}`). One spec per unit: one folder per unit under `units/` (see *Using it for a project*). Class options go to `article` (`\documentclass[10pt]{suts}`).

## Test

"Test" = it builds without errors or warnings: `latexmk -pdf sw_unit_test_spec.tex` (the sample unit, also the committed preview) and `python3 scripts/build.py --strict --force sample empty` (`units/empty`: everything as placeholders); a unit created by `scripts/new_unit.py` builds the same way.
