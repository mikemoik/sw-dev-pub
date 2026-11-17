# Task: configuration and change management (`configuration.tex`)

Chapter 5 (SUP.8, SUP.9, SUP.10): configuration items, branching model, baselines, naming conventions, change and problem workflows (drawn as state chains), release procedure.

- **`\ConfigItem{item}{location}{controlled by}`:** what is under configuration control, where, and how (merge requests, tags, tool baselines).
- **`\BranchingModel{text}`:** branches, how changes get to the main branch, release and maintenance branches.
- **`\Baseline{ID}{when / trigger}{content}{label}`:** when a baseline is taken (milestone, release), what it contains, how it is labelled.
- **`\Naming{object}{rule}{example}`:** branch, tag, commit message, file names.
- **`\Workflow{ID}{name}{states, in order}{tool / where}`:** one per workflow (change request, problem report); the states are comma-separated and drawn left to right.
- **`\ReleaseProcedure{text}`:** who creates a release from what, what it contains, who signs and approves it.

## Example

```latex
\Baseline{BL-REL}{every release}{Code, tests, specifications, tool versions}{tag \code{heater_ctrl-vX.Y.Z}}
\Naming{Release tag}{\code{heater_ctrl-v<major>.<minor>.<patch>}}{heater_ctrl-v1.0.0}
\Workflow{PR}{Problem report (SUP.9)}{New, Analysed, In work, Fixed, Verified, Closed}{Issue tracker, type Bug}
```
