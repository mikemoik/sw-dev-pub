# Task: introduction (`introduction.tex`)

This file holds the scope, the referenced documents, the use cases and the terms.

- **`\Purpose{text}`:** optional. Only replaces the default purpose paragraph if the engineer wants other wording.
- **`\Scope{text}`:** two paragraphs, "In scope: ..." (the component, its units, interfaces and configuration) and "Out of scope: ..." (the units' insides, verified by their unit test specs; neighbouring components; system integration).
- **`\DocumentReference{key}{attribute = value, ...}`:** one per document. `key` is a short lowercase name, cited anywhere as `\DocRef{key}`; every listed document must be cited somewhere. Put the requirements and architecture documents first, then the unit test specifications of the units. Attributes, any order:
  - `title` (always), `number` (document number, e.g. `SRS-SPC-001`) and `issue` (version or edition) — both required for internal documents, `date` (YYYY-MM-DD).
  - `scope = internal` (default: the organisation's own documents) or `scope = external` (standards, guidelines, supplier documents).
  - `classification`: `public`, `internal`, `confidential` or `strictly confidential` (unless the project set other values).
  - `url`: only if the engineer gives one; always in braces, `%` written as `\%`: `url = {https://…}`.
  - `id`: a short label printed instead of [R1], [R2], ... (e.g. `id = SVP`); leave it out unless asked.
  - A value containing `,` or `=` goes in braces: `title = {ISO 26262-6 -- Clauses 7, 10}`.
  - The older `\Reference{key}{internal|external}{document}{version}` still works; write new ones as `\DocumentReference`. Never invent document numbers, issues or URLs: ask for them.
- **`\UseCase{use case}{actor, actor}`:** system use cases the component contributes to, usually taken from the SRS. `\UseCaseNote{text}` adds a sentence above the diagram.
- **`\Term{term}{definition}`:** abbreviations and project terms used in the document.

## Other things you can do

- **Scope:** draft it from `component.tex` and the engineer's notes.
- **Terms:** list abbreviations used in the files but not yet defined as `\Term`.
- **References:** suggest the usual standards as external references, e.g. ISO/IEC/IEEE 29119-3, Automotive SPICE SWE.2/SWE.5, ISO 26262-6 clauses 7 and 10, MISRA C:2012. Only add the ones that apply to the project; ask about versions.

## Example

```latex
\Scope{
  In scope: the component \TheComponent\ with its three units in the series
  configuration: its provided interfaces, the interaction of its units, its
  error handling and its resource budgets.

  Out of scope: the internals of each unit (verified by their unit test
  specifications), the basic software, the heater power stage (system test).
}
\DocumentReference{arch}{
  title = Software Architecture Description,
  number = SAD-HC-002, issue = 2.0, date = 2026-10-20,
  classification = confidential,
  url = {https://plm.example.com/docs/SAD-HC-002},
}
\DocumentReference{suts-spc}{
  title = Software Unit Test Specification setpoint_ctrl,
  number = SUTS-SPC-001, issue = 0.2,
}
\DocumentReference{26262}{
  title = ISO 26262-6 -- Clauses 7 and 10, issue = 2018, scope = external,
}
\UseCase{Heat the cabin to the setpoint}{Vehicle occupant}
\Term{CUT}{Component Under Test}
```
