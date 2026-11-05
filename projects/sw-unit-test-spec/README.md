# sw-unit-test-spec

LaTeX template for a **Software Unit Test Specification**. Structure follows ISO/IEC/IEEE 29119-3 (test design / test case specification) and covers the work products expected by Automotive SPICE SWE.4 (software unit verification) and ISO 26262-6 clause 9 (software unit verification). Drop the safety-specific parts if they don't apply. The template addresses those clauses; it does not make a project compliant — content, reviews and evidence remain the project's job.

**Content is separated from the template:** you write only data and plain text into `content/*.tex` — no tables, no `&`/`\\`, no environments except `TestCase` — plus optional `FreeText` blocks for anything else (see *Free text*). All layout lives in `suts.cls`. Traceability tables, the uncovered-requirements list, test case count, reference numbers, the list of test cases and three UML diagrams (see *Diagrams*) are generated.

**Owner:** swdevos · **Status:** stable, builds clean (TeX Live 2026) · **License:** MIT (repo root)

## Files

| File | What | You edit it? |
|---|---|---|
| `content/metadata.tex` | document data, unit identification, revision history | yes |
| `content/introduction.tex` | scope, references, terms | yes |
| `content/unit.tex` | functional description, interfaces, dependencies/mocks, callers | yes |
| `content/design.tex` | free-text sections *Intended Behavior*, *Internal Architecture*, *Algorithm Description* | yes |
| `content/approach.tex` | verification methods, derivation, coverage targets, entry/exit, pass/fail | yes |
| `content/environment.tex` | tools and versions, tool qualification | yes |
| `content/requirements.tex` | stakeholder and internal requirements (functional / non-functional), rationale for untested ones | yes |
| `content/testcases.tex` | the test cases | yes |
| `content/results.tex` | execution results, achieved coverage, deviations (optional) | yes |
| `figures/` | figures: image files (`\includegraphics`) and figure code (`\InputFigure`); examples `ramp_response.pdf`, `init_sequence.tex` | yes |
| `sw_unit_test_spec.tex` | main file: chapter order | rarely |
| `suts.cls` | the template: all formatting and input commands | no |
| `sw_unit_test_spec.pdf` | the example, built — a preview of what the template produces | (rebuilt) |
| `latexmkrc` | lets `latexmk -c` also remove the free-text helper files | no |

The `content/` files ship with a small worked example (unit `setpoint_ctrl`) — replace the text inside the braces.

## Build

Needs a TeX distribution with `latexmk` and the packages `tcolorbox`, `xltabular`, `enumitem`, `fancyhdr`, `lastpage`, `underscore`, `microtype`, `fancyvrb`, `tikz` (pgf), `adjustbox` (TeX Live: `texlive-latexextra` or equivalent).

```sh
latexmk -pdf sw_unit_test_spec.tex        # -> sw_unit_test_spec.pdf
latexmk -pdf -pvc sw_unit_test_spec.tex   # live rebuild while editing
latexmk -c                                # remove intermediates
```

`sw_unit_test_spec.pdf` is committed as a preview of the example; rebuild it whenever the template or example content changes.

### Choosing the content folder at build time

`\LoadContent{content}` in `sw_unit_test_spec.tex` sets the default folder. To build another folder without editing the file, define `\ContentDir` on the command line:

```sh
latexmk -pdf -jobname=demo -usepretex='\def\ContentDir{units/demo}' sw_unit_test_spec.tex   # -> demo.pdf
latexmk -c -jobname=demo sw_unit_test_spec.tex                                              # its intermediates
```

- **Always add `-jobname=<name>` (one name per folder).** latexmk does not count `-usepretex` code as input. Without its own job name, a build of another folder finds the previous PDF up to date and does nothing; force it with `-g` in that case. With its own job name, each folder gets its own PDF, intermediates and change tracking: editing `units/demo/*.tex` rebuilds `demo.pdf` and leaves the others alone.
- The path is relative to the main file. Without `\ContentDir` the argument of `\LoadContent` applies, as before.
- A folder without `metadata.tex` gives the warning `Content folder … has no metadata.tex` (typo guard). The log always names the folder used: `suts: content folder …`.
- Figures stay in the shared `figures/` folder.
- Plain `pdflatex` without latexmk: `pdflatex -jobname=demo '\def\ContentDir{units/demo}\input{sw_unit_test_spec}'`.

## Using it for a project

The template is used as its own repository (the *upstream*). A project gets **one copy of it, with one branch per unit**:

```
upstream (this template)  ──merge──▶  main  ──merge──▶  unit/<unit-name>   (one branch per unit)
  template + worked example            template +         template + project-wide
                                       project-wide       + unit content + its PDF
                                       content, no PDF
```

