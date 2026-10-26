# Portable atmos, tanks and measurement

Covers canisters, portable pumps and scrubbers, gas tanks, jetpacks, analyzers, meters, miners, grenades and the AtmoZphere app.

## PORT-1: Explosions release a portable machine's gas twice (high, verified)

- **Fixed in:** [`atmos/portable-gas-release`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/portable-gas-release)
- **Location:** `code/modules/atmospherics/machinery/portable/portable_atmospherics.dm:97-100`, plus `canister.dm:494-498`, `pump.dm:15-17`, `scrubber.dm:35-37` and `bluespace_scrubber.dm:92-94`
- **What's wrong:** `ex_act` calls `local_turf.assume_air(air_contents)`, which uses `merge()` and leaves `air_contents` full. Then `..()` → `take_damage(INFINITY)` → break or destroy releases `air_contents` again:
  - Canisters do it through `canister_break`.
  - Pumps and scrubbers do it through `on_deconstruction`.
- **Effect:** a portable machine in devastation range, or that is the explosion's target, puts double its gas onto the turf.

## PORT-2: The pipe scrubber's `atom_deconstruct` never runs (medium, confirmed)

- **Fixed in:** [`atmos/portable-gas-release`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/portable-gas-release)
- **Location:** `code/modules/atmospherics/machinery/portable/pipe_scrubber.dm:40-46`, with `code/game/machinery/_machinery.dm:925-960`
- **What's wrong:** `/obj/machinery/handle_deconstruct` is `SHOULD_NOT_OVERRIDE`. It calls `on_deconstruction()` and then `dump_contents()`, and never `atom_deconstruct()`, so the override is dead code.
- **Effect:** destroying the scrubber, or breaking its internal tank, drops `internal_tank` as a full, usable canister. The scrubber's own 200 L of gas is deleted.

## PORT-3: Gas from a tank that leaks or ruptures while held or worn is deleted (medium, verified)

- **Fixed in:** [`atmos/gas-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gas-tanks)
- **Location:** `code/game/objects/items/tanks/tanks.dm:182-186, 341-345`
- **What's wrong:** both paths call `loc.assume_air(...)`. When `loc` is a mob, that is `/atom/assume_air`, which returns null. Storage items pass the call up to the mob, so it ends the same way.
- **Effect:**
  - A leaking tank on someone's back loses its gas without it reaching the air.
  - A plasma tank that ruptures in someone's hand releases nothing.

## PORT-4: An external tank's `Destroy` leaves its breather pointing at the deleted tank (low-medium, confirmed)

- **Fixed in:** [`atmos/gas-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gas-tanks)
- **Location:** `code/game/objects/items/tanks/tanks.dm:135-140`; `code/game/objects/structures/tables_racks.dm:938-943`
- **What's wrong:** the tank's `Destroy` never closes `breathing_mob`'s internals. For an external tank, such as the operating table's, nothing clears `carbon.external`.
- **Effect:** a hard-delete reference, and the patient suffocates on internals that still show as active.

## PORT-5: Canister deconstruction loses the hypernoblium crystal (low, confirmed)

- **Fixed in:** [`atmos/portable-gas-release`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/portable-gas-release)
- **Location:** `code/modules/atmospherics/machinery/portable/canister.dm:418-427`
- **What's wrong:** the canister's `on_deconstruction` doesn't call `..()`, and the base proc is the one that spawns the crystal.

## PORT-6: `canister_break` doesn't unregister the holding tank's signal (low, confirmed)

- **Fixed in:** [`atmos/portable-gas-release`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/portable-gas-release)
- **Location:** `code/modules/atmospherics/machinery/portable/canister.dm:506-508`
- **What's wrong:** it does `holding.forceMove(T); holding = null` without `UnregisterSignal(holding, COMSIG_QDELETING)`.
- **Effect:** a stale listener on the broken canister.

## PORT-7: The captain's jetpack ignores stabilization toggles while it is on (low, confirmed)

- **Fixed in:** [`atmos/gas-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gas-tanks)
- **Location:** `code/game/objects/items/tanks/jetpack.dm:57`
- **What's wrong:** `user.get_item_by_slot(slot_flags) == src` is passed the combined `ITEM_SLOT_BACK | ITEM_SLOT_SUITSTORE`, which `get_item_by_slot` doesn't match, so it returns null.
- **Effect:** after toggling stabilization on, the captain keeps `TRAIT_NOGRAV_ALWAYS_DRIFT`.

## PORT-8: The gas miner's `power_draw` modes do nothing (low, confirmed)

- **Fixed in:** [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc)
- **Location:** `code/modules/atmospherics/machinery/other/miner.dm:83-99`
- **What's wrong:**
  - `update_use_power(ACTIVE_POWER_USE, <amount>)` is passed an amount, but the proc only takes one argument.
  - `if(!active) active_power_usage = idle_power_usage` overwrites the active value permanently.

## PORT-9: The atmos meter circuit can runtime on a missing target or air (low, plausible)

- **Fixed in:** [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc)
- **Location:** `code/modules/atmospherics/machinery/other/meter.dm:231-233`
- **What's wrong:** `connected_meter.target.return_air()`, then `environment.return_pressure()`, with no null checks.

## PORT-10: AtmoZphere's right-click scan stays registered after the app closes (low, confirmed)

- **Fixed in:** [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc)
- **Location:** `code/modules/modular_computers/file_system/programs/atmosscan.dm:81`
- **What's wrong:** `COMSIG_ITEM_ATTACK_SELF_SECONDARY` is only unregistered when switching back to env mode. There is no `kill_program` override.

## PORT-11: Minor tank and analyzer issues (low, confirmed)

- **Fixed in:** [`atmos/gas-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gas-tanks) (tank leak message) and [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc) (analyzers)
- `tanks.dm:381`: `if(atom_integrity < 0)` can never be true, because integrity is clamped to 0. The leak message and spray sound play even on the hit that ruptures the tank.
- `gas_analyzer.dm:51-57`: every analyzer adds and removes `TRAIT_DETECT_STORM` under the same source. Dropping one of two analyzers removes the trait.

## Borderline, probably intended

- The portable pump's `emp_act` sets a target pressure above `PUMP_MAX_PRESSURE`.
- Welder-deconstructing a canister empties it before `COMSIG_ATOM_BREAK`, so the `volatile_gas_storage` explosion never fires on that path.
- `canister_break` → `atom_break()` → `canister_break` recurses once on the welder path. The only effect is duplicate logs, sound and animation.

## Checked, nothing solid

- **Canisters:** the holding tank swap and the port connect/disconnect logic.
- **`ui_act`:** the pressure clamps, and that tgui action names match.
- **Other items:** jetpack fuel use, meter bands, bluespace scrubber links, `tank_types.dm`, `watertank.dm` and `atmos_grenades.dm`.
