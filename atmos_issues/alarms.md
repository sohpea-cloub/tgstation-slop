# Air alarms, sensors, consoles, firelocks and lungs

## ALARM-1: Breath temperature damage never applies (high, verified)

- **Fixed in:** [`atmos/lungs`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/lungs)
- **Location:** `code/modules/surgery/organs/internal/lungs/_lungs.dm:798`
- **What's wrong:** `if((breath_temperature > cold_level_1_threshold) || (breath_temperature < heat_level_1_threshold)) return`. The cold threshold is always below the heat threshold, so every temperature satisfies one side and the proc returns. It should be `&&`. This came in with #97883.
- **Effect:** for every lung type, breathing 5000 K or 50 K air causes no burns, no frostbite, no lung damage and no message.

## ALARM-2: Air alarm returns early on pressure/temperature hazards (high, verified)

- **Fixed in:** [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm)
- **Location:** `code/modules/atmospherics/machinery/air_alarm/_air_alarm.dm:605-628` (it skips lines 636-639)
- **What's wrong:** each `is_low_pressure` / `is_high_temp` branch sets `warning_message` and then `return`s. That skips both `update_appearance()` and `selected_mode.replace(my_area, pressure)`.
- **Effect:**
  - Cycle mode only refills below 0.05 atm, which is always under the 20 kPa hazard minimum. The early return always fires first, so Cycle mode siphons the room to vacuum and never refills it.
  - The alarm light never turns red for a pressure or temperature hazard (spacing, fire).

## ALARM-3: Gas consumed in a breath counts as "lost" (medium, verified)

- **Fixed in:** [`atmos/lungs`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/lungs)
- **Location:** `code/modules/surgery/organs/internal/lungs/_lungs.dm:723-731`
- **What's wrong:** `if(breath_moles[gas_id]) continue`. `breathe_gas_volume` has already zeroed that gas in the same breath, so `on_loss` runs on every breath the gas is present. This regressed in #96448; the old check tested the gas list entry, which stayed truthy at 0 moles.
- **Effect:**
  - Helium: `lose_helium` unregisters the say hook in the same breath that registers it, so the small voice never works.
  - Healium: `lose_healium` resets `healium_euphoria` every breath, so the mood never applies.
  - Miasma: the smell mood is cleared in the same breath that adds it.

## ALARM-4: Vent "Reset external pressure" sets 50 atm instead of 1 atm (medium, verified)

- **Fixed in:** [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm)
- **Location:** `code/modules/atmospherics/machinery/air_alarm/_air_alarm.dm:455-459`
- **What's wrong:** `vent.external_pressure_bound = ATMOS_PUMP_MAX_PRESSURE`. The vent default and the UI's `extdefault` (line 328) are both `ONE_ATMOSPHERE`. The log line also says "internal".
- **Effect:** set a vent's external target to 90 kPa and press Reset. The vent then pumps the room toward 5066 kPa.

## ALARM-5: Air alarm AI wire is inverted (medium, verified)

- **Fixed in:** [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm)
- **Location:** `code/datums/wires/airalarm.dm:66`
- **What's wrong:** `A.aidisabled = mend`. The APC uses `!mend` (`code/datums/wires/apc.dm:87`).
- **Effect:** cutting the AI wire turns AI control back on, and mending it locks the AI out.

## ALARM-6: Circuit "External Pressure" input writes the internal bound (medium, confirmed)

- **Fixed in:** [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm)
- **Location:** `code/modules/atmospherics/machinery/air_alarm/air_alarm_circuit.dm:654`
- **What's wrong:** `set_external_pressure_async` does `vent.internal_pressure_bound = clamp(external_pressure.value, ...)`.

## ALARM-7: Circuit scrubber "Siphoning" output is inverted (low, confirmed)

- **Fixed in:** [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm)
- **Location:** `code/modules/atmospherics/machinery/air_alarm/air_alarm_circuit.dm:437`
- **What's wrong:** `is_siphoning.set_value(scrubber.scrubbing == ATMOS_DIRECTION_SCRUBBING)`.

