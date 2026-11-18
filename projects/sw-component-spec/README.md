# sw-component-spec

LaTeX template for a **Software Component Specification**: one document per software component, holding its requirements, its architecture (units, interfaces, dynamic behaviour, resources) and its verification (step-by-step integration of its units, component test cases). Covers the work products expected by Automotive SPICE 4.0 SWE.2 (software architectural design) and SWE.5 (software component verification and integration verification) and by ISO 26262-6 clauses 7 and 10. Test documentation follows ISO/IEC/IEEE 29119-3. The template addresses those clauses; it does not make a project compliant: content, reviews and evidence remain the project's job.

Spin-off of [`sw-unit-test-spec`](../sw-unit-test-spec/) one level up. It uses the same content model, tooling and rules: content as plain data commands in `components/<component>/*.tex`, all layout in `swcs.cls`, generated tables, diagrams and traceability, inconsistencies in red. Each unit of the component keeps its own unit test spec, which this document references.

**Owner:** swdevos · **Status:** new, builds clean (TeX Live 2026 and 2022) · **License:** MIT (repo root)

## Unit scope vs. component scope

| | Unit test spec (`sw-unit-test-spec`) | Component spec (this) |
|---|---|---|
| Object | one unit, smallest testable element | one component = several units (units only, no sub-components) |
| Requirements | stakeholder → internal | software requirements (allocated from the SRS) → component requirements (interfaces, timing, resources); allocation to units |
| Design | intended behaviour, internal architecture, algorithm | static architecture (units table + generated structure diagram), dynamic behaviour, error handling, resource budgets, configuration |
| Interfaces | functions of the unit, every dependency mocked | provided interfaces (realised by a unit) and required interfaces (provided by other components) |
| Test | white-box, statement/branch/MC/DC | integration steps, black-box at the boundary, function and call coverage (ISO 26262-6 Table 12), resource usage |
| Test doubles | all dependencies | only the required interfaces; all units are real |

## Files

```
sw_component_spec.tex     main file: chapter order, default component
swcs.cls                  the template: all formatting and input commands
latexmkrc                 latexmk settings: sty/ on TeX's search path, -c also removes the free-text helper files, llm-context.md after each build
sty/                      packages TeX Live does not have, found without install: tikz-uml.sty, specfig*.sty
sw_component_spec.pdf     the sample component, built: a preview of what the template produces
scripts/new_component.py  creates components/<component>/ from components/empty/
scripts/build.py          builds components into build/<component>.pdf
scripts/clean.py          removes build output (build/ and root LaTeX files) for a clean build
scripts/llm_prompt.py     builds a chat prompt so an LLM can help edit a component's file
scripts/llm_context.py    writes components/<component>/llm-context.md: whole component + guides as one chat context (run after every build)
llm/                      the guides it uses: general rules + one per content file
scripts/continue_rules.py generates .continue/rules/ from llm/ (Continue chat in VS Code)
.continue/rules/          generated: the guides as Continue rules, one per content file
README-scripts.md         short usage of the scripts, incl. LLM chat help
figures/  data/  code/    shared by all components (a component's own file of the same name wins)
components/
  empty/                  skeleton for new components: commented command templates, no content
  sample/                 worked example (component heater_ctrl with the units setpoint_ctrl, temp_filter, heat_pi)
  <component>/            one folder per component:
    metadata.tex …        content files (table below)
    figures/ data/ code/  the component's own figures, data and source files
```

| Content file (in `components/<component>/`) | What |
|---|---|
| `metadata.tex` | document data, component identification, revision history |
| `introduction.tex` | scope, references, use cases, terms |
| `requirements.tex` | software and component requirements (functional / non-functional), rationale for untested ones |
| `component.tex` | functional description, units and allocation, provided/required interfaces, use relations, callers, resources, configuration |
| `design.tex` | free-text sections *Static Architecture*, *Dynamic Behavior*, *Error Handling* |
| `approach.tex` | verification methods, integration strategy and steps, derivation, coverage targets, entry/exit, pass/fail |
| `environment.tex` | tools and versions, tool qualification |
| `testcases.tex` | the test cases |
| `results.tex` | execution results, achieved coverage, deviations (optional) |

