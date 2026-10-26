# Hypertorus Fusion Reactor (HFR)

Files: `code/modules/atmospherics/machinery/components/fusion/`. Paths below are relative to that folder.

Nothing solid was found in `_hfr_defines.dm` or `hfr_fuel_datums.dm`. Every recipe has 2 requirements, at least 1 primary product and 6 secondary products, so the index reads in `fusion_process` are safe.

## HFR-1: Moderator gas that should be consumed is added instead (high, verified)

- **Fixed in:** [`atmos/hfr-moderator`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-moderator)
- **Location:** `hfr_main_processes.dm:294, 297, 301, 306, 311, 318, 329, 336`, in `moderator_common_process`.
- **What's wrong:** at power levels 1 to 5, the lines meant to consume moderator gas call `adjust_gas` with a positive amount, for example:
  `moderator_internal.adjust_gas(/datum/gas/plasma, min(moderator_internal.moles[/datum/gas/plasma], scaled_production * 0.85))`
  `adjust_gas` does `moles[gas] += amount`.
  - Before e98cb75c570 (#95327) these lines were `...[MOLES] -= min(...)`, and the minus sign was lost in the conversion.
  - The level 6 and healium lines kept `-min(...)`.
- **Effect:** at fusion level 1 to 5 with more than 100 mol plasma in the moderator (or the BZ / proto-nitrate thresholds), the HFR makes its N2O, BZ, nitrium, halon or pluoxium and also adds the same amount of plasma, BZ or proto-nitrate. This is unlimited free gas. The moderator grows toward the 10000 mol crack/spill threshold.

## HFR-2: Part references are never cleared (medium, confirmed)

- **Fixed in:** [`atmos/hfr-part-linking`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-part-linking)
- **Location:** `hfr_procs.dm:9-78` (`check_part_connectivity`), `hfr_procs.dm:137-163` (`deactivate`), `hfr_parts.dm:153-163`, `hfr_core.dm:179-197`.
- **What's wrong:**
  - (a) `machine_parts |= object` is never reset. `deactivate()` clears the `linked_*` vars and `corners`, but not `machine_parts`.
  - (b) `check_part_connectivity()` sets `linked_*` and does `corners |= object` even when it returns FALSE. `deactivate()` starts with `if(!active) return`, so after a failed multitool on a reactor that was never activated, nothing is cleared.
  - (c) `interface.connected_core` is only nulled in the interface's own `Destroy`, not in `deactivate()`.
  - (d) The core's `Destroy` runs `QDEL_NULL` on whatever `linked_*` and `corners` it still holds.
- **Effect:**
  - Activate, open a part's panel (the next atmos tick deactivates), then deconstruct that part. The core's `machine_parts` still holds the part: a hard delete. After a rebuild, `create_crack()` can `pick()` the deleted part:
    - `spill_gases` returns early because `origin.loc` is null.
    - The explosion uses a nullspace origin.
    - `check_cracked_parts()` returns the deleted part from then on, so the moderator never leaks and nothing can be welded.
  - Multitool the interface while a part is misplaced (the check fails), then rebuild a part that got linked:
    - The core holds the deleted part.
    - `linked_input && linked_input != object` (or `corners.len != 4`) fails forever, so the core can never activate again.
  - In the same state, deconstructing the core deletes the neighbouring parts it linked, without dropping their boards.
  - Activate, deactivate, then deconstruct the core. The interface's `connected_core` is a hard delete.

## HFR-3: `ui_act` doesn't enforce the power-level locks the UI shows (medium, confirmed, needs a crafted act)

- **Fixed in:** [`atmos/hfr-meltdown`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-meltdown)
- **Location:** `hfr_parts.dm:309-321, 358-374`; `hfr_procs.dm:411-413, 456`.
- **What's wrong:**
  - TGUI disables `start_power`, recipe selection and turning cooling off while `power_level > 0` (`tgui/.../Hypertorus/index.tsx:70, 84, 96`). The server checks none of this.
  - `countdown()` sets `final_countdown = TRUE` before it reads `selected_fuel.meltdown_flags`.
  - `meltdown()` reads `selected_fuel.meltdown_flags` with no null check.
- **Effect:**
  - During the meltdown countdown, `act('fuel', {mode: ""})` sets `selected_fuel` to null, so `meltdown()` runtimes before `explosion()`. `final_countdown` stays TRUE, `countdown()` returns early from then on, and the HFR never explodes.
  - `start_power` off at level 6 switches to `IDLE_POWER_USE` while `fusion_process` keeps running (because of `|| power_level`), so the 50-350 kW draw is skipped.

## HFR-4: Meltdown EMP light range uses the heavy size (low/medium, verified)

- **Fixed in:** [`atmos/hfr-meltdown`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-meltdown)
- **Location:** `hfr_procs.dm:562`: `light_range = critical ? emp_light_size * 2 : emp_heavy_size`.
- **Effect:** the non-critical branch should use `emp_light_size`, so every non-critical recipe's EMP is smaller than intended:
  - MEDIUM_SPREAD recipes (H2+O2, H2+Trit) get a light range of 3×power_level instead of 5×.
  - BIG_SPREAD recipes (hyper-noblium) get 5× instead of 7×.

## HFR-5: Signals stay registered after `process_atmos` deactivates (low, confirmed)

- **Fixed in:** [`atmos/hfr-part-linking`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-part-linking)
- **Location:** `hfr_main_processes.dm:16-18`, `hfr_procs.dm:95-108`.
- **What's wrong:** `process_atmos` calls `deactivate()` directly, not `unregister_signals()`, so the `COMSIG_QDELETING` registrations on all 8 parts remain. `activate()` then calls `RegisterSignal` again without `override`.
- **Effect:** activate, open and close a part's panel, then multitool again. You get a "signal overridden" `stack_trace` for each part.

## HFR-6: Clicking an inactive interface runtimes (low, confirmed)

- **Fixed in:** [`atmos/hfr-part-linking`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-part-linking)
- **Location:** `hfr_parts.dm:176-178`.
- **What's wrong:** the `else` branch calls `ui.close()`, but on a first open `ui` is null.
- **Effect:** clicking an HFR interface that isn't activated shows the chat message, then a `null.close()` runtime.

## HFR-7: `ui_act` after deactivation runtimes (low, confirmed)

- **Fixed in:** [`atmos/hfr-part-linking`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-part-linking)
- **Location:** `hfr_parts.dm:367-372`.
- **What's wrong:** machinery `can_interact` doesn't check `active`, so an open UI keeps working after `deactivate()` nulls `linked_input`, `linked_output` and `linked_moderator`. The `fuel` action then calls `dump_gases()` (which reads `linked_output.airs[1]`) or `connected_core.linked_input.update_parents()`.
- **Effect:** with the UI open, someone opens a part's panel. Picking a recipe then runtimes on a null.

## HFR-8: Meltdown deletes about a third of the pocketed gas (low, confirmed)

- **Fixed in:** [`atmos/hfr-meltdown`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-meltdown)
- **Location:** `hfr_procs.dm:522-538`.
- **What's wrong:** `remove = remove_fusion.remove_ratio(1/gas_pockets)` is taken from a shrinking remainder, and what's left of `remove_fusion` / `remove_moderator` is never released.
- **Effect:** the leftover is (1-1/n)^n of the gas: 32.8% at n=5 and 35.6% at n=15. That leftover is deleted, which works out to about 6.5-7% of all fusion and moderator moles lost per meltdown.

## HFR-9: Cold-coolant heal formula doesn't match its defines (low, confirmed math)

- **Fixed in:** [`atmos/hfr-meltdown`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-meltdown)
- **Location:** `hfr_main_processes.dm:434`.
- **What's wrong:** `log(10, max(coolant_temperature, 1) * HYPERTORUS_COLD_COOLANT_SCALE) - (HYPERTORUS_COLD_COOLANT_MAX_RESTORE * 2)` puts the scale inside the log and doubles the max. The defines describe at most 2.5/s at 1 K, falling to 0 at 1e5 K (SCALE = 2.5/5 = 0.5).
- **Effect:**
  - At 1 K: `log10(0.5) - 5 = -5.3`, so it heals 5.3/s, more than double the maximum.
  - At 99,999 K it still heals 0.3/s, then drops straight to 0 above the threshold.
  - The intended formula, `log10(T)*SCALE - MAX`, gives 2.5 at 1 K and 0 at the threshold.
  - This has been there since fbd22878ad5 (2021).

## HFR-10: Deleting a part never shuts the reactor down (medium, verified; found while writing tests)

- **Fixed in:** [`atmos/hfr-part-linking`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-part-linking)
- **Location:** `hfr_procs.dm:95-108` (the registrations) and `hfr_procs.dm:118` (`unregister_signals(only_signals = FALSE)`).
- **What's wrong:** `unregister_signals` is the `COMSIG_QDELETING` handler for every part. The signal passes `source` as the first argument, so it lands in `only_signals`. That value is never false, so `deactivate()` is never called.
- **Effect:** when a part of a running reactor is deconstructed or destroyed:
  - The core stays active, still holding the deleted part.
  - The other parts keep showing as active.
  - Everything only shuts down when the next atmos tick fails the connectivity check.
  - This makes HFR-2 easier to hit: for instance, re-linking before that tick finds the core still "active" with a dead `linked_input`.

## Checked, not bugs

The countdown loop, `check_alert` delays, the power-level `switch`, overfull/hypercritical damage, the damage cap, the `remove_waste` divisor, the heat-transfer divisions, the `dirty_production_rate` index and the `ui_act` numeric clamps.
