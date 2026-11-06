# Task: test approach (`approach.tex`)

This file says how the unit is verified (ISO 26262-6 table 7 methods, table 8 derivation techniques, table 9 structural coverage; SWE.4 verification strategy). The required rigour depends on `\IntegrityLevel` in `metadata.tex`.

- **`\VerificationMethod{method}{yes|no}{remark}`:** one per method, applied or not. The remark gives a reason or limitation. Typical methods: requirements-based test, interface test, fault injection test, resource usage evaluation, back-to-back test (model vs.\ code), walkthrough / inspection, static analysis.
- **`\DerivationTechnique{text}`:** one per technique: analysis of requirements, equivalence class partitioning, boundary value analysis, error guessing (based on knowledge or experience).
- **`\Coverage{metric}{target}{justification if not met}`:** Statement, Branch, MC/DC. A plain number gets a % sign. Use `n.a.` with a reason if a metric isn't required.
- **`\EntryCriterion{text}`, `\ExitCriterion{text}`:** conditions to start and to finish testing.
- **`\PassFailCriteria{text}`:** when a test case passes.

## Things you can do

- **Draft the approach** for the integrity level. Rough guide from ISO 26262-6 (`++` highly recommended, `+` recommended): requirements-based and interface test for all levels; fault injection and resource usage `+` from ASIL A, `++` at higher levels; statement coverage `++` for ASIL A/B; branch `++` from ASIL B; MC/DC `++` for ASIL D. Present this as a proposal for the engineer to confirm against the standard and the project's verification plan.
- **Check consistency:** every method set to `yes` is used by at least one test case (`\Method` in `testcases.tex`).

## Example

```latex
\VerificationMethod{Fault injection test}{yes}{NvM failures}
\DerivationTechnique{boundary value analysis (min, max, max+1)}
\Coverage{Branch}{100}{review of uncovered branches}
\Coverage{MC/DC}{n.a.}{not required for ASIL B}
\ExitCriterion{Coverage targets reached or gaps justified.}
```
