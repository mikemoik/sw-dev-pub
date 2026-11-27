# Task: introduction (`introduction.tex`)

Chapter 1: purpose, scope, project identification (from `metadata.tex`), objectives, deliverables, references and terms.

- **`\Purpose{text}`:** optional; the template has a default text. Replace it only if the manual has a special purpose.
- **`\Scope{text}`:** what the project develops and delivers, and what it does not (other teams, basic software, the safety plan). Two short paragraphs: in scope, out of scope.
- **`\ProjectObjective{text}`:** one per objective, measurable (date, capability level, number of open findings).
- **`\Deliverable{deliverable}{recipient}{milestone IDs}`:** what goes to whom, and at which milestone of `lifecycle.tex`.
- **`\DocumentReference{key}{attribute = value, ...}`:** every document cited elsewhere with `\DocRef{key}`: offer, requirements, process handbook, specifications, standards; every listed document must be cited somewhere. Attributes, any order:
  - `title` (always), `number` (document number, e.g. `SRS-SPC-001`) and `issue` (version or edition) — both required for internal documents, `date` (YYYY-MM-DD).
  - `scope = internal` (default: the organisation's own documents) or `scope = external` (standards, guidelines, supplier documents).
  - `classification`: `public`, `internal`, `confidential` or `strictly confidential` (unless the project set other values).
  - `url`: only if the engineer gives one; always in braces, `%` written as `\%`: `url = {https://…}`.
  - `id`: a short label printed instead of [R1], [R2], ... (e.g. `id = SVP`); leave it out unless asked.
  - A value containing `,` or `=` goes in braces: `title = {ISO 26262-6 -- Clauses 7, 10}`.
  - The older `\Reference{key}{internal|external}{document}{version}` still works; write new ones as `\DocumentReference`. Never invent document numbers, issues or URLs: ask for them.
- **`\Term{term}{definition}`:** abbreviations used in the manual.

## Example

```latex
\ProjectObjective{Release \TheComponent\ v2.0 for the start of production on 2027-09-24.}
\Deliverable{Software release (binary, release note)}{Customer}{M3, M4}
\DocumentReference{process}{
  title = Company software process handbook,
  number = PH-SW-003, issue = 4.1, classification = internal,
  url = {https://intranet.example.com/process/PH-SW-003},
}
\Term{SOP}{Start Of Production}
```
