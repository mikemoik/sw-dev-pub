# Task: developer manual (`development.tex`)

Chapter 9: how the team works day to day: engineering rules, CI pipeline (drawn as a chain), Definition of Done, and step-by-step how-tos. Tool names must match `environment.tex`.

- **`\Rule{area}{rule}{enforced by: tools}`:** coding standard, formatting, naming, tests, reviews. Leave the tools empty if the rule is checked by review.
- **`\CIStage{stage}{does / checks}{tools}{blocking: yes | no}`:** pipeline stages in order. Blocking stages stop the merge.
- **`\DoneCriterion{text}`:** one per criterion of the Definition of Done.
- **`HowTo`:** `\begin{HowTo}{ID}{title}` ... `\end{HowTo}` with `\Goal{text}`, `\Tools{tool, tool}` and one `\Step{action}{command}` per step. The command is printed in typewriter on its own line; leave it empty for steps without a command. In commands escape `\#` `\$` `\%` `\&` and write `~` as `\textasciitilde`.

## Things you can do

- Write a how-to from a description or a shell history the engineer pastes.
- Check that every tool named in rules, stages and how-tos is declared in `environment.tex`.

## Example

```latex
\Rule{Formatting}{\code{.clang-format} of the repository, checked in CI}{clang-format}
\CIStage{Static analysis}{MISRA check, new violations fail}{cppcheck}{yes}
\begin{HowTo}{HT-SETUP}{Set up the workspace}
  \Goal{A fresh clone that builds and runs the tests.}
  \Tools{CMake, GCC}
  \Step{Configure the host build.}{cmake --preset host}
  \Step{Build and run all tests.}{cmake --build --preset host \&\& ctest --preset host}
\end{HowTo}
```
