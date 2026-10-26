# Pumps, valves, filters, mixers, vents and scrubbers

Paths are relative to `code/modules/atmospherics/machinery/components/`.

## DEV-1: Gas mixer runs with no power or while broken (medium, verified)

- **Fixed in:** [`atmos/device-power-checks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/device-power-checks)
- **Location:** `trinary_devices/mixer.dm:67`
- **What's wrong:** `if(!on || !(nodes[1] && nodes[2] && nodes[3]) && !is_operational)` parses as `!on || (!(all nodes) && !is_operational)`. The filter's version of this check (`filter.dm:59`) is correct.
- **Effect:** with all three nodes connected, a mixer that is switched on keeps mixing after its APC dies or after it breaks, while its sprite shows "off". It also works the other way: a powered mixer with a missing node keeps filling its internal output buffer.

## DEV-2: Closed valves are ventcrawlable until opened once (medium, verified)

- **Fixed in:** [`atmos/ventcrawl`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ventcrawl)
- **Location:** `binary_devices/valve.dm`, which has no `vent_movement` override and no Initialize. The flag is only set in `set_open()`, at lines 49 and 53.
- **What's wrong:** valves start closed (`on = FALSE`), but they inherit the base `vent_movement = VENTCRAWL_ALLOWED | VENTCRAWL_CAN_SEE` (`atmosmachinery.dm:66`). They also have no `relaymove` check, unlike `passive_gate` and `pressure_valve`.
- **Effect:** any closed valve that was mapped or newly wrenched lets ventcrawlers through until someone opens and closes it.

## DEV-3: Overclocked vent pumps are deleted at 0 integrity (medium, confirmed / plausibly unintended)

- **Fixed in:** [`atmos/vents-scrubbers`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/vents-scrubbers)
- **Location:** `unary_devices/vent_pump.dm:253-257`. Related code: examine text at line 94, the "broken" overlay at 182, `toggle_overclock(from_break)` at 226, and the screwdriver repair.
- **What's wrong:** `take_damage(fan_damage_rate, ...)` is applied with `integrity_failure = 0`. At 0 integrity, `atom_destruction` calls `deconstruct(FALSE)` and the vent is deleted. That leaves all the "fan is broken" handling unreachable. PR #78583 says reaching 0 integrity "will still disable them".
- **Effect:** an overclocked vent disappears after about 200 atmos ticks and leaves a pipe fitting behind.

## DEV-4: ~~Passive vent on space writes gas into the shared space mixture~~ (NOT A BUG)

- **Fixed in:** nothing to fix (not a bug)

> **Not a bug.** `equalize()` does call `other.garbage_collect()` on its last line (`gas_mixture.dm:301`). On the immutable space mixture, that clears the moles and resets the temperature. A temporary test that vented 100 mol through a passive vent onto space left the space turf at 0 mol. The original claim is kept below for reference.

- **Location:** `unary_devices/passive_vent.dm:36` (`internal.equalize(external)`), with `gas_mixture.dm:276-300`
- **What's wrong:** `equalize()` writes moles and temperature straight into `other`, then calls `garbage_collect()` only on `src`. On space, `other` is the single static `space_gas` immutable mixture, and the immutable type doesn't override `equalize`.
- **Effect:** about 92% of the vented moles land in `space_gas`. Another passive vent to space can then pull them into its own pipes, and space turfs report non-zero pressure until something resets it.

## DEV-5: Dual-port vent pump ignores power (low-medium, confirmed)

- **Fixed in:** [`atmos/device-power-checks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/device-power-checks)
- **Location:** `binary_devices/dp_vent_pump.dm:41`
- **What's wrong:** `process_atmos` only checks `if(!on) return`, with no `is_operational` check. The icon shows `vent_off` when it isn't operational.
- **Effect:** the incinerator's dual-port vents keep pumping with the APC off.

## DEV-6: Temperature gate clamp has its arguments in the wrong order (style only, NOT A BUG in behaviour)

- **Fixed in:** nothing to fix (no visible effect)

> **No visible effect.** Setting 10000 K through the UI still stored a target at or below 4500 K. `clamp(2.7, T, 4500)` gives the same result as `clamp(T, 2.7, 4500)` for every T. The argument order is wrong, but nothing a player sees changes, so there is no test.

- **Location:** `binary_devices/temperature_gate.dm:274`: `clamp(minimum_temperature, temperature, max_temperature)`
- **Effect:** for values above `max_temperature`, the lower bound is above the upper bound, so the result depends on how BYOND's `clamp` handles that, and the value may not be clamped. The value can only get that high from a crafted `ui_act`.

## DEV-7: Pressure gate and passive gate maximums are inconsistent (low, confirmed)

- **Fixed in:** [`atmos/gates`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gates)
- **Location:** `binary_devices/pressure_valve.dm:36-39, 91, 106, 112`; `passive_gate.dm` `ui_act`
- **What's wrong:**
  - **Pressure gate:** the UI and server maximum is `ONE_ATMOSPHERE*100` (10132.5 kPa), but alt-click "maximize" sets and compares against `MAX_OUTPUT_PRESSURE` (4500 kPa).
  - **Passive gate:** it sends `max_pressure = MAX_OUTPUT_PRESSURE` to the UI, but the server clamps to 10132.5.

## DEV-8: Scrubber power usage is wrong or stale (low, confirmed)

- **Fixed in:** [`atmos/vents-scrubbers`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/vents-scrubbers)
- **Location:** `unary_devices/vent_scrubber.dm:105-119, 147, 157-158`
- **What's wrong:**
  - `active_power_usage = initial(idle_power_usage)` is a typo, so siphon mode uses the idle figure.
  - The widenet surcharge uses `length(adjacent_turfs)`, which is still empty when `set_widenet(TRUE)` runs.
  - `toggle_filters` and `remove_filters` never call `update_power_usage()`.

## DEV-9: Pressure and temperature gates stay on the flowing sprite (low, cosmetic, confirmed)

- **Fixed in:** [`atmos/gates`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gates)
- **Location:** `binary_devices/pressure_valve.dm:68-73`, `binary_devices/temperature_gate.dm:221-234`
- **What's wrong:** `is_gas_flowing` is set when `release_gas_to` succeeds, but not reset when the condition still holds and `release_gas_to` returns FALSE.

## DEV-10: Mixer node concentrations are not clamped (low, confirmed)

- **Fixed in:** [`atmos/device-power-checks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/device-power-checks)
- **Location:** `trinary_devices/mixer.dm:171-185`
- **What's wrong:** `text2num(params["concentration"])` goes into `adjust_node1_value` with no 0-100 clamp.
- **Effect:** a crafted value of 150 gives node1 = 1.5 and node2 = -0.5. The `<= 0` check in `process_atmos` then always returns early, so the mixer silently stops working.

## Minor

- **Volume pump:** because of `||`/`&&` precedence, overclocking bypasses only the output limit, not the 0.01 kPa input minimum. Negligible.
- **Outlet injector:** `click_ctrl` returns SUCCESS and BLOCKING the wrong way round. Both satisfy `CLICK_ACTION_ANY`, so this has no effect.

## Checked, nothing solid

`pump`, `volume_pump`, `passive_gate` processing, `temperature_pump`, `circulator`, `filter`, `heat_exchanger`, `portables_connector`, `machine_connector`, `pump_gas_to` and `release_gas_to`.