## Build

Same requirements as `sw-unit-test-spec`: a TeX distribution with `latexmk` and `tcolorbox`, `xltabular`, `enumitem`, `fancyhdr`, `lastpage`, `underscore`, `microtype`, `fancyvrb`, `tikz` (pgf), `adjustbox`; Python 3.6+ (standard library only). Run everything from the template's root folder.

```sh
python3 scripts/new_component.py brake_mon     # new component: copies components/empty/
python3 scripts/build.py brake_mon             # -> build/brake_mon.pdf
python3 scripts/build.py --all                 # every component except components/empty
latexmk -pdf sw_component_spec.tex             # the default component (\LoadComponent{sample}) -> sw_component_spec.pdf
```

`\SpecComponent` selects the component at build time (`-usepretex='\def\SpecComponent{brake_mon}'`, one job name per component, as `build.py` does). Options, live preview and plain `pdflatex` work as in `sw-unit-test-spec` (README there, *Build*). `sw_component_spec.pdf` is committed as a preview of the sample; rebuild it whenever the template or the sample changes.

## Using it for a project

Exactly as `sw-unit-test-spec` (README there, *Using it for a project*), with `components/` for `units/`, `new_component.py` for `new_unit.py`, `\LoadComponent` for `\LoadUnit` and tags `<component>-v<version>`. In short: a private copy of the template with all components on `main`, project defaults in `components/empty/`, template updates merged one way from upstream, each component's spec baselined by its own tag. Keep it outside the code repository and reference the code baseline (`\ComponentBaseline`).

Component specs and unit test specs may live in the same project repository as two template copies, or in two repositories. Either way, link a component's units to their unit test specs with `\Reference` + `\Unit{…}{…}{\DocRef{key}}`.

## Writing content: the rules

The same as in `sw-unit-test-spec`. Replace the text inside `{…}`. Underscores need no escaping. Escape only `\%` `\&` `\#` `\$` `\{ \}`. Anything left out shows as a grey `⟨placeholder⟩` or `none`. Values for your own text: `\TheComponent`, `\TheBaseline`, `\TheIntegrityLevel`. Cite a reference with `\DocRef{key}`.

## Document structure

| Chapter | Content from |
|---|---|
| Title page, Document Control | `metadata.tex` |
| 1 Introduction: Purpose, Scope, Stakeholders and Use Cases, References, Terms | `introduction.tex` |
| 2 Requirements: 2.1 Software (Functional, Non-Functional), 2.2 Component (Functional, Non-Functional) | `requirements.tex` |
| 3 Component Description: Identification, Functional Description, Context, **Static Architecture** (units table, structure diagram), Interfaces (Provided, Required), **Dynamic Behavior**, **Error Handling**, Resource Budgets, Configuration Parameters | `metadata.tex`, `component.tex`, `design.tex` |
| 4 Test Approach: Verification Methods, **Integration Strategy** (steps), Derivation, Coverage, Entry/Exit, Pass/Fail | `approach.tex` |
| 5 Test Environment: harness diagram, tools, Test Doubles | `environment.tex`, `component.tex` |
| 6 Test Cases | `testcases.tex` |
| 7 Traceability: requirements → test cases, uncovered requirements, integration steps → test cases | generated |
| 8 Test Results Summary | `results.tex` |

### Units, interfaces and integration

```latex
\Unit{setpoint_ctrl}{Range check, ramp limitation and storage of the setpoint}{\DocRef{suts-spc}}
\Allocate{setpoint_ctrl}{SWR-0110, SWR-0120, SWR-0130}
\ProvidedInterface[setpoint_ctrl]{SetpointCtrl_Set(sp)}{uint8, [0, 100]}{Sets a new setpoint}
\RequiredInterface[NvM]{NvM_ReadBlock()}{Reads the stored setpoint}{Stub}{Returns a configurable value}
\Uses{heat_pi}{setpoint_ctrl}{SetpointCtrl_GetEffective()}     % unit -> unit
\Uses{setpoint_ctrl}{NvM}{NvM_ReadBlock(), NvM_WriteBlock()}   % unit -> other component

\IntegrationStep{IS-1}{temp_filter, heat_pi}{Control path}           % approach.tex
\IntegrationStep{IS-2}{temp_filter, heat_pi, setpoint_ctrl}{Complete component}
\begin{TestCase}{TC-HC-001}{...} \Verifies{SWR-0100} \Integration{IS-1} ... \end{TestCase}
```

