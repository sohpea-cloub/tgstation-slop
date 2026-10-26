# Large atmos machines

Covers the thermomachine, cryo, airlock pump, pressure tanks, electrolyzer and crystallizer.

Paths are relative to `code/modules/atmospherics/machinery/components/` unless they say otherwise.

## MACH-1: Cutting open a merged pressure tank duplicates the group's gas (high, verified)

- **Fixed in:** [`atmos/pressure-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pressure-tanks)
- **Location:** `tank.dm:423-426`
- **What's wrong:** `on_deconstruction` runs `location.assume_air(air_contents)`.
  - For a tank in a merger group, `air_contents` is the single mix that the whole group shares.
  - `/turf/open/assume_air` calls `air.merge(giver)`, and `merge()` copies moles without emptying the giver (`gasmixtures/gas_mixture.dm:157`).
- **Effect:** build 3 or more adjacent tanks, fill them, then weld-cut one (`welder_act_secondary` → `deconstruct`) or destroy it.
  - The tile gets the entire group's gas, and the remaining tanks keep all of it too.
  - The duplication is repeatable.

## MACH-2: Pressure tank groups re-merge the shared mix once per tank (high, verified)

- **Fixed in:** [`atmos/pressure-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pressure-tanks)
- **Location:** `tank.dm:284-292`
- **What's wrong:**
  - In `merger_refresh_complete`, the origin runs `air_contents.merge(joiner.air_contents)` for every joiner. Joiners from another group all point at the same mix object, so that mix gets merged N times. If it is already the origin's own mix, it gets merged into itself.
- **Effect:** build two separate groups of 2 or more tanks each, then build a tank that bridges them. The second group's origin merges the first group's mix once per tank in it.
  - Another way to trigger it: remove a tank from a group of 3, then build next to the leftovers.
  - Pipenet reconciliation calling `GetMergeGroup` triggers it too.
  - Either way, gas is multiplied.

## MACH-3: Airlock pump stays on forever if an airlock is destroyed mid-cycle (medium, confirmed)

- **Fixed in:** [`atmos/airlock-pump`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/airlock-pump)
- **Location:** `unary_devices/airlock_pump.dm:570-593, 366`
- **What's wrong:**
  - `unlink_airlock` calls `break_all_links()` once one side has no airlocks left. That proc deletes `emergency_stop_timer` and empties both lists, but never calls `set_on(FALSE)`.
  - If the target pressure is ever reached, `stop_cycle` runs `unlocked_airlocks[1].say(message)` on an empty list.
- **Effect:** during a pressurization cycle, destroy the only external airlock.
  - The chamber is open to space, so it never reaches the target pressure.
  - With the timeout gone, the pump vents distro air into space every tick.
  - Mapped pumps can't be unwrenched, and `can_unwrench` refuses while the pump is on.

## MACH-4: ~~Airlock pump sleeps inside `process_atmos`, stalling SSair~~ (NOT A BUG)

- **Fixed in:** nothing to fix (not a bug)

> **Not a bug.** The base `/obj/machinery/proc/process_atmos` has `set waitfor = FALSE` (`code/game/machinery/_machinery.dm:323`), and overrides inherit it. When `stop_cycle` sleeps, `process_atmos` returns to SSair straight away. A test confirmed this: the call that finished a cycle returned with `world.time` unchanged. The audit (and my "verified" mark) had only checked `stop_cycle`. The original claim is kept below.

- **Location:** `unary_devices/airlock_pump.dm:188, 205, 217` → `stop_cycle` at 362 (`stoplag(1 SECONDS)`)
- **What's wrong:** `process_atmos` calls `stop_cycle`, which sleeps, and there is no `waitfor = FALSE`. `SSair.fire` therefore sleeps too, and the MC marks it `SS_SLEEPING`.
- **Effect:** each time any airlock pump finishes a cycle, all atmos processing (machinery, pipenets, active turfs) pauses for at least 1 second.

## MACH-5: Electrolyzer runs forever for free on a nearly empty cell (medium, confirmed)

- **Fixed in:** [`atmos/electrolyzer-crystallizer`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/electrolyzer-crystallizer)
- **Location:** `electrolyzer/electrolyzer.dm:96, 130`
- **What's wrong:** the shutoff check is `cell.charge <= 0`, but `cell.use(power_to_use)` is called without `force`. When the charge is below the cost, `use` returns 0 and drains nothing.
- **Effect:** with T1 parts the cost is about 17.14 J per tick. A 10 kJ cell is left with about 5.7 J that can never be drained. From then on the unanchored electrolyzer runs indefinitely.

## MACH-6: Anchored electrolyzer works without area power (medium, confirmed)

- **Fixed in:** [`atmos/electrolyzer-crystallizer`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/electrolyzer-crystallizer)
- **Location:** `electrolyzer/electrolyzer.dm:16, 91, 127-128`
- **What's wrong:**
  - With `use_power = NO_POWER_USE`, `powered()` always returns TRUE, so the machine never gets `NOPOWER`.
  - The return value of `use_energy()` is ignored. It returns FALSE when there is no APC or the APC isn't operating.
- **Effect:** anchored in an area with a dead, broken or missing APC, it still makes H2 and O2 for free.

