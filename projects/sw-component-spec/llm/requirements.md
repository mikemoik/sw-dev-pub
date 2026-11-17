# Task: requirements (`requirements.tex`)

This file declares the requirements the component is specified and tested against. The template prints them in four tables (software / component × functional / non-functional), adds "verified by" from the test cases and generates the traceability. Missing links show in red in the PDF.

- **Software requirement:** allocated to this component from the software requirements specification (SWE.1). Keep the SRS wording and ID. `{source}` names the document, e.g. `\DocRef{srs}`.
- **Component requirement:** derived at component level from software requirements or from the architecture: interface behaviour between units, timing, resources. `{derived from}` lists software requirement IDs (comma-separated) or stays empty if it comes from the architecture.
- **kind:** exactly `functional` or `non-functional`.
- **`\NotComponentTested{ID}{rationale}`:** for a requirement that no component test case verifies. Say where it is verified instead, e.g. "Target timing measurement, see timing analysis report TAR-HC-001", or "unit test of setpoint_ctrl".

Requirements that only concern one unit's inside belong to that unit's spec, not here. Allocation to units is done in `component.tex` (`\Allocate`).

## Add or improve a requirement

1. **ID.** Continue the existing scheme. Never reuse an ID. Ask if no scheme exists yet.
2. **Text.** One requirement per command, one "shall"-free statement in present tense. It must be testable at the component boundary: give values, ranges, modes, tolerances, time limits.
3. **Derived from.** Every component requirement should trace to a software requirement, unless it is purely architecture-driven. Then say so in the open points.
4. **Test or not.** Say whether a component test can verify it. If not, propose a `\NotComponentTested` line.

## Other things you can do

- **Review** the requirements for ambiguity, missing values, compound statements and duplicates.
- **Turn** a pasted SRS excerpt into commands. Keep the original IDs.
- **Find** software requirements without allocation in `component.tex`.

## Example

```latex
\SoftwareRequirement{SWR-0200}{functional}
  {On an implausible cabin temperature the heater duty is set to 0 within 100 ms.}
  {\DocRef{srs}}
\ComponentRequirement{CR-011}{functional}
  {The heater duty is written exactly once per HeaterCtrl_MainFunction() call.}
  {SWR-0200}
\NotComponentTested{CR-020}{Target timing measurement, see timing analysis report TAR-HC-001}
```
