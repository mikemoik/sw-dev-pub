# sw-unit-test-spec

LaTeX template for a **Software Unit Test Specification**. Structure follows ISO/IEC/IEEE 29119-3 (test design / test case specification) and covers the work products expected by Automotive SPICE SWE.4 (software unit verification) and ISO 26262-6 clause 9 (software unit verification). Drop the safety-specific parts if they don't apply. The template addresses those clauses; it does not make a project compliant — content, reviews and evidence remain the project's job.

**Content is separated from the template:** you write only data and plain text into `content/*.tex` — no tables, no `&`/`\\`, no environments except `TestCase`. All layout lives in `suts.cls`. Traceability tables, the uncovered-requirements list, test case count, reference numbers and the list of test cases are generated.

**Owner:** swdevos · **Status:** stable, builds clean (TeX Live 2026) · **License:** MIT (repo root)

## Files

| File | What | You edit it? |
|---|---|---|
| `content/metadata.tex` | document data, unit identification, revision history | yes |
| `content/introduction.tex` | scope, references, terms | yes |
| `content/unit.tex` | functional description, interfaces, dependencies/mocks | yes |
| `content/approach.tex` | verification methods, derivation, coverage targets, entry/exit, pass/fail | yes |
| `content/environment.tex` | tools and versions, tool qualification | yes |
| `content/requirements.tex` | requirements allocated to the unit, rationale for untested ones | yes |
| `content/testcases.tex` | the test cases | yes |
| `content/results.tex` | execution results, achieved coverage, deviations (optional) | yes |
| `sw_unit_test_spec.tex` | main file: chapter order | rarely |
| `suts.cls` | the template: all formatting and input commands | no |

The `content/` files ship with a small worked example (unit `setpoint_ctrl`) — replace the text inside the braces.

## Build

Needs a TeX distribution with `latexmk` and the packages `tcolorbox`, `xltabular`, `enumitem`, `fancyhdr`, `lastpage`, `underscore`, `microtype` (TeX Live: `texlive-latexextra` or equivalent).

```sh
latexmk -pdf sw_unit_test_spec.tex        # -> sw_unit_test_spec.pdf
latexmk -pdf -pvc sw_unit_test_spec.tex   # live rebuild while editing
latexmk -c                                # remove intermediates
```

The PDF is not committed (build output); build it from the sources.

## Writing content — the rules

- Replace the text inside `{…}`. Empty lines inside an argument start a new paragraph.
- Underscores need no escaping: `SetpointCtrl_Init()`, `unit_name`.
- Escape only these: `\%` `\&` `\#` `\$` `\{ \}` (a bare `%` starts a comment). Plain numbers given as coverage values get the `%` added for you.
- Anything left out shows up as a grey `⟨placeholder⟩` or `none` — the document always builds. Missing files in `content/` are skipped.
- Formatting is optional and up to you: `\textbf{…}`, `\emph{…}`, `\code{…}` (typewriter, for identifiers and command lines), lists etc. work in the text arguments.
- Values for use in your own text: `\TheUnit`, `\TheBaseline`, `\TheIntegrityLevel`; cite a reference with `\DocRef{key}` → `[R2]`.

## Command reference

| File | Command | Produces |
|---|---|---|
| metadata | `\DocID{}` `\DocVersion{}` `\DocStatus{}` `\DocDate{}` `\DocTitle{}` `\ProjectName{}` `\Company{}` | title page, header/footer (`\DocStatus` default Draft, `\DocDate` default today) |
| | `\Author{}` `\Reviewer{}` `\Approver{}` | title page, approval table |
| | `\UnitName{}` `\UnitBaseline{}` `\IntegrityLevel{}` `\SourceFiles{}` `\Language{}` `\DesignReference{}` | title page, identification table |
| | `\Revision{version}{date}{author}{change}` | one row of the revision history |
| introduction | `\Purpose{text}` | overrides the default purpose paragraph |
| | `\Scope{text}` | scope |
| | `\Reference{key}{document}{version}` | row `[Rn]`, numbered in order; cite with `\DocRef{key}` |
| | `\Term{term}{definition}` | terms table row |
| unit | `\FunctionalDescription{text}` | functional description |
| | `\Interface{name}{direction}{type / range}{description}` | interfaces table row |
| | `\Dependency{name}{replaced by}{behaviour in test}` | stubs/mocks table row |
| approach | `\VerificationMethod{method}{yes/no}{remark}` | methods table row with ☒ / ☐ |
| | `\DerivationTechnique{text}` | list item |
| | `\Coverage{metric}{target}{justification if not met}` | coverage targets row (`100` → `100 %`) |
| | `\EntryCriterion{text}` `\ExitCriterion{text}` | list items |
| | `\PassFailCriteria{text}` | pass/fail criteria |
| environment | `\Tool{item}{description}{version}` | environment table row |
| | `\ToolQualification{text}` | paragraph below the table |
| requirements | `\Requirement{ID}{short description}` | traceability row; test cases filled in automatically |
| | `\NotUnitTested{ID}{rationale / verified instead by}` | uncovered-requirements row |
| testcases | `\TestGroup{title}` | sub-heading |
| | `\begin{TestCase}{ID}{title}` … `\end{TestCase}` | one test case box, entry in *List of Test Cases*, link target |
| | inside: `\Objective{}` `\Verifies{REQ, REQ}` `\Method{}` `\Priority{}` `\Preconditions{}` `\InputData{}` `\Postconditions{}` `\Implementation{}` | fields — all optional, any order, printed in a fixed order |
| | inside: `\InputValue{name}{value}{class}` | one input value row |
| | inside: `\Step{action}{expected result}` | one numbered test step |
| results | `\Executed{n}` `\Passed{n}` `\Failed{n}` `\ResultsNote{text}` | results summary (test case and deviation counts are automatic) |
| | `\CoverageResult{metric}{achieved}` | achieved coverage row |
| | `\Deviation{ID}{test case}{description}{status}` | deviations table row |

Consistency checks, shown in red in the PDF: a requirement in `\Verifies` that is not declared in `requirements.tex`; a declared requirement with no test case and no `\NotUnitTested` rationale; `\DocRef` to an unknown key (also a LaTeX warning). Duplicate test case IDs give a LaTeX warning.

## Customizing

In `sw_unit_test_spec.tex` you can reorder or drop the chapter commands (`\SpecTitlePage`, `\SpecDocumentControl`, `\SpecContents`, `\SpecIntroduction`, `\SpecUnitUnderTest`, `\SpecTestApproach`, `\SpecTestEnvironment`, `\SpecTestCases`, `\SpecTraceability`, `\SpecResults`), load your own packages, and add own sections (`\section{…}` + `\input{content/my_extra}`). One spec per unit: copy the project folder, or keep several content folders and point `\LoadContent{…}` at one. Class options go to `article` (`\documentclass[10pt]{suts}`).

## Test

"Test" = it builds without errors or warnings: `latexmk -pdf sw_unit_test_spec.tex`; also with an empty `content/` folder (everything as placeholders).
