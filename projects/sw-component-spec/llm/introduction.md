# Task: introduction (`introduction.tex`)

This file holds the scope, the referenced documents, the use cases and the terms.

- **`\Purpose{text}`:** optional. Only replaces the default purpose paragraph if the engineer wants other wording.
- **`\Scope{text}`:** two paragraphs, "In scope: ..." (the component, its units, interfaces and configuration) and "Out of scope: ..." (the units' insides, verified by their unit test specs; neighbouring components; system integration).
- **`\Reference{key}{internal|external}{document}{version}`:** one per document. `internal` is the organisation's own documents (SRS, design, plans). `external` is standards, guidelines and supplier documents. `key` is a short lowercase name, cited anywhere as `\DocRef{key}`. They are numbered [R1], [R2], ... in this order. Put the requirements and architecture documents first, then the unit test specifications of the units.
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
\Reference{arch}{internal}{Software Architecture Description, SAD-HC-002}{2.0}
\Reference{suts-spc}{internal}{Software Unit Test Specification setpoint_ctrl, SUTS-SPC-001}{0.2}
\Reference{26262}{external}{ISO 26262-6 -- Clauses 7 and 10}{2018}
\UseCase{Heat the cabin to the setpoint}{Vehicle occupant}
\Term{CUT}{Component Under Test}
```
