# Task: risks (`risks.tex`)

Chapter 7 (MAN.5): the risk register and a generated 3 x 3 risk matrix (probability x impact; green, yellow, red).

- **`\Risk{ID}{risk}{probability}{impact}{mitigation}{owner role}`:** probability and impact are `low`, `medium` or `high`. The risk text names the cause and the effect. The mitigation is a concrete action (who does what, by when) or a contingency. The owner is a role ID.

## Things you can do

- Propose risks from the other files: late inputs from stakeholders, single members in a role, tight milestones, tool licences, timing or memory budgets.
- Check that every risk has a mitigation and an owner.

## Example

```latex
\Risk{RSK-01}{Basic software release of the platform team comes late}{medium}{high}{Stubs of the BSW interfaces in the component test; monthly alignment with the platform team}{PL}
```
