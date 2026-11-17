# Task: test approach (`approach.tex`)

This file says how the component is integrated and verified (ISO 26262-6 Table 10 methods, Table 11 derivation, Table 12 structural coverage at architectural level; ASPICE SWE.5 verification and integration strategy). The required rigour depends on `\IntegrityLevel` in `metadata.tex`.

- **`\VerificationMethod{method}{yes|no}{remark}`:** one per method. Typical: requirements-based test, interface test, fault injection test, resource usage evaluation, back-to-back test (model vs.\ code), verification of control flow and data flow, static analysis.
- **`\IntegrationStrategy{text}`:** how the units are put together (bottom-up, top-down, all at once) and why; what replaces a unit not yet integrated.
- **`\IntegrationStep{ID}{units}{description}`:** one per step, in order. `{units}` lists all units integrated so far (cumulative), with names exactly as in `\Unit`. The last step contains all units. Test cases name their step with `\Integration{ID}`.
- **`\DerivationTechnique{text}`:** analysis of requirements and architecture, equivalence classes, analysis of interfaces between units, error guessing.
- **`\Coverage{metric}{target}{justification if not met}`:** Function and Call coverage. A plain number gets a % sign.
- **`\EntryCriterion{text}`, `\ExitCriterion{text}`:** e.g. units passed their unit verification; resource budgets met.
- **`\PassFailCriteria{text}`:** when a test case passes.

## Things you can do

- **Draft the approach** for the integrity level. Rough guide from ISO 26262-6 (`++` highly recommended, `+` recommended): requirements-based and interface test for all levels; fault injection and resource usage `+` from ASIL A, `++` at higher levels; function and call coverage `+` for ASIL A/B, `++` for C/D. Present this as a proposal to confirm against the standard and the verification plan.
- **Propose integration steps** from the `\Uses` relations in `component.tex`: start with units that use no other unit, add their users step by step.
- **Check consistency:** every unit is in a step; every step has a test case; every method set to `yes` is used by a test case.

## Example

```latex
\IntegrationStrategy{Bottom-up; units come from their unit verification.}
\IntegrationStep{IS-1}{temp_filter, heat_pi}{Control path; setpoint_ctrl replaced by a stub}
\IntegrationStep{IS-2}{temp_filter, heat_pi, setpoint_ctrl}{Complete component}
\Coverage{Call}{100}{review of unexecuted calls}
```
