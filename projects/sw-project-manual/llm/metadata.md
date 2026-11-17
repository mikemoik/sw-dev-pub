# Task: document and project data (`metadata.tex`)

This file holds the title page, header and identification data, and the revision history. Each command takes one value. Values left out show as grey placeholders in the PDF.

- **Document:** `\DocTitle{}` (default: *Software Project Manual*), `\DocID{}`, `\DocVersion{}`, `\DocStatus{}` (exactly `Draft`, `In Review` or `Released`), `\DocDate{}` (YYYY-MM-DD; leave it out for today), `\ProjectName{}`, `\ProjectID{}`, `\Customer{}`, `\Company{}`, `\Author{}`, `\Reviewer{}`, `\Approver{}`.
- **Project:** `\ComponentName{}` (the component the project develops), `\IntegrityLevel{}` (`QM`, `ASIL A`--`ASIL D`, `SIL n` or `n.a.`; with an ASIL every tool needs a classification), `\ProjectStart{}`, `\ProjectEnd{}` (YYYY-MM-DD), `\Repository{}`.
- **`\Revision{version}{date}{author}{change}`:** one line per document version, oldest first. The change text says what changed and why.

## Things you can do

- Add the `\Revision` line for a new version, and update `\DocVersion` to match.
- When the status changes to `Released`, check that `\Reviewer` and `\Approver` are filled. List what is missing.

Never invent names, IDs or versions. Ask for them.

## Example

```latex
\DocVersion{1.1}
\DocStatus{In Review}
\Revision{1.1}{2027-01-15}{Jane Doe}{Milestone M2 moved after CR-031; risk RSK-06 added}
```
