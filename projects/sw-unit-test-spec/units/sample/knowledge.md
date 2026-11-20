---
unit: setpoint_ctrl
sources:
  - {id: S1, file: setpoint_ctrl.h, kind: code, date: 2026-11-04}
  - {id: S2, file: srs_export.csv, kind: requirements, date: 2026-11-04, columns: ID / Text / Type / Source}
---
# Knowledge about the unit

Collected from the sources above, one input at a time (see llm/knowledge.md).
Entries: `K-<SEC>-<n>: fact. [sources]`.

## Purpose (PUR)
- K-PUR-1: Public API of the heater setpoint controller. [S1]

## Interfaces (IF)
- K-IF-1: `Std_ReturnType SetpointCtrl_Init(void)`. [S1]
- K-IF-2: `Std_ReturnType SetpointCtrl_Set(uint8 sp)`: accepts 0..100, else returns `E_NOT_OK`. [S1]
- K-IF-3: `SetpointCtrl_StateType SetpointCtrl_GetState(void)`, values `SETPOINTCTRL_IDLE`, `SETPOINTCTRL_DEGRADED`. [S1]
- K-IF-4: `void SetpointCtrl_Main(void)`, called every 10 ms. [S1]

## Dependencies (DEP)
- K-DEP-1: Includes `Std_Types.h` (`Std_ReturnType`, `uint8`). [S1]

## Callers (CALL)
- none yet

## Requirements (REQ)
- K-REQ-1: STK-010 (functional): The occupant can select a heating setpoint between 0 and 100. [S2]
- K-REQ-2: STK-011 (functional): The selected setpoint is kept across ignition cycles. [S2]
- K-REQ-3: STK-012 (functional): The service technician can read the controller state. [S2]
- K-REQ-4: STK-020 (non-functional): Setpoint changes take effect smoothly, without steps in heating power. [S2]
- K-REQ-5: STK-021 (non-functional): Faults of persistent storage must not lead to an undefined heater state (ASIL B). [S2]

## Behavior (BEH)
- K-BEH-1: State `SETPOINTCTRL_IDLE`: normal operation, setpoint from NvM. [S1]
- K-BEH-2: State `SETPOINTCTRL_DEGRADED`: NvM unreadable, default setpoint 20. [S1]

## Parameters (PAR)
- K-PAR-1: Default setpoint in DEGRADED: 20. [S1]

## Timing (TIM)
- K-TIM-1: `SetpointCtrl_Main()` cycle: 10 ms. [S1]

## Error handling (ERR)
- K-ERR-1: `SetpointCtrl_Set()` rejects setpoints outside 0..100 with `E_NOT_OK`. [S1]

## Test hints (TEST)
- none yet

## Conflicts (CON)
- none yet

## Open questions (Q)
- K-Q-1: Which NvM functions are called, and when (implied by K-BEH-1, K-BEH-2)?
- K-Q-2: Is the previous setpoint kept when `SetpointCtrl_Set()` returns `E_NOT_OK`?
- K-Q-3: Is a fault reported when NvM is unreadable?
- K-Q-4: Who calls the unit?