- **`main`** — the template plus everything that is the same for all units of the project: `\Company`, `\ProjectName`, approver, common references and terms, test approach, test environment. It never holds a unit's content.
- **`unit/<unit-name>`** — one long-lived branch per unit, created from `main`. `<unit-name>` is the unit's `\UnitName` (e.g. `unit/setpoint_ctrl`). Holds the unit's content and its built `sw_unit_test_spec.pdf`. Unit branches are never merged back into `main` or into each other.
- Changes flow one way only: **upstream → `main` → `unit/*`**. Template fixes go to upstream (not edited in the copy), project-wide edits go to `main`, unit edits go to the unit branch.

**Outside the code repository.** Keep the spec repository separate from the unit's source code, not as a folder or submodule in it. The spec is a work product with its own versions, tags and releases (`\DocVersion`, `<unit>-v<version>`, review and approval). Its life cycle differs from the code's: a spec is often baselined before the code exists, and a code release does not imply a new spec version. To link the two, reference the code baseline under test in the spec (`\UnitBaseline`, `\SourceFiles`, a `\Reference` to the code repository and tag), never the other way round.

**A private copy, not a GitHub fork.** A fork of a public repository is public. For project work, create an empty **private** repository (e.g. `<project>-unit-test-specs`) and push the template into it, keeping upstream as a second remote.

### 1. Set up the project repository (once)

```sh
git clone <template-url> <project>-unit-test-specs && cd <project>-unit-test-specs
git remote rename origin upstream
git remote add origin <url of the new private repo>
```

On `main`, replace the worked example in **every** `content/*.tex` with the project-wide content and empty or placeholder content for the unit-specific files. The document still builds, with placeholders. Then remove the example PDF and push:

```sh
git rm sw_unit_test_spec.pdf          # the example's preview; unit branches carry their own PDF
git rm figures/ramp_response.pdf figures/init_sequence.tex   # the example's figures
latexmk -pdf sw_unit_test_spec.tex    # check: builds, 0 warnings (PDF stays untracked on main)
git commit -am "Project setup: project-wide content"
git push -u origin main
```

Touch every content file here. A content file left unchanged would silently take later changes to the upstream example.

### 2. Start a unit

```sh
git switch main && git pull
git switch -c unit/setpoint_ctrl
# fill content/*.tex for the unit, in this order:
#   metadata (UnitName, baseline, …) → requirements → unit → design
#   → approach/environment (unit specifics) → testcases → results (after execution)
latexmk -pdf sw_unit_test_spec.tex
git add content/ figures/ sw_unit_test_spec.pdf && git commit -m "setpoint_ctrl: initial spec"
git push -u origin unit/setpoint_ctrl
```

Commit the rebuilt PDF with every content change on the unit branch, so reviewers can read the branch without building it. For a review, compare the content against the last baseline: `git diff setpoint_ctrl-v1.0 -- content/ figures/` (see step 5).

### 3. Project-wide change (e.g. a new tool version)

Edit on `main`, commit, then bring it into each unit branch:

```sh
git switch unit/setpoint_ctrl && git merge main
latexmk -pdf sw_unit_test_spec.tex && git commit -am "setpoint_ctrl: rebuild after merge of main"
```

A conflict only occurs when the unit branch changed the same lines. Resolve it as usual.

### 4. Take over template updates from upstream

```sh
git switch main && git fetch upstream && git merge upstream/main
```

Expect two kinds of conflicts, both resolved the same way every time:

| Conflict | Why | Resolve |
|---|---|---|
| `content/*.tex` | upstream changed its worked example; the project has its own content | keep ours: `git checkout --ours -- content/` |
| `sw_unit_test_spec.pdf` (modify/delete) | upstream rebuilt its example PDF; `main` has none | `git rm sw_unit_test_spec.pdf` |
| `figures/*` (modify/delete) | upstream changed an example figure; `main` has none | `git rm` it |

```sh
git checkout --ours -- content/ && git rm -q --ignore-unmatch sw_unit_test_spec.pdf figures/ramp_response.pdf figures/init_sequence.tex
git add content/ && git commit -m "Merge template update from upstream"
git push
```

`suts.cls`, `latexmkrc` and `.gitignore` merge cleanly, because they are not edited in the copy. Check the upstream changes to `sw_unit_test_spec.tex` and to *new* files in `content/` and `figures/`: a new content file arrives with example text, a new example figure is not needed. Replace that text and `git rm` the figure on `main`. Then merge `main` into every unit branch as in step 3, and rebuild and commit each unit's PDF.

### 5. Baseline a unit's spec

Set `\DocVersion` and `\DocStatus` in `metadata.tex` and add a `\Revision` row. Rebuild and commit, then tag on the unit branch:

