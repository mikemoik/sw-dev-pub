# Task: quality assurance (`quality.tex`)

Chapter 6 (SUP.1): QA activities, metrics, escalation.

- **`\QAActivity{activity}{when}{roles}{evidence}`:** process audits, product reviews, sample checks; when (milestone, cadence), who (role IDs), and the evidence it produces.
- **`\Metric{metric}{target}{measured by / when}`:** measurable targets (open problem reports, coverage, static analysis findings, schedule deviation).
- **`\Escalation{text}`:** what happens with QA findings the project does not resolve, and to whom QA reports.

## Example

```latex
\QAActivity{Process audit against this manual}{before M1, M3, M4}{QA}{QA report in WP-QAR}
\Metric{Open PRs of severity A/B}{0 at a release}{Issue tracker, at every release}
```
