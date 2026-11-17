# Task: organisation (`organization.tex`)

Chapter 2: roles, the organisation chart (generated), team, stakeholders, meetings, reporting.

- **`\Role[reports to]{ID}{name}{responsibility}`:** one per role. The ID is short (PL, SWA, DEV, TST, QA, CM) and is used by every other file. `[reports to]` is the ID of the superior role and draws the organisation chart; the top role has none. QA should not report to the project lead if independence is required.
- **`\Member{name}{role IDs}{organisation / contact}`:** one per person; a person may hold several roles. Every role needs at least one member.
- **`\Stakeholder{stakeholder}{interest / interface}{contact role}`:** customer, other teams, safety manager, suppliers, and which role is their contact.
- **`\Meeting{meeting}{cadence}{participant roles}{purpose / output}`:** recurring meetings with their output (decisions, minutes, backlog).
- **`\Communication{text}`:** reporting (who reports what to whom, how often), where decisions are recorded, project language.

## Things you can do

- Check that every role has a member and every meeting has participants.
- Propose missing roles for the processes in `lifecycle.tex` (e.g. a configuration manager for SUP.8).

Never invent people. Ask for names.

## Example

```latex
\Role{PL}{Project lead}{Plan, budget, schedule, customer contact, risks}
\Role[PL]{SWA}{Software architect}{Requirements analysis, architecture}
\Member{Lee Noe}{DEV, CM}{Example Corp, SW Engineering}
\Meeting{Change board}{weekly}{PL, SWA, CM}{Decisions on CRs and PRs}
```
