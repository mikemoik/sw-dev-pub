# Task: introduction (`introduction.tex`)

This file holds the scope, the referenced documents, the use cases and the terms.

- **`\Purpose{text}`:** optional. Only replaces the default purpose paragraph if the engineer wants other wording.
- **`\Scope{text}`:** two paragraphs, "In scope: ..." (which interfaces, functions and configuration of the unit) and "Out of scope: ..." (what is tested elsewhere, and where).
- **`\DocumentReference{key}{attribute = value, ...}`:** one per document. `key` is a short lowercase name, cited anywhere as `\DocRef{key}`; every listed document must be cited somewhere. Attributes, any order:
  - `title` (always), `number` (document number, e.g. `SRS-SPC-001`) and `issue` (version or edition) — both required for internal documents, `date` (YYYY-MM-DD).
  - `scope = internal` (default: the organisation's own documents — SRS, design, plans) or `scope = external` (standards, guidelines, supplier documents).
  - `classification`: `public`, `internal`, `confidential` or `strictly confidential` (unless the project set other values).
  - `url`: only if the engineer gives one; always in braces, `%` written as `\%`: `url = {https://…}`.
  - `id`: a short label printed instead of [R1], [R2], ... (e.g. `id = SVP`); leave it out unless asked.
  - A value containing `,` or `=` goes in braces: `title = {ISO 26262-6 -- Part 6, Clause 9}`.
  - Put the requirements and design documents first. The older `\Reference{key}{internal|external}{document}{version}` still works; write new ones as `\DocumentReference`.
- **`\UseCase{use case}{actor, actor}`:** system use cases the unit contributes to, usually taken from the SRS. `\UseCaseNote{text}` adds a sentence above the diagram.
- **`\Term{term}{definition}`:** abbreviations and project terms used in the document.

## Other things you can do

- **Scope:** draft it from `unit.tex` and the engineer's notes.
- **Terms:** list abbreviations used in the files but not yet defined as `\Term`.
- **References:** suggest the usual standards as external references, e.g. ISO/IEC/IEEE 29119-3, Automotive SPICE SWE.4, ISO 26262-6 clause 9, MISRA C:2012. Only add the ones that apply to the project; ask about versions. Never invent document numbers, issues or URLs: ask for them.
- **Old form:** convert `\Reference{key}{scope}{document}{version}` lines to `\DocumentReference` when asked; split a document number out of the title into `number`.

## Example

```latex
\Scope{
  In scope: the public API of \TheUnit\ (initialisation, setpoint handling,
  state query) in its series configuration.

  Out of scope: the NvM driver (tested in its own unit), integration with the
  heater power stage (integration test).
}
\DocumentReference{srs}{
  title = Software Requirements Specification,
  number = SRS-SPC-001, issue = 1.3, date = 2026-09-14,
  classification = confidential,
  url = {https://plm.example.com/docs/SRS-SPC-001},
}
\DocumentReference{26262}{
  title = {ISO 26262-6 -- Road vehicles, Functional safety, Part 6},
  issue = 2018, scope = external,
}
\UseCase{Restore setpoint after restart}{Vehicle occupant}
\Term{NvM}{Non-volatile Memory manager}
```
