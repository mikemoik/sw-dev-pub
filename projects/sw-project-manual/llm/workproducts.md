# Task: work products (`workproducts.tex`)

Chapter 4: work product list, reviews and the responsibility matrix. The RACI matrix is generated: R from `\WorkProduct`, A (approves) from the `\Review` approver, C from the reviewers, I from `\Informed`.

- **`\WorkProduct{ID}{name}{process IDs}{responsible role}{template / location}`:** one per work product the project creates. Process IDs from `lifecycle.tex`, role ID from `organization.tex`. Name the template (e.g. `sw-component-spec template`) or where it lives.
- **`\Review{work product}{method}{reviewer roles}{approver role}`:** how the work product is reviewed (inspection with checklist, walkthrough, merge request review) and who approves it. Reviewers should not be the responsible role.
- **`\Informed{work product}{roles}`:** roles that are informed about a new version.

## Things you can do

- Propose one work product per applied process that has none (red in chapter 3).
- Check that every work product has a review and that author and reviewer differ.

## Example

```latex
\WorkProduct{WP-SWCS}{Software component specification}{SWE.2, SWE.5}{SWA}{sw-component-spec template}
\Review{WP-SWCS}{Inspection with checklist CL-ARCH}{DEV, TST, QA}{PL}
\Informed{WP-SWCS}{CM}
```
