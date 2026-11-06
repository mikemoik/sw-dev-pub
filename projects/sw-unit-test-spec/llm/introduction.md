# Task: introduction (`introduction.tex`)

This file holds the scope, the referenced documents, the use cases and the terms.

- **`\Purpose{text}`:** optional. Only replaces the default purpose paragraph if the engineer wants other wording.
- **`\Scope{text}`:** two paragraphs, "In scope: ..." (which interfaces, functions and configuration of the unit) and "Out of scope: ..." (what is tested elsewhere, and where).
- **`\Reference{key}{internal|external}{document}{version}`:** one per document. `internal` is the organisation's own documents (SRS, design, plans). `external` is standards, guidelines and supplier documents. `key` is a short lowercase name, cited anywhere as `\DocRef{key}`. They are numbered [R1], [R2], ... in this order. Put the requirements and design documents first.
- **`\UseCase{use case}{actor, actor}`:** system use cases the unit contributes to, usually taken from the SRS. `\UseCaseNote{text}` adds a sentence above the diagram.
- **`\Term{term}{definition}`:** abbreviations and project terms used in the document.

## Other things you can do

- **Scope:** draft it from `unit.tex` and the engineer's notes.
- **Terms:** list abbreviations used in the files but not yet defined as `\Term`.
- **References:** suggest the usual standards as external references, e.g. ISO/IEC/IEEE 29119-3, Automotive SPICE SWE.4, ISO 26262-6 clause 9, MISRA C:2012. Only add the ones that apply to the project; ask about versions.

## Example

```latex
\Scope{
  In scope: the public API of \TheUnit\ (initialisation, setpoint handling,
  state query) in its series configuration.

  Out of scope: the NvM driver (tested in its own unit), integration with the
  heater power stage (integration test).
}
\Reference{srs}{internal}{Software Requirements Specification, SRS-SPC-001}{1.3}
\Reference{26262}{external}{ISO 26262-6 -- Clause 9, Software unit verification}{2018}
\UseCase{Restore setpoint after restart}{Vehicle occupant}
\Term{NvM}{Non-volatile Memory manager}
```
