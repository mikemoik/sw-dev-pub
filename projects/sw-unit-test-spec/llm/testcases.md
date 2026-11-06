# Task: test cases (`testcases.tex`)

This file holds the test case specification (ISO 29119-3 test case specification, SWE.4 unit verification, ISO 26262-6 9.4.2/9.4.3). Each `TestCase` becomes one box in the PDF and one entry in the list of test cases. Its `\Verifies` fills the traceability tables automatically.

## Add a test case

Work through these points. Ask for what you can't take from the files.

1. **Requirement.** Find the internal requirement(s) it verifies in `requirements.tex` (`\InternalRequirement{ID}...`) and use them in `\Verifies{ID, ID}`. Use only declared IDs. If none fits, say so and offer a new `\InternalRequirement` for `requirements.tex` as a separate block. The engineer decides.
2. **ID.** Continue the existing scheme with the next free number (e.g. after TC-SPC-003 comes TC-SPC-004). IDs are unique. The title is a short statement of what is checked.
3. **Group.** Put it under the fitting existing `\TestGroup{}`. Propose a new group only if none fits.
4. **Method.** Name the derivation technique: requirements-based, equivalence class partitioning, boundary value analysis, fault injection, error guessing, interface test.
5. **Priority.** High, Medium or Low. Safety-related requirements and the main function are High.
6. **Preconditions.** Give the unit's state and how each mock or stub is configured. Mocks and stubs are the `\Dependency` lines in `unit.tex`. You may refer to another test case for the setup ("Unit initialised (TC-SPC-001).").
7. **Inputs.** One `\InputValue{name}{value}{class}` per value, the class naming its equivalence class or boundary (e.g. `max (valid)`, `max+1 (invalid)`). Use `\InputData{none}` or free text if there is no input value.
8. **Steps.** One `\Step{action}{expected result}` per action. An action calls an interface from `unit.tex` (`\Interface`) or checks a mock. Each expected result can be observed: a return value, a state, a call count or recorded data of a mock, an output value (with tolerance for real numbers).
9. **Postconditions.** The state after the test. **Implementation:** the test file and test name, only if the engineer gives them. Otherwise leave the field out.

Fields are optional and may be in any order; the template prints them in a fixed order. Write them in the order of the example.

## Other things you can do

- **Change** a test case: return the whole `TestCase` block as a replacement.
- **Find gaps:** list internal requirements that appear in no `\Verifies` and have no `\NotUnitTested` line in `requirements.tex`. Propose test cases for them (first only ID, title, method, one line each, then the full block on request).
- **Derive boundary tests** from an `\Interface` range, e.g. `[0, 100]` gives min, max, max+1 (and min-1 if the type allows it).
- **Review** a test case against the checklist below.

## Checklist

- `\Verifies` lists only declared requirement IDs.
- Every step has a concrete, observable expected result.
- Preconditions say how each mock involved is configured.
- Invalid and boundary inputs are covered for every range requirement.
- The ID is unique, the title says what is checked.

## Example

```latex
\TestGroup{Boundary Values}

\begin{TestCase}{TC-SPC-002}{Setpoint accepted at upper limit}
  \Objective{Range check of the setpoint at its upper bound.}
  \Verifies{SWR-0110}
  \Method{Boundary value analysis}
  \Priority{High}
  \Preconditions{Unit initialised (TC-SPC-001).}
  \InputValue{sp}{100}{max (valid)}
  \InputValue{sp}{101}{max+1 (invalid)}
  \Step{SetpointCtrl_Set(100)}{Returns E_OK; setpoint = 100.}
  \Step{SetpointCtrl_Set(101)}{Returns E_NOT_OK; setpoint unchanged (100).}
  \Postconditions{Setpoint = 100.}
  \Implementation{test/setpoint_ctrl_test.cpp: RangeTest.UpperLimit}
\end{TestCase}
```

A `FreeText` block between test cases (any LaTeX) is printed where it stands, e.g. a note on tolerances that applies to a whole group.
