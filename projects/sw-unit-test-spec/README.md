# sw-unit-test-spec

LaTeX template for a **Software Unit Test Specification**. Structure follows ISO/IEC/IEEE 29119-3 (test design / test case specification) and covers the work products expected by Automotive SPICE SWE.4 (software unit verification) and ISO 26262-6 clause 9 (software unit verification). Drop the safety-specific parts if they don't apply. The template addresses those clauses; it does not make a project compliant — content, reviews and evidence remain the project's job.

**Owner:** swdevos · **Status:** stable, builds clean (TeX Live 2026) · **License:** MIT (repo root)

## Files

| File | What |
|---|---|
| `sw_unit_test_spec.tex` | The template: metadata block, document control, UUT, test approach, environment, test cases, traceability, results summary — with three example test cases. |

## Build

Needs a TeX distribution with `latexmk` and the packages `tcolorbox`, `xltabular`, `enumitem`, `fancyhdr`, `lastpage` (TeX Live: `texlive-latexextra` or equivalent).

```sh
latexmk -pdf sw_unit_test_spec.tex        # -> sw_unit_test_spec.pdf
latexmk -pdf -pvc sw_unit_test_spec.tex   # live rebuild while editing
latexmk -c                                # remove intermediates
```

The PDF is not committed (build output); build it from the `.tex`.

## Use

1. Copy `sw_unit_test_spec.tex` into your project and rename it per unit.
2. Fill in the metadata block at the top (`\DocID`, `\UnitName`, `\UnitVersion`, `\SafetyLevel`, `\Author`, …).
3. Replace every grey italic placeholder produced by `\ph{…}`.
4. One `testcase` environment per test case — it is listed automatically in the *List of Test Cases* and gets the label `tc:<ID>` for `\hyperref`:

```latex
\begin{testcase}{TC-UNIT-004}{Short title}
  \tcfield{Objective}{What is verified.}
  \tcfield{Requirements}{SWR-0130}
  \tcfield{Method}{Boundary value analysis}
  \tcfield{Preconditions}{…}
  \tcfield{Test steps}{%
    \begin{tcsteps}
      \tcstep{Action / stimulus}{Expected result}
    \end{tcsteps}}
  \tcfield{Postconditions}{…}
\end{testcase}
```

5. Keep the traceability table (requirements → test cases) in sync with the test cases.

## Test

"Test" = it builds without errors: `latexmk -pdf sw_unit_test_spec.tex`.
