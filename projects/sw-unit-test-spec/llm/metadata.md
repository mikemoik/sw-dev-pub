# Task: document and unit data (`metadata.tex`)

This file holds the title page, header and identification data, and the revision history. Each command takes one value. Values left out show as grey placeholders in the PDF.

- **Document:** `\DocID{}`, `\DocVersion{}` (e.g. `0.3`), `\DocStatus{}` (exactly `Draft`, `In Review` or `Released`), `\DocDate{}` (YYYY-MM-DD; leave it out for today), `\ProjectName{}`, `\Company{}`, `\Author{}`, `\Reviewer{}`, `\Approver{}`.
- **Unit:** `\UnitName{}` (set by the new-unit script, don't change it), `\UnitBaseline{}` (the code version under test, e.g. `git: 3f2a9c1 (tag v1.4.0)`), `\IntegrityLevel{}` (`QM`, `ASIL A`--`ASIL D`, `SIL n` or `n.a.`), `\SourceFiles{}`, `\Language{}`, `\DesignReference{}` (e.g. `\DocRef{design}, section 4.2`).
- **`\Revision{version}{date}{author}{change}`:** one line per document version, oldest first. The change text says what changed and why ("Fault injection test case added after review").

## Things you can do

- Add the `\Revision` line for a new version, and update `\DocVersion` to match.
- When the status changes to `Released`, check that `\Reviewer`, `\Approver` and `\UnitBaseline` are filled. List what is missing.

Never invent names, IDs or versions. Ask for them.

## Example

```latex
\DocVersion{0.2}
\DocStatus{In Review}
\Revision{0.2}{2026-11-04}{Jane Doe}{Fault injection test case added after review}
```