An integration step lists all units integrated so far. Each test case names its step with `\Integration{ID}`.

## Diagrams

Generated with TikZ from the data you already enter. Each diagram only appears when its data exists.

| Diagram | Where | Built from |
|---|---|---|
| **Use cases** | 1.x *Stakeholders and Use Cases* | `\UseCase{use case}{actor, actor}` in `introduction.tex` |
| **Context**: users → `«component»` → providing components | 3.x *Context* | `\Caller` + `\RequiredInterface[component]` |
| **Internal structure**: units inside the component boundary; provided interfaces enter from the left, unit → unit uses on lanes, uses of other components fan out to their boxes on the right | 3.x *Static Architecture* | `\Unit`, `\ProvidedInterface[unit]`, `\Uses` |
| **Test harness**: test driver → `«CUT»` (all units real) → test doubles of the required interfaces | top of 5 *Test Environment* | `\ProvidedInterface` + `\RequiredInterface` |

Units appear in the order of their `\Unit` lines, and the boxes of other components in the order of the mean position of their users. Sequence diagrams and other figures go into a `FreeText` or design block (see `figures/main_cycle.tex` of the sample). `sty/tikz-uml.sty` is shipped as in `sw-unit-test-spec`. Likewise `sty/specfig*.sty` (spec-figures, optional): `\usepackage{specfig}` after `\documentclass{swcs}`, figures as `figures/<type>_<name>.tex` with `\InputFigure`, refreshed with spec-figures' `scripts/vendor.py`.

## Free text, figures, code and data

As in `sw-unit-test-spec` (README there, *Free text* and *Figures, code and data*), with `\ComponentDir` for `\UnitDir`. A block is printed at the end of its file's chapter (`component.tex` and `design.tex`: end of chapter 3), in `testcases.tex` exactly where it stands. The design blocks are `StaticArchitecture`, `DynamicBehavior` and `ErrorHandling`.

## Command reference

The text commands `\Purpose`, `\Scope`, `\UseCaseNote`, `\FunctionalDescription`, `\IntegrationStrategy`, `\PassFailCriteria`, `\ToolQualification` and `\ResultsNote` also work as environments with any LaTeX inside (`\end{...}` on its own line). Given twice, the last one is used (warning).

