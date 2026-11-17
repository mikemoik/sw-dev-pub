/* heater_ctrl.h -- public API of the component heater_ctrl (excerpt) */
#ifndef HEATER_CTRL_H
#define HEATER_CTRL_H

#include "Std_Types.h"

void HeaterCtrl_Init(void);
void HeaterCtrl_MainFunction(void);              /* every 10 ms */

Std_ReturnType SetpointCtrl_Set(uint8 sp);       /* 0..100 */
SetpointCtrl_StateType SetpointCtrl_GetState(void);

#endif /* HEATER_CTRL_H */
