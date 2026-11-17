# Figure: RACI matrix

Who is Responsible, Accountable, Consulted and Informed for each activity or work product, as a table with coloured letters. Typical in the project manual (work products, responsibilities).

## TikZ: `\begin{sfRaci}` … `\end{sfRaci}`

This is a table, not a picture. Put it in a `table` or `center` environment, not in a `figure` file for `\InputFigure`.

- **`\Roles{ID, ID, ...}`:** the columns, in order. Give it first, once.
- **`\Activity{name}{ID=letter, ID=letter, ...}`:** one row. Letters: `R` responsible (does the work), `A` accountable (approves), `C` consulted, `I` informed. Combine with `/` when one role has two (`PL=A/R`). Roles not listed stay empty.
- **Options:** none.
- **Red marks:** an activity without exactly one `A` or without any `R` (its name turns red), an unknown role, a letter other than R, A, C, I, an entry that is not `ID=letter`.

## Mermaid: none

- Mermaid has no table diagram. In Markdown pages write a Markdown table: one column per role (centred, `:---:`), one row per activity, the letters as text, `A/R` for two letters. Add the legend line under the table.

## From a table

- A matrix with roles as columns → `\Roles{...}` from the header, one `\Activity` per row with only the non-empty cells.
- A list with columns *activity*, *role*, *letter* → group the rows by activity, one `\Activity` per activity.
- Several roles marked `A` in one row: keep them as given; the red mark shows it. Mention it in the open points.
