# Task: open point list (`opl.tex`)

Chapter 10: the project's open point list, converted from an export of the tool where the open points are kept (issue tracker, spreadsheet, meeting minutes). The engineer pastes or attaches the export (CSV, table, list). You turn it into `\OpenPoint` lines. The template sorts and prints them: top 5 (repeated), in progress, open, closed; the top-5 points are highlighted in their status list.

- **`\OpenPointExport{date}{source}`:** as-of date of the export (YYYY-MM-DD) and where it comes from (tool, filter or file name). Due dates before this date are marked overdue.
- **`\OpenPoint[top rank]{ID}{topic}{status}{responsible}{date}{comment}`:**
  - `[top rank]`: `1` to `5`, only for the top-5 points; leave it out for all others. Each rank at most once, only on points that are open or in progress.
  - ID: as in the export (e.g. `OP-012`, `HC-142`). Each ID once.
  - topic: one sentence, as in the export; shorten only very long texts.
  - status: exactly `open`, `in progress` or `closed`.
  - responsible: the person (or role) as in the export.
  - date: YYYY-MM-DD. For open and in-progress points the due date; for closed points the closing date (the due date if the export has none, else empty).
  - comment: the latest status note or, for closed points, the result. Empty `{}` if none.

## Converting an export

1. **Columns.** Map the export's columns to the fields above. If a field has no obvious column, say which column you use or leave it empty; don't invent content.
2. **Status.** Map the export's statuses to the three values, e.g. new, to do, planned → `open`; in work, ongoing, in review, blocked → `in progress`; done, resolved, rejected, cancelled → `closed`. List every mapping you used in one line before the code block. If a status is unclear, ask.
3. **Top 5.** Take the ranks from the export (a column such as Top 5, rank, priority order). If the export has no such column, ask the engineer which points are the top 5 and in which order; never pick them yourself.
4. **Dates.** Convert every date to YYYY-MM-DD (e.g. `12.11.2026` and `11/12/2026` are ambiguous between formats: ask if the export's format is unclear).
5. **Text.** Escape `& % # $` as `\& \% \# \$`; replace line breaks inside a cell by a space; drop HTML or Markdown markup.
6. **Order.** One line per point, in the order of the export. The template does the sorting.
7. **Answer** with the whole file: the comment lines of the command reference, `\OpenPointExport`, then all `\OpenPoint` lines. This replaces the old `opl.tex`. With more than about 40 points, convert 40 per answer and continue when the engineer says "next".

## GitLab issue exports

A GitLab export that follows the project conventions is converted by `scripts/gitlab_opl.py` without you. You get GitLab exports only when they don't follow them; the engineer usually gives you the reduced file from `gitlab_opl.py --slim`. Use the same mapping as the script, and ask about anything that deviates:

- ID: `\#` + Issue ID (e.g. `\#142`); topic: Title; responsible: Assignee.
- status: State `Closed` → `closed`; label `workflow::in progress` → `in progress`; otherwise `open`. Ask how other labels (e.g. `Doing`, `workflow::review`) map.
- top rank: label `top::1` … `top::5`.
- date: Due Date; for closed issues the date part of Closed At.
- comment: empty, unless the engineer names a column (e.g. Milestone).
- as-of date: ask for the export date; source: `GitLab issue export <file name>`.

## Things you can do

- Point out open or in-progress points without a responsible or a due date, and top-5 points that are closed.
- Compare two exports and list the points that are new, closed or changed.

## Example

Export row (CSV): `OP-011;Timing budget per task not yet given by the system team;Open;J. Doe;04.12.2026;Top 2;Needed for v0.9`

```latex
\OpenPoint[2]{OP-011}{Timing budget per task not yet given by the system team}{open}{J. Doe}{2026-12-04}{Needed for v0.9}
```
