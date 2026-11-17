<!-- RACI matrix: who is Responsible, Accountable, Consulted, Informed per activity.
     Mermaid has no table diagram; in Markdown pages use this table. -->

| Activity                | PL  | SWA | DEV | TST | QA  |
|-------------------------|:---:|:---:|:---:|:---:|:---:|
| Software requirements   |  A  |  R  |  C  |  C  |  I  |
| Component specification |  A  |  R  |  C  |  C  |     |
| Unit implementation     |     |  A  |  R  |  I  |     |
| Unit test specification |     |  A  |  R  |  C  |     |
| Component test          |  A  |  C  |     |  R  |  I  |
| Release                 | A/R |  I  |  I  |  I  |  C  |

R = Responsible (does the work), A = Accountable (approves, exactly one per activity),
C = Consulted, I = Informed.