## ALARM-8: Monitor-only atmos consoles still accept control actions (low/medium, confirmed, crafted act)

- **Fixed in:** [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc)
- **Location:** `code/game/machinery/computer/atmos_computers/_atmos_control.dm:155-156`
- **What's wrong:** the guard is `if(. || !(control || reconnecting)) return`, and the toggle and adjust branches never check `control`. TGUI only hides the buttons.
- **Effect:** on a monitor-only console such as the incinerator monitor, a crafted `toggle_input`, `adjust_input` or `adjust_output` still retunes the chamber.

## ALARM-9: Firelock frame RCD circuit check compares against an upgrade flag (low, confirmed)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes)
- **Location:** `code/game/machinery/doors/firedoor.dm:967`
- **What's wrong:** `switch(rcd_data[RCD_DESIGN_MODE])` has `if(RCD_UPGRADE_SIMPLE_CIRCUITS)`. That value (1<<1) equals `RCD_WINDOWGRILLE`, not `RCD_WALLFRAME`.
- **Effect:** the circuit only installs when the RCD is in window/grille mode.

## ALARM-10: Atmos alert console icon doesn't switch between minor and priority (low, confirmed)

- **Fixed in:** [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc)
- **Location:** `code/game/machinery/computer/atmos_alert.dm:90`
- **What's wrong:** the icon only updates when the alarm list goes from empty to non-empty or back.
- **Effect:** if the only alarm escalates from warning to hazard, the icon stays on the warning state.

## ALARM-11: Circuit-driven scrubber changes don't re-register atmos processing (low, plausible)

- **Fixed in:** [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm)
- **Location:** `code/modules/atmospherics/machinery/air_alarm/air_alarm_circuit.dm:379, 394, 424`
- **What's wrong:** these set `filter_types`, `on` and `scrubbing` directly, without calling `atmos_conditions_changed()`.

## ALARM-12: Firelock generic alarm clears while hot turfs remain (low, plausible)

- **Fixed in:** not fixed: it's unclear whether the current behaviour is intended
- **Location:** `code/game/machinery/doors/firedoor.dm:311-317`
- **What's wrong:** `if(length(issue_turfs) && alarm_type != FIRELOCK_ALARM_TYPE_GENERIC) return`. When the alarm is GENERIC, any benign exposure falls through to `start_deactivation_process()` even though there are still issue turfs.
- **Effect:** after a pulled fire alarm with a fire next to the firelock, the firelock flaps open and shut.

## ALARM-13: The atmos_requirements debug trace uses the wrong keys (low, confirmed)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes)
- **Location:** `code/datums/elements/atmos_requirements.dm:102`
- **What's wrong:** it reads `gases["o2"]` and `gases["plasma"]`, but the keys are `"oxy"` and `"plas"`.
- **Effect:** the stack trace prints blank O2 and plasma values.

## ALARM-14: Minor air alarm runtimes (low, confirmed)

- **Fixed in:** [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm)
- **Location:** `code/modules/atmospherics/machinery/air_alarm/_air_alarm.dm`
- **What's wrong:**
  - Lines 387-388: the "power" action with a stale or unmatched ref dereferences a null `powering`.
  - Line 749: `disconnect_sensor` with no sensor connected reads `null.loc`.
  - Line 486: `set_threshold` stores `params["value"]` with no type or range check.

## Checked, nothing solid

- Air alarm: `air_alarm_modes.dm` (apart from the Cycle path above) and the threshold logic in `air_alarm_thresholds.dm`.
- Atmos consoles: sensor linking in `_air_sensor.dm`, and `inlets.dm`, `outlets.dm`, `meters.dm`.
- Field generators: `atmos_field_gen.dm` and `atmosshieldgen.dm`.
- `atmos_sensitive.dm`.
- Firelocks: merging, hold-open, and alarm source tracking.