## MACH-7: Crystallizer `gas_input` treats "moles/s" as a fraction (medium, confirmed)

- **Fixed in:** [`atmos/electrolyzer-crystallizer`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/electrolyzer-crystallizer)
- **Location:** `gas_recipe_machines/crystallizer.dm:113, 327`
- **What's wrong:** the UI (`tgui/.../Crystallizer.tsx:85-90`) offers 0-250 "moles/s". The code runs `contents.remove_specific(gas_type, contents.moles[gas_type] * gas_input)`, which clamps to what is available.
- **Effect:** any value of 1 or more pulls 100% of that gas from the input network every tick, which blows past the 2x cap. The excess stays trapped until the recipe changes.

## MACH-8: Cryo cell runs and heals with no power (low-medium, confirmed)

- **Fixed in:** [`atmos/cryo`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cryo)
- **Location:** `unary_devices/cryo.dm:515-516, 645-652`
- **What's wrong:**
  - `close_machine` calls `set_on(TRUE)` without checking `is_operational`.
  - Drag-drop never calls `can_interact`.
  - Neither `process()` nor `process_atmos()` checks power.
- **Effect:** cut power, crowbar the cryo open, then drag an incapacitated patient in. It turns on, cools the patient and injects reagents.

## MACH-9: Crystallizer products can get a blank quality name (low, confirmed)

- **Fixed in:** [`atmos/electrolyzer-crystallizer`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/electrolyzer-crystallizer)
- **Location:** `gas_recipe_machines/crystallizer.dm:197-219`
- **What's wrong:** `total_quality` is fractional, but the quality `switch` has integer gaps (34-35, 54-55, 64-65, 74-75, 94-95, 99-100).
- **Effect:** a value like 54.5 matches nothing, so the item is named `" Hyper-Noblium crystal"` with no quality tag.

## MACH-10: Cryo drag-in of a conscious patient is unreachable (low, confirmed)

- **Fixed in:** [`atmos/cryo`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cryo)
- **Location:** `unary_devices/cryo.dm:646-657`
- **What's wrong:** after `if(!iscarbon(target)) return`, the `if(isliving(target)) { ... return }` check is always true, so the `do_after` "shoving inside" branch is dead code.
- **Effect:** dragging a conscious carbon onto the cryo does nothing and gives no feedback.

## MACH-11: Tank frame runtimes on stacks without a material (low, confirmed)

- **Fixed in:** not fixed (left out of `atmos/pressure-tanks` as unrelated)
- **Location:** `tank.dm:618-621`
- **What's wrong:** `if(!stack.material_type) balloon_alert(...)` has no `return`, so it goes on to `SSmaterials.get_material(null)`, which CRASHes.
- **Effect:** using cable coil on a bare tank frame runtimes on every click.

## MACH-12: Thermomachine ctrl-click leaves the wrong power mode (NOT A BUG in practice)

- **Fixed in:** nothing to fix (no visible effect)

> **No visible effect.** Thermomachines inherit `idle_power_usage = 0` and `active_power_usage = 0` (`atmosmachinery.dm:16-17`). Their real cost is drawn in `process_atmos` only while they are on, so the wrong `use_power` mode changes no power draw. The area's static load measured 0 either way. The original claim is kept below.

- **Location:** `unary_devices/thermomachine.dm:196, 349`
- **What's wrong:** `click_ctrl` and the not-operational shutoff call `set_on()` without `update_use_power()`.
- **Effect:** turn it on through the UI, then ctrl-click it off. It keeps drawing `ACTIVE_POWER_USE` while off.

## MACH-13: Airlocks keep a stale pump link after `break_all_links` (low, confirmed)

- **Fixed in:** [`atmos/airlock-pump`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/airlock-pump)
- **Location:** `unary_devices/airlock_pump.dm:585-593`
- **What's wrong:** `break_all_links` never clears `airlock.cycle_pump`, and `is_valid_airlock` rejects any airlock that has one.
- **Effect:** after one side's airlock is destroyed, the surviving airlocks can't be linked to a new pump.

## MACH-14: Prying open an unpowered cryo cell runtimes (low-medium, verified; found while writing tests)

- **Fixed in:** [`atmos/cryo`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cryo)
- **Location:** `unary_devices/cryo.dm:293`: `if(!(default_pry_open(tool) & ITEM_INTERACT_SUCCESS))`
- **What's wrong:** `default_pry_open(mob/living/user, obj/item/crowbar, ...)` gets the crowbar as `user`, and `crowbar` is left null. It then reads `crowbar.tool_behaviour` (`_machinery.dm:882`).
- **Effect:** a crowbar on a closed, unpowered cryo cell runtimes and never opens it. That is the documented way to get someone out of a cryo cell during a power outage.

## Checked, nothing solid

- **Thermomachine:** heat math, part-tier ranges and `ui_act` clamping.
- **Electrolyzer:** reaction conservation.
- **Crystallizer:** recipe totals (no log(0) or divide by zero). `crystallizer_items.dm` had nothing either.
- **Cryo:** heat exchange can overshoot by up to 1.3x with T4 bins, but it still converges.
- **Not traced:** whether a cryo occupant's traits are cleaned up when the cell is destroyed without being deconstructed.
