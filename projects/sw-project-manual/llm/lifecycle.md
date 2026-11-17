# Task: process and lifecycle (`lifecycle.tex`)

Chapter 3: process reference, process tailoring, milestones and releases with a generated timeline.

- **`\ProcessReference{text}`:** which process the project follows (company handbook, Automotive SPICE version, target capability level) and the development rhythm (sprints, phases).
- **`\Process{ID}{name}{yes | no | tailored}{rationale}`:** one per process of the reference model that is relevant. `no` and `tailored` need a rationale. An applied process (`yes`/`tailored`) needs at least one `\WorkProduct` in `workproducts.tex` that names it; the table shows the work products per process.
- **`\Milestone{ID}{date}{name}{exit criteria: work product IDs}`:** dates as YYYY-MM-DD (the timeline is to scale only if all dates have this form). The exit criteria are the work products that must be done.
- **`\Release{version}{date}{content}{milestone ID}`:** planned software releases; the milestone may stay empty for intermediate releases.

## Things you can do

- Propose the process list for a component project: MAN.3, MAN.5, SWE.1--SWE.6, SUP.1, SUP.8, SUP.9, SUP.10 applied; SYS.x and HWE.x usually `no` with a rationale.
- Check that each milestone's exit criteria are declared work products.

## Example

```latex
\Process{SWE.6}{Software verification}{tailored}{Qualification test on the system team's HIL; we provide the specification}
\Milestone{M2}{2027-02-12}{Architecture released}{WP-SWCS}
\Release{v1.0}{2027-05-07}{Feature complete}{M3}
```
