# Task: results (`results.tex`)

This file records the results after the tests were run. The number of test cases is counted automatically.

- **`\ResultsNote{text}`:** when and where the tests ran (date, CI run, baseline).
- **`\Executed{n}`, `\Passed{n}`, `\Failed{n}`:** numbers of test cases.
- **`\CoverageResult{metric}{achieved}`:** one per metric of `\Coverage` in `approach.tex`. A plain number gets a % sign.
- **`\Deviation{ID}{test case}{description / justification}{status}`:** one per failed test case or missed coverage target. Status is `open` or `closed`.

## Things you can do

- **Fill in from a test report** (e.g. pasted GoogleTest, JUnit XML or lcov summary): count executed, passed and failed. Map failed tests to test case IDs using `\Implementation` in `testcases.tex`.
- **Check consistency:**
  - Passed + Failed = Executed.
  - Executed ≤ the number of test cases.
  - Every failed test case and every coverage result below its target in `approach.tex` has a `\Deviation`.
  - Every metric with a target has a result.

## Example

```latex
\ResultsNote{Executed on 2026-11-03 in CI pipeline run 1234.}
\Executed{3}
\Passed{3}
\Failed{0}
\CoverageResult{Branch}{95.5}
\Deviation{DEV-01}{TC-SPC-002}{Branch for sp > 255 unreachable (uint8); accepted by review.}{closed}
```