| File | Command | Produces |
|---|---|---|
| metadata | `\DocID{}` `\DocVersion{}` `\DocStatus{}` `\DocDate{}` `\DocTitle{}` `\ProjectName{}` `\Company{}` | title page, header/footer |
| | `\Author{}` `\Reviewer{}` `\Approver{}` | title page, approval table |
| | `\ComponentName{}` `\ComponentBaseline{}` `\IntegrityLevel{}` `\SourceFiles{}` `\Language{}` `\ArchitectureReference{}` | title page, identification table |
| | `\Revision{version}{date}{author}{change}` | revision history row |
| introduction | `\Purpose{}` `\Scope{}` | text |
| | `\Reference{key}{internal/external}{document}{version}` | row `[Rn]`; cite with `\DocRef{key}` |
| | `\Term{term}{definition}` | terms table row |
| | `\UseCase{use case}{actor, actor}` `\UseCaseNote{text}` | use case diagram |
| requirements | `\SoftwareRequirement{ID}{kind}{text}{source}` | row in 2.1.x; traceability row |
| | `\ComponentRequirement{ID}{kind}{text}{derived from IDs}` | row in 2.2.x; traceability row |
| | `\NotComponentTested{ID}{rationale / verified instead by}` | uncovered-requirements row |
| component | `\FunctionalDescription{text}` | functional description |
| | `\Unit{unit}{responsibility}{unit verification}` | units table row, box in structure and harness diagrams |
| | `\Allocate{unit}{REQ, REQ}` | *Allocated* column of the units table |
| | `\ProvidedInterface[unit]{name}{type / range / timing}{description}` | provided interfaces row; arrow into the unit; test driver label |
| | `\RequiredInterface[component]{name}{description}{replaced by}{behaviour in test}` | required interfaces row, test doubles row, boxes in context and harness diagrams |
| | `\Uses{unit}{unit or component}{interfaces}` | arrow in the structure diagram |
| | `\Caller{component}{interfaces it calls}` | caller box in the context diagram |
| | `\Resource{resource}{budget}{verified by}` | resource budgets row |
| | `\ConfigParameter{name}{values / default}{description}` | configuration row |
| design | `StaticArchitecture` `DynamicBehavior` `ErrorHandling` environments | the three design subsections of chapter 3 |
| approach | `\VerificationMethod{method}{yes/no}{remark}` | methods table row |
| | `\IntegrationStrategy{text}` | integration strategy text |
| | `\IntegrationStep{ID}{units so far}{description}` | integration steps row; traceability |
| | `\DerivationTechnique{text}` `\EntryCriterion{text}` `\ExitCriterion{text}` | list items |
| | `\Coverage{metric}{target}{justification if not met}` | coverage targets row |
| | `\PassFailCriteria{text}` | pass/fail criteria |
| environment | `\Tool{item}{description}{version}` `\ToolQualification{text}` | environment table |
| testcases | `\TestGroup{title}` | sub-heading |
| | `\begin{TestCase}{ID}{title}` … `\end{TestCase}` | test case box, list of test cases |
| | inside: `\Objective{}` `\Verifies{REQ, REQ}` `\Integration{step}` `\Method{}` `\Priority{}` `\Preconditions{}` `\InputData{}` `\Postconditions{}` `\Implementation{}` | fields, all optional, printed in a fixed order |
| | inside: `\InputValue{name}{value}{class}` `\Step{action}{expected result}` | input value row, numbered test step |
| results | `\Executed{n}` `\Passed{n}` `\Failed{n}` `\ResultsNote{text}` `\CoverageResult{metric}{achieved}` `\Deviation{ID}{test case}{description}{status}` | results summary, deviations |
| any | `\InputFigure[max width]{name}` `\InputCode[options]{file}` `\ComponentDir` `FreeText` | as in `sw-unit-test-spec` |
| main file | `\LoadComponent{component}` | loads `components/<component>/` (overridden by `\SpecComponent`) |

Consistency checks, shown in red in the PDF:

- a `\Verifies` requirement that is not declared
- a declared requirement with no test case and no `\NotComponentTested` rationale (a software requirement defers to its derived component requirements)
- an unknown *derived from* ID or allocated requirement ID
- an `\Allocate` for a unit that is not declared with `\Unit`
- a `\ProvidedInterface[unit]` or integration step naming an unknown unit
- a declared unit that is in no integration step
- an integration step without a test case
- an `\Integration` step that is not declared
- `\DocRef` to an unknown key
- a missing figure or code file

LaTeX warnings: duplicate test case, requirement, unit or step IDs; `\Uses` from an undeclared unit (arrow not drawn); an unknown requirement kind or reference type.

## Customizing

In `sw_component_spec.tex` you can reorder or drop the chapter commands (`\SpecTitlePage`, `\SpecDocumentControl`, `\SpecContents`, `\SpecIntroduction`, `\SpecRequirements`, `\SpecDescription`, `\SpecTestApproach`, `\SpecTestEnvironment`, `\SpecTestCases`, `\SpecTraceability`, `\SpecResults`), load your own packages and add own sections. For a pure architecture document, drop the test chapters. Class options go to `article`.

## Test

"Test" = it builds without errors or warnings: `latexmk -pdf sw_component_spec.tex` (the sample, also the committed preview) and `python3 scripts/build.py --strict --force sample empty`. A component created by `scripts/new_component.py` builds the same way. After changing `llm/`, `components/empty/` or `components/sample/`: `python3 scripts/continue_rules.py` (`--check` in CI). `components/sample/llm-context.md` is committed like the preview PDF: `python3 scripts/llm_context.py sample --check` must pass.
