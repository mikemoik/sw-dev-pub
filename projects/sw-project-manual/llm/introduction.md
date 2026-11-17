# Task: introduction (`introduction.tex`)

Chapter 1: purpose, scope, project identification (from `metadata.tex`), objectives, deliverables, references and terms.

- **`\Purpose{text}`:** optional; the template has a default text. Replace it only if the manual has a special purpose.
- **`\Scope{text}`:** what the project develops and delivers, and what it does not (other teams, basic software, the safety plan). Two short paragraphs: in scope, out of scope.
- **`\ProjectObjective{text}`:** one per objective, measurable (date, capability level, number of open findings).
- **`\Deliverable{deliverable}{recipient}{milestone IDs}`:** what goes to whom, and at which milestone of `lifecycle.tex`.
- **`\Reference{key}{internal | external}{document}{version}`:** every document cited elsewhere with `\DocRef{key}`: offer, requirements, process handbook, specifications, standards.
- **`\Term{term}{definition}`:** abbreviations used in the manual.

## Example

```latex
\ProjectObjective{Release \TheComponent\ v2.0 for the start of production on 2027-09-24.}
\Deliverable{Software release (binary, release note)}{Customer}{M3, M4}
\Reference{process}{internal}{Company software process handbook, PH-SW-003}{4.1}
\Term{SOP}{Start Of Production}
```
