# Core turf simulation (SSair, LINDA, fire)

## CORE-1: Cordon turfs superconduct forever, and edge cordons break SSair (medium, plausible)

- **Fixed in:** [`atmos/cordon-superconduction`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cordon-superconduction)
- **Location:** `code/modules/atmospherics/environmental/LINDA_turf_tile.dm:654-659` (`/turf/consider_superconductivity`) and `:626-628` (`super_conduct`).
- **What's wrong:**
  - `/turf/cordon` (and any other non-open turf that doesn't override `consider_superconductivity`) keeps the base `thermal_conductivity = 0.05`. The base `consider_superconductivity` has no temperature check; it just does `SSair.active_super_conductivity |= src`.
  - `super_conduct` uses `get_step(src, direction)` without a null check (`if(!neighbor.thermal_conductivity)`).
  - `/turf/open/conductivity_directions` can return a direction off the map edge, because `!(null in atmos_adjacent_turfs)` is true.
- **Effect:**
  - A hot open turf (over 693 K) next to a cordon seeds it.
  - In `super_conduct`, the cordon re-adds its cordon neighbours, then removes itself in `finish_superconduction` (293 K < 373 K). The neighbours add it back on the next tick, so the wave never stops.
  - The Academy, museum, moonoutpost19 and undergroundoutpost45 away missions each have 37k-61k cordon tiles; the museum has 142 next to open floor. Turf reservations also have cordon rings.
  - Once the wave reaches an edge cordon, `get_step` returns null and the proc runtimes before `finish_superconduction`. That turf is never removed and runtimes on every fire. Each runtime aborts the rest of the superconductivity pass, so `SSAIR_PROCESS_ATOMS` never runs again.
  - **Walls are not affected (checked while writing tests).**
    - `/turf/closed/wall` has `thermal_conductivity = WALL_HEAT_TRANSFER_COEFFICIENT`, which is 0 (`atmos_core.dm:119`), so walls never superconduct.
    - Closed turfs that do conduct (indestructible walls at 0.05, plasma walls at 0.04, rock) use `/turf/closed/consider_superconductivity`, which checks temperature.
    - A temporary test with a chain of walls passed.
    - The endless re-adding only affects turfs that are neither open nor closed, which in practice means `/turf/cordon`. A test confirmed two cordons taking turns re-adding each other on every pass.
  - **World-edge null check, confirmed by test:** a hot open floor at (1,1) runtimes with `Cannot read null.thermal_conductivity` (`LINDA_turf_tile.dm:628`).

## CORE-2: Possible null excited group in the end-of-cycle share with space (low-medium, plausible)

- **Fixed in:** not fixed: no way to reach it was found, and the right guard isn't obvious
- **Location:** `LINDA_turf_tile.dm:348-353`
- **What's wrong:** the `share_end` loop's `LAST_SHARE_CHECK` dereferences `our_excited_group`. `run_later` tiles go into `share_end` before the `current_cycle` skip, so nothing guarantees a group exists.
- **Effect:** a mid-`SSAIR_ACTIVETURFS` pause, followed by the group being garbage-collected (shuttle `KILL_EXCITED`, `remove_from_active`), causes a null runtime. The turf then skips `react()` that tick.

## CORE-3: Merging a displayed and an undisplayed excited group runtimes (low, admin debug only, confirmed)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes)
- **Location:** `LINDA_turf_tile.dm:448-450, 459-461`
- **What's wrong:** `merge_groups` calls `hide_turfs()` without checking `display_id`. `GLOB.colored_turfs[0]` is then out of bounds.

## CORE-4: `process_atmos_machinery` is missing a `continue` after its null check (low, verified)

- **Fixed in:** [`atmos/ssair-null-entries`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ssair-null-entries)
- **Location:** `code/controllers/subsystem/air.dm:326-328`
- **What's wrong:** `if(!M) atmos_machinery -= M` falls through to `M.process_atmos(...)`.
- **Effect:** a null in `atmos_machinery` (left by a hard-deleted machine) runtimes and aborts the machinery phase.

## CORE-5: `process_atoms` returns on a null entry and never removes it (low, verified)

- **Fixed in:** [`atmos/ssair-null-entries`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ssair-null-entries)
- **Location:** `code/controllers/subsystem/air.dm:312-313`
- **What's wrong:** `if(!talk_to) return`. The null is never removed from `atom_process`. `process_pipenets` and `process_hotspots` do remove theirs.
- **Effect:** every atom stored before the null is never processed again.

## CORE-6: Wrong sign in the end-of-cycle pressure difference (low, latent, confirmed)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes)
- **Location:** `LINDA_turf_tile.dm:359`
- **What's wrong:** in the `difference < 0` branch, the call is `enemy_tile.consider_pressure_difference(src, difference)`. The main loop (line 325) passes `-difference`.
- **Effect:** nothing today, because space is the only `run_later` turf and it always has `difference > 0`.

## CORE-7: Fire sound groups track z-levels incorrectly (low, confirmed)

- **Fixed in:** [`atmos/fire-sound`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/fire-sound)
- **Location:** `code/modules/atmospherics/environmental/LINDA_fire.dm:404-409, 440-442`
- **What's wrong:** `remove_from_group` doesn't remove `z_coord`, and `merge_hot_groups` doesn't merge it.
- **Effect:** in a multi-z fire, the sound can be centred on a z-level that isn't burning. `z_coord` also grows for the life of the group.

## CORE-8: Fire sound goes silent when its original turf changes (low, confirmed)

- **Fixed in:** [`atmos/fire-sound`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/fire-sound)
- **Location:** `LINDA_fire.dm:458-459`
- **What's wrong:** `update_sound` sets `sound.parent = sound_turf` directly instead of calling `set_parent()`. The `COMSIG_QDELETING` hook stays on the original turf.
- **Effect:** when that turf is changed (for example a floor melting), the parent is set to null and the fire's loop stops.

## Minor

- `code/__DEFINES/atmospherics/atmos_mob_interaction.dm`: the doc for `WARNING_HIGH_PRESSURE` says "0.7 * HAZARD_HIGH_PRESSURE", which would be 385, but the value is 325.
- `experience_pressure_difference` (`LINDA_turf_tile.dm:409`): the `&&`/`||` precedence is wrong, but this is dead code because the caller already filters out anchored atoms.

## Checked, nothing solid

- **LINDA_system.dm:** adjacency, `can_atmos_pass` and the `zAirIn`/`zAirOut` logic.
- **immutable_mixtures.dm:** `immutable/share` forcing the sharer's temperature looks intentional.
- **Defines and helpers:** `atmos_core.dm`, `atmos_helpers.dm` and `__HELPERS/atmospherics.dm`.
