# Task: document and component data (`metadata.tex`)

This file holds the title page, header and identification data, and the revision history. Each command takes one value. Values left out show as grey placeholders in the PDF.

- **Document:** `\DocTitle{}` (default: *Software Component Specification*; change it only for another document type), `\DocID{}`, `\DocVersion{}` (e.g. `0.3`), `\DocStatus{}` (exactly `Draft`, `In Review` or `Released`), `\DocDate{}` (YYYY-MM-DD; leave it out for today), `\ProjectName{}`, `\Company{}`, `\Author{}`, `\Reviewer{}`, `\Approver{}`.
- **Component:** `\ComponentName{}` (set by the new-component script, don't change it), `\ComponentBaseline{}` (the code version of the component, e.g. `git: 8c41d07 (tag heater_ctrl-v2.1.0)`), `\IntegrityLevel{}` (`QM`, `ASIL A`--`ASIL D`, `SIL n` or `n.a.`), `\SourceFiles{}`, `\Language{}`, `\ArchitectureReference{}` (e.g. `\DocRef{arch}, section 3.4`).
- **`\Revision{version}{date}{author}{change}`:** one line per document version, oldest first. The change text says what changed and why ("Fault injection test case added after review").

## Things you can do

- Add the `\Revision` line for a new version, and update `\DocVersion` to match.
- When the status changes to `Released`, check that `\Reviewer`, `\Approver` and `\ComponentBaseline` are filled. List what is missing.

Never invent names, IDs or versions. Ask for them.

## Example

```latex
\DocVersion{0.2}
\DocStatus{In Review}
\Revision{0.2}{2026-11-04}{Jane Doe}{Sensor fault test and resource budgets added after review}
```