```sh
git tag -a setpoint_ctrl-v1.0 -m "setpoint_ctrl unit test spec v1.0"   # tag version = \DocVersion
git push origin setpoint_ctrl-v1.0
```

The tagged commit, with its PDF, is the released document. File the PDF in the project's document management if required. Never move a tag; fix forward with a new version.

**Template from sw-dev-pub.** Until the template has its own repository, `git subtree split --prefix=projects/sw-unit-test-spec -b sw-unit-test-spec` in a sw-dev-pub clone produces a branch with the template's history, ready to push as upstream. The split is deterministic, so later splits continue the same history and step 4 keeps working.

## Writing content — the rules

- Replace the text inside `{…}`. Empty lines inside an argument start a new paragraph.
- Underscores need no escaping: `SetpointCtrl_Init()`, `unit_name`.
- Escape only these: `\%` `\&` `\#` `\$` `\{ \}` (a bare `%` starts a comment). Plain numbers given as coverage values get the `%` added for you.
- Anything left out shows up as a grey `⟨placeholder⟩` or `none` — the document always builds. Missing files in `content/` are skipped.
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

Start the block with `\subsection{…}` if it should get its own heading. The example content has blocks in `design.tex` (state diagram + table; architecture diagram + list; *Algorithm Description* with subsubsections, `cases`, `align`, `\eqref` and a PDF figure from `figures/`; *Internal Architecture* also a TikZ figure from `figures/`), `unit.tex` (API excerpt in `verbatim`), `approach.tex` (own table, displayed formula) and `testcases.tex` (paragraph with formulas between the test groups). Not allowed inside a `TestCase` (use the text fields there). Each block is copied to a helper file `<jobname>.free-*.tex` during the build (gitignored, removed by `latexmk -c`).

### Figures

Figures live in `figures/`, in one of two forms. Both go inside a `FreeText` block (usually in a `figure` float with caption and label) and are found by name alone, without path or extension:

| Form | File | Include with | Typical source |
|---|---|---|---|
| Image file | `figures/<name>.pdf` (also `.png`, `.jpg`) | `\includegraphics[width=…]{<name>}` | exported plot (MATLAB, Python), modelling tool export, screenshot |
| Figure code | `figures/<name>.tex` — a bare `tikzpicture`, no preamble or `\begin{document}` | `\InputFigure[max width]{<name>}` | hand-written TikZ: sequence and state diagrams, block diagrams |

```latex
\begin{figure}[htbp]
  \centering
  \includegraphics[width=0.75\linewidth]{ramp_response}   % figures/ramp_response.pdf
  \caption{Ramp limitation: step request from 20 to 100.}
  \label{fig:ramp}
\end{figure}

\begin{figure}[htbp]
  \centering
  \InputFigure{init_sequence}                             % figures/init_sequence.tex
  \caption{Start-up sequence of \texttt{SetpointCtrl\_Init()}.}
  \label{fig:init-seq}
\end{figure}
```

Reference them with `Figure~\ref{fig:ramp}`. Subfolders work with a relative name (`{nvm/sequence}` → `figures/nvm/sequence.pdf`).

- **Image file:** prefer vector PDF over PNG/JPG and keep files small (they are committed with the spec). Older pdfTeX (TeX Live 2022) warns for PDF versions above 1.5. Export as PDF 1.5 if your tool allows.
- **Figure code** is typeset as part of the document: the template's colours (`accent`, `sutsunit`, `sutsdouble`, …), TikZ libraries (`arrows.meta`, `positioning`, `fit`, `calc`, `shapes.geometric`) and fonts apply, and the text stays searchable. A figure wider than the text is shrunk to `\linewidth`, or to the optional `[max width]`, but never enlarged. Short TikZ can also stay inline in the `FreeText` block, as the state diagram in *Intended Behavior* does. Move it into `figures/` once it gets long or is reused.

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

In `sw_unit_test_spec.tex` you can reorder or drop the chapter commands (`\SpecTitlePage`, `\SpecDocumentControl`, `\SpecContents`, `\SpecIntroduction`, `\SpecRequirements`, `\SpecUnitUnderTest`, `\SpecTestApproach`, `\SpecTestEnvironment`, `\SpecTestCases`, `\SpecTraceability`, `\SpecResults`), load your own packages, and add own sections (`\section{…}` + `\input{content/my_extra}`). One spec per unit: one branch per unit in a project copy (see *Using it for a project*). For a quick local use without git, keep several content folders and pick one at build time (see *Choosing the content folder at build time*). Class options go to `article` (`\documentclass[10pt]{suts}`).

## Test

"Test" = it builds without errors or warnings: `latexmk -pdf sw_unit_test_spec.tex`; also with an empty `content/` folder (everything as placeholders).
