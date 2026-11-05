/* setpoint_ctrl.h -- public API of the heater setpoint controller (excerpt) */
#ifndef SETPOINT_CTRL_H
#define SETPOINT_CTRL_H

#include "Std_Types.h"

typedef enum
{
    SETPOINTCTRL_IDLE,     /* normal operation, setpoint from NvM */
    SETPOINTCTRL_DEGRADED  /* NvM unreadable, default setpoint 20 */
} SetpointCtrl_StateType;

Std_ReturnType SetpointCtrl_Init(void);
Std_ReturnType SetpointCtrl_Set(uint8 sp);   /* 0..100, else E_NOT_OK */
SetpointCtrl_StateType SetpointCtrl_GetState(void);
void SetpointCtrl_Main(void);                /* every 10 ms */

#endif /* SETPOINT_CTRL_H */
