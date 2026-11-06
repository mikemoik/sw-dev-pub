# Task: unit under test (`unit.tex`)

This file describes the unit as seen by the test: what it does, its interfaces, what it depends on and how those dependencies are replaced in the test, and who calls it. From `\Interface`, `\Dependency` and `\Caller` the template draws the context diagram and the test harness diagram.

- **`\FunctionalDescription{text}`:** two to five sentences: what the unit does and its main constraints. Refer to the design document with `\DocRef{key}`.
- **`\Interface{name}{direction}{type / range}{description}`:** one per function or signal. `direction` is `in`, `out` or `inout` as seen from the unit. Give the range for every value input (`uint8, [0, 100]`). List return values in the description.
- **`\Dependency[component]{name}{replaced by}{behaviour in test}`:** one per called function of another unit. `replaced by` is `Mock`, `Stub`, `Fake` or `Original`. The behaviour says what the replacement returns and records. `[component]` groups functions of one component in one box.
- **`\Caller{component}{interfaces it calls}`:** who uses the unit.
- **`FreeText`:** e.g. a `\subsection{Public API (excerpt)}` with `\InputCode{file.h}` (the file goes to the unit's `code/` folder).

## Fill it from source code

When the engineer pastes a header or source excerpt:

1. Make one `\Interface` per public function, with parameter types and ranges. Ask for ranges that the code doesn't show.
2. Make one `\Dependency` per external function the unit calls. Propose `Mock` for functions whose calls the tests check, and `Stub` for plain return values.
3. Ask who calls the unit if that isn't known.

## Example

```latex
\Interface{SetpointCtrl_Set(sp)}{in}{uint8, [0, 100]}{Sets a new setpoint, returns E_OK / E_NOT_OK}
\Interface{SetpointCtrl_GetState()}{out}{enum}{IDLE / DEGRADED}
\Dependency[NvM]{NvM_ReadBlock()}{Mock}{Returns a configurable value, records calls}
\Caller{HeaterApp}{SetpointCtrl_Init(), SetpointCtrl_Set()}
```
