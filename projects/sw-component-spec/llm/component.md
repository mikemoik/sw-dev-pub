# Task: the component (`component.tex`)

This file describes the component as an architecture element (SWE.2): what it does, which units it consists of, which requirements each unit realises, its provided and required interfaces, how its units use each other, who uses it, its resource budgets and configuration. From these the template draws the context diagram, the internal structure diagram and the test harness diagram.

- **`\FunctionalDescription{text}`:** two to five sentences: what the component does and its main constraints. Refer to the architecture document with `\DocRef{key}`.
- **`\Unit{unit}{responsibility}{unit verification}`:** one per unit, in the order they should appear in the diagram. Unit verification names the unit's test specification, e.g. `\DocRef{suts-spc}`.
- **`\Allocate{unit}{REQ, REQ}`:** the requirements from `requirements.tex` that the unit realises. A requirement may be allocated to several units. Emergent properties (timing, total RAM) may stay unallocated.
- **`\ProvidedInterface[unit]{name}{type / range / timing}{description}`:** one per interface offered to other components. `[unit]` is the unit that realises it. Give ranges and call rates (`uint8, [0, 100]`, `void, every 10 ms`).
- **`\RequiredInterface[component]{name}{description}{replaced by}{behaviour in test}`:** one per interface of another component that this component calls. `[component]` names the providing component (one box per component in the diagrams). `replaced by` is `Mock`, `Stub`, `Fake` or `Original` for the component test.
- **`\Uses{unit}{unit or component}{interfaces}`:** one per use relation. To a unit: an internal interface. To a component: a required interface. These draw the arrows of the internal structure diagram.
- **`\Caller{component}{interfaces it calls}`:** who uses the component.
- **`\Resource{resource}{budget}{verified by}`:** CPU (WCET per call or load), RAM, ROM, stack, and how each is verified (test case, analysis).
- **`\ConfigParameter{name}{values / default}{description}`:** calibration or variant parameters.

## Fill it from the architecture or the code

1. Make one `\Unit` per unit of the architecture. Ask for the unit test spec references.
2. Make one `\ProvidedInterface` per public function or signal of the component header, with the realising unit.
3. Make one `\RequiredInterface` per external function called, grouped by providing component. Propose `Mock` for calls the tests check, `Stub` for plain return values, `Fake` for simulated behaviour.
4. Make one `\Uses` per call between units and per call to another component. Every unit should appear in at least one `\Uses` or `\ProvidedInterface`; say so in the open points if not.
5. Check every software requirement of `requirements.tex` is allocated or is emergent.

## Example

```latex
\Unit{setpoint_ctrl}{Range check, ramp limitation and storage of the setpoint}{\DocRef{suts-spc}}
\Allocate{setpoint_ctrl}{SWR-0110, SWR-0120}
\ProvidedInterface[setpoint_ctrl]{SetpointCtrl_Set(sp)}{uint8, [0, 100]}{Sets a new setpoint, returns E_OK / E_NOT_OK}
\RequiredInterface[NvM]{NvM_ReadBlock()}{Reads the stored setpoint}{Stub}{Returns a configurable value and result}
\Uses{heat_pi}{setpoint_ctrl}{SetpointCtrl_GetEffective()}
\Uses{setpoint_ctrl}{NvM}{NvM_ReadBlock(), NvM_WriteBlock()}
\Caller{HeaterApp}{SetpointCtrl_Set()}
\Resource{RAM}{512 bytes}{TC-HC-005 (linker map)}
```
