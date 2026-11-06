# Task: requirements (`requirements.tex`)

This file declares the requirements the unit tests refer to. The template prints them in four tables (stakeholder / internal × functional / non-functional), adds "verified by" from the test cases and generates the traceability. Missing links show in red in the PDF.

- **Stakeholder requirement:** what a user or another stakeholder needs, in their words. `{source}` names the stakeholder or document, e.g. `Vehicle occupant, \DocRef{srs}`.
- **Internal requirement:** derived from stakeholder requirements or from the design, precise enough to test. `{derived from}` lists stakeholder IDs (comma-separated) or stays empty if it comes from the design.
- **kind:** exactly `functional` or `non-functional`.
- **`\NotUnitTested{ID}{rationale}`:** for an internal requirement that no unit test verifies. Say where it is verified instead, e.g. "Timing behaviour, verified in integration test ITS-SPC-007".

## Add or improve a requirement

1. **ID.** Continue the existing scheme (e.g. SWR-0150 after SWR-0140). Never reuse an ID. Ask if no scheme exists yet.
2. **Text.** One requirement per command, one "shall"-free statement in present tense ("Setpoints outside 0..100 are rejected with E_NOT_OK; the previous setpoint is kept."). It must be testable: give values, ranges, states, tolerances, time limits. Split compound requirements.
3. **Derived from.** Every internal requirement should trace to a stakeholder requirement, unless it is purely design-driven. Then say so in the open points.
4. **Test or not.** Say whether a unit test can verify it. If not, propose a `\NotUnitTested` line.

## Other things you can do

- **Review** the requirements for ambiguity, missing values, compound statements and duplicates.
- **Turn** a pasted SRS excerpt into commands. Keep the original IDs if it has them.
- **Find** stakeholder requirements without any internal requirement derived from them.

## Example

```latex
\StakeholderRequirement{STK-010}{functional}
  {The occupant can select a heating setpoint between 0 and 100.}
  {Vehicle occupant, \DocRef{srs}}

\InternalRequirement{SWR-0110}{functional}
  {Setpoints outside 0..100 are rejected with E_NOT_OK; the previous setpoint is kept.}
  {STK-010}

\NotUnitTested{SWR-0140}{Target timing measurement, see timing analysis report TAR-SPC-001}
```
