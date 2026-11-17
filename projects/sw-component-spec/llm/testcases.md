# Task: test cases (`testcases.tex`)

This file holds the test case specification (ISO 29119-3, ASPICE SWE.5, ISO 26262-6 clause 10). Each `TestCase` becomes one box in the PDF and one entry in the list of test cases. Its `\Verifies` and `\Integration` fill the traceability tables automatically.

A component test case stimulates the component through its provided interfaces (`\ProvidedInterface` in `component.tex`) and observes its outputs and the test doubles of its required interfaces. It checks how the units work together, not one unit's inside.

## Add a test case

Work through these points. Ask for what you can't take from the files.

1. **Requirement.** Find the requirement(s) it verifies in `requirements.tex` and use them in `\Verifies{ID, ID}`. Use only declared IDs. If none fits, offer a new `\ComponentRequirement` as a separate block.
2. **Integration step.** `\Integration{ID}` names the step of `approach.tex` (`\IntegrationStep`) whose units the test runs with. Use only declared steps.
3. **ID and title.** Continue the existing scheme with the next free number. The title is a short statement of what is checked.
4. **Group.** Put it under the fitting `\TestGroup{}`; propose a new group only if none fits.
5. **Method.** Requirements-based, interface test, fault injection, resource usage evaluation, equivalence classes, error guessing.
6. **Priority.** High, Medium or Low. Safety-related requirements and the main function are High.
7. **Preconditions.** Mode of the component and how each test double is configured (the `\RequiredInterface` lines in `component.tex`), and which units are stubbed if the step is not complete.
8. **Inputs.** `\InputValue{name}{value}{class}` per value, or `\InputData{text}`.
9. **Steps.** One `\Step{action}{expected result}` per action. An action calls a provided interface, lets time pass (n calls of the main function) or injects a value through a test double. Each expected result is observable at the boundary: a return value, a mode, recorded calls or data of a test double, an output with tolerance, a measured resource.
10. **Implementation:** test file and test name, only if the engineer gives them.

## Other things you can do

- **Find gaps:** requirements in no `\Verifies` and without `\NotComponentTested`; integration steps without a test case; required interfaces never exercised in a fault case.
- **Change** a test case: return the whole `TestCase` block as a replacement.
- **Review** a test case against the checklist below.

## Checklist

- `\Verifies` and `\Integration` use only declared IDs.
- Every step has a concrete, observable expected result at the component boundary.
- Preconditions say how each test double involved is configured.
- Each fault the component handles (`ErrorHandling` in `design.tex`) has a fault injection test.
- The ID is unique, the title says what is checked.

## Example

```latex
\begin{TestCase}{TC-HC-002}{Implausible temperature switches the heater off}
  \Objective{Sensor fault detected in temp_filter leads to duty 0 in heat_pi.}
  \Verifies{SWR-0200}
  \Integration{IS-1}
  \Method{Fault injection}
  \Priority{High}
  \Preconditions{Running as in TC-HC-001, duty above 0.}
  \InputValue{IoHwAb_GetCabinTemp()}{-500 (= -50.0)}{below plausible range}
  \Step{Inject the value and call HeaterCtrl_MainFunction() 10 times.}{Duty 0 from the first call on.}
  \Step{Check the Dem mock.}{DEM_E_TEMP_SENSOR reported once.}
  \Implementation{test/heater_ctrl_test.cpp: ControlPath.SensorFault}
\end{TestCase}
```

A `FreeText` block between test cases (any LaTeX) is printed where it stands.
