# Unit tests per finding

The tests live on the fix branches, not on this branch. Each fix branch's first commit adds `code/modules/unit_tests/atmos_<group>.dm`, where the group is the branch name with dashes turned into underscores. Every test in that file is under `/datum/unit_test/atmos_<group>/`. Each file stands on its own, with its own copies of the helpers it needs. On `master` (`87b933384df`), every listed test fails because of the bug it covers, and the branch's second commit makes it pass.

**Legend:**
- **runtime:** the failure signal is the bug's own runtime, which fails the test.
- **skipped:** the finding has no test; the reason is given.
- **not a bug:** testing showed the finding was wrong.

## [`atmos/compare-early-exit`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/compare-early-exit) (`atmos_compare_early_exit.dm`)

| Finding | Test | Notes |
|---|---|---|
| GAS-1 relative threshold | `compare_large_mixtures` | |
| GAS-1 cmp_archive | `compare_uses_archive` | |

## [`atmos/share-energy`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/share-energy) (`atmos_share_energy.dm`)

| Finding | Test | Notes |
|---|---|---|
| GAS-2 | `share_conserves_energy` | 1,440,000 J goes to 1,438,800 J. |

## [`atmos/reaction-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/reaction-fixes) (`atmos_reaction_fixes.dm`)

| Finding | Test | Notes |
|---|---|---|
| GAS-3 | `antinoblium_cleanup_reacts` | |

## [`atmos/cordon-superconduction`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cordon-superconduction) (`atmos_cordon_superconduction.dm`)

| Finding | Test | Notes |
|---|---|---|
| CORE-1 cordons | `cold_cordon_stops_superconducting` | Reads `SSair.active_super_conductivity` as the only sign of "will superconduct next tick". |
| CORE-1 map edge | `hot_floor_at_map_edge_superconducts` | runtime. Uses an open floor rather than a cordon, so it still covers the null check once cordons are fixed. Changes 3 space tiles at (1,1) on the test z-level. |

## [`atmos/ssair-null-entries`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ssair-null-entries) (`atmos_ssair_null_entries.dm`)

| Finding | Test | Notes |
|---|---|---|
| CORE-4 | `null_atmos_machine_is_skipped` | runtime. Pushes a null into `atmos_machinery` and saves/restores `SSair.currentrun`. |
| CORE-5 | `null_atom_does_not_block_processing` | Pushes a null into `atom_process`. |

## [`atmos/fire-sound`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/fire-sound) (`atmos_fire_sound.dm`)

| Finding | Test | Notes |
|---|---|---|
| CORE-8 | `fire_sound_survives_turf_change` | Reads `fire.sound.parent`. |

## [`atmos/pipenet-bookkeeping`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pipenet-bookkeeping) (`atmos_pipenet_bookkeeping.dm`)

| Finding | Test | Notes |
|---|---|---|
| PIPE-2 | `looped_pump_joins_network` | Gas lost on unwrench. |
| PIPE-3 | `shuttle_move_keeps_component_gas` | Calls the pump's on/after/lateShuttleMove directly. |
| PIPE-8 | `build_next_to_rebuilding_pipe` | runtime, plus gas not reaching across. The "half-built pipeline" case is skipped (needs a tick-check yield). |

## [`atmos/rpd`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/rpd) (`atmos_rpd.dm`)

| Finding | Test | Notes |
|---|---|---|
| PIPE-1 | `rpd_reprogram_connects` | runtime. The one-sided connection didn't reproduce. |
| PIPE-4 | `rpd_unwrench_destroys` | Destroy mode only. |

## [`atmos/device-power-checks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/device-power-checks) (`atmos_device_power_checks.dm`)

| Finding | Test | Notes |
|---|---|---|
| DEV-1 | `mixer/needs_power`, `mixer/needs_output` | |
| DEV-5 | `dual_port_vent_needs_power` | |
| DEV-10 | `mixer/concentration_out_of_range` | |

## [`atmos/gates`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gates) (`atmos_gates.dm`)

| Finding | Test | Notes |
|---|---|---|
| DEV-7 | `pressure_gate_maximize`, `passive_gate_max` | Assert on `ui_data()`. |
| DEV-9 | `pressure_gate_flow_sprite`, `temperature_gate_flow_sprite` | Icon state. |

## [`atmos/vents-scrubbers`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/vents-scrubbers) (`atmos_vents_scrubbers.dm`)

| Finding | Test | Notes |
|---|---|---|
| DEV-3 | `overclocked_vent_survives` | |
| DEV-8 | `scrubber/siphon_power`, `scrubber/widenet_power`, `scrubber/filter_power` | Read the area's static environ load. |

## [`atmos/ventcrawl`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ventcrawl) (`atmos_ventcrawl.dm`)

| Finding | Test | Notes |
|---|---|---|
| DEV-2 | `closed_valve_blocks_ventcrawlers` | |

## [`atmos/pressure-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pressure-tanks) (`atmos_pressure_tanks.dm`)

| Finding | Test | Notes |
|---|---|---|
| MACH-1 | `tank_deconstruct_conserves_gas` | Gas goes from 73,410 to 144,221 mol. |
| MACH-2 | `tank_bridge_conserves_gas` | |

## [`atmos/airlock-pump`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/airlock-pump) (`atmos_airlock_pump.dm`)

| Finding | Test | Notes |
|---|---|---|
| MACH-3 | `airlock_pump_stops_when_airlock_destroyed` | |
| MACH-13 | `airlock_pump_relinks_orphaned_airlock` | |

## [`atmos/cryo`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cryo) (`atmos_cryo.dm`)

| Finding | Test | Notes |
|---|---|---|
| MACH-8 | `cryo_needs_power` | |
| MACH-10 | `cryo_drag_in_conscious_patient` | |
| MACH-14 | `cryo_pry_open_unpowered` | runtime. New finding. |

## [`atmos/electrolyzer-crystallizer`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/electrolyzer-crystallizer) (`atmos_electrolyzer_crystallizer.dm`)

| Finding | Test | Notes |
|---|---|---|
| MACH-5 | `electrolyzer_stops_on_drained_cell` | |
| MACH-6 | `electrolyzer_needs_area_power` | |
| MACH-7 | `crystallizer_gas_input_is_moles` | |
| MACH-9 | `crystallizer_product_has_quality` | Sets `quality_loss` to reach a fractional quality. |

## [`atmos/hfr-moderator`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-moderator) (`atmos_hfr_moderator.dm`)

| Finding | Test | Notes |
|---|---|---|
| HFR-1 | `moderator_consumes_gas` | Reads `moderator_internal`. |

## [`atmos/hfr-part-linking`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-part-linking) (`atmos_hfr_part_linking.dm`)

| Finding | Test | Notes |
|---|---|---|
| HFR-2a | `replaced_cracked_part_leaks` | |
| HFR-2b | `activates_after_replacing_part`, `core_deconstruction_keeps_parts` | |
| HFR-5 | `relink_after_shutdown` | Fails on 8 "overridden" stack traces. |
| HFR-6 | `click_inactive_interface` | runtime |
| HFR-7 | `interface_after_shutdown` | runtime |
| HFR-10 | `part_removal_shuts_down` | New finding. Reads the parts' `active`. |

All three HFR files null the test's reactor vars in `Destroy()`. The core keeps the corners it linked in `corners` even after it is deleted, so a test that still held the core while waiting to be garbage collected made every corner a hard delete, and each one cost a reference search of about 45 s at the end of a full run.

## [`atmos/hfr-meltdown`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-meltdown) (`atmos_hfr_meltdown.dm`)

| Finding | Test | Notes |
|---|---|---|
| HFR-3 | `recipe_locked_while_running`, `power_and_cooling_locked_while_running` | |
| HFR-4 | `meltdown_emp_light_range` | Calls `meltdown()` directly and cancels the explosion. |
| HFR-8 | `meltdown_releases_all_gas` | 1868.93 of 2000 mol released. |
| HFR-9 | `cold_coolant_heal_rate` | |

## [`atmos/portable-gas-release`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/portable-gas-release) (`atmos_portable_gas_release.dm`)

| Finding | Test | Notes |
|---|---|---|
| PORT-1 | `canister_explosion_conserves_gas`, `pump_explosion_conserves_gas` | |
| PORT-2 | `pipe_scrubber_destruction_releases_gas` | |
| PORT-5 | `canister_deconstruction_returns_crystal` | |
| PORT-6 | `broken_canister_releases_tank` | runtime. The stale listener runtimes once the tank is deleted. |

## [`atmos/gas-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gas-tanks) (`atmos_gas_tanks.dm`)

| Finding | Test | Notes |
|---|---|---|
| PORT-3 | `worn_tank_leak_reaches_air`, `held_tank_rupture_reaches_air` | |
| PORT-4 | `deleted_external_tank_closes_internals` | |
| PORT-7 | `captain_jetpack_stabilization` | Checks `TRAIT_NOGRAV_ALWAYS_DRIFT`. |

## [`atmos/lungs`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/lungs) (`atmos_lungs.dm`)

| Finding | Test | Notes |
|---|---|---|
| ALARM-1 | `hot_breath_burns`, `cold_breath_burns` | |
| ALARM-3 | `helium_voice`, `healium_euphoria` | `healium_euphoria` relies on a 15% chance per breath over 100 breaths, so after a fix it could flake about once in 1e7 runs. |

## [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm) (`atmos_air_alarm.dm`)

| Finding | Test | Notes |
|---|---|---|
| ALARM-2 | `cycle_mode_refills`, `alarm_light_on_spacing` | The light test reads `light_color`. |
| ALARM-4 | `vent_reset_external_pressure` | |
| ALARM-5 | `ai_wire` | |
| ALARM-6 | `circuit_vent_external_pressure` | |
| ALARM-7 | `circuit_scrubber_siphoning` | |
| ALARM-11 | `circuit_scrubber_starts_scrubbing` | Runs one `atom_process` pass by hand. |
| ALARM-14 | `power_stale_vent`, `disconnect_missing_sensor`, `threshold_not_a_number` | runtime |

## [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes) (`atmos_small_fixes.dm`)

| Finding | Test | Notes |
|---|---|---|
| PIPE-5 | `component_fitting_not_weldable` | |
| PIPE-6 | `component_unwrench_delay_in_vacuum` | Uses `human/consistent/slow`. |
| PIPE-7 | `layer_adaptor_overlay_layer` | Reads the overlay layer (visual-only finding). |
| PIPE-9 pink | `pipe_colors_layer_apart` | |
| ALARM-9 | `rcd_firelock_frame` | |
| CORE-3 | `merge_displayed_excited_groups` | runtime |

## [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc) (`atmos_scanners_misc.dm`)

| Finding | Test | Notes |
|---|---|---|
| PORT-8 | `miner_static_power_draw`, `miner_power_after_reactivation` | Measures `cable.surplus()`. |
| PORT-9 | `meter_circuit_without_pipe` | runtime. Only reachable with a mapped or admin-spawned meter that has no pipe. |
| PORT-10 | `atmozphere_close_releases_pda` | |
| PORT-11 analyzers | `analyzer_storm_detection_with_two` | |
| ALARM-8 | `monitor_console_cant_control` | |
| ALARM-10 | `alert_console_escalation` | |

## ALARM-12 test (not on any branch)

ALARM-12 has no branch, because it's unclear whether its behaviour is intended. Its test fails on `master` and is kept here in case the finding is taken up:

```dm
/datum/unit_test/atmos_firelock_generic_alarm
	abstract_type = /datum/unit_test/atmos_firelock_generic_alarm

/// Replaces a turf's air with the given partial pressures (kPa).
/datum/unit_test/atmos_firelock_generic_alarm/proc/set_air(turf/open/location, list/gas_pressures, temperature = T20C)
	var/datum/gas_mixture/new_air = new(CELL_VOLUME)
	new_air.temperature = temperature
	for(var/gas_type in gas_pressures)
		new_air.add_gas(gas_type)
		new_air.moles[gas_type] = gas_pressures[gas_type] * CELL_VOLUME / (R_IDEAL_GAS_EQUATION * temperature)
	location.copy_air(new_air)
	return location.return_air()

/// Lets everything watching a turf know its air changed, the way atmos processing does.
/datum/unit_test/atmos_firelock_generic_alarm/proc/expose(turf/open/location)
	var/datum/gas_mixture/air = location.return_air()
	location.temperature_expose(air, air.temperature)

/// Returns TRUE if the atom shows an overlay whose icon state contains the given text.
/datum/unit_test/atmos_firelock_generic_alarm/proc/has_overlay(atom/thing, state_text)
	for(var/mutable_appearance/overlay as anything in thing.overlays)
		if(findtext(overlay.icon_state, state_text))
			return TRUE
	return FALSE

/// A firelock shut by a fire alarm stays alarmed while there's fire next to it.
/datum/unit_test/atmos_firelock_generic_alarm/firelock_holds_near_fire

/datum/unit_test/atmos_firelock_generic_alarm/firelock_holds_near_fire/Run()
	var/turf/centre = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/open/hot_side = get_step(centre, NORTH)
	var/turf/open/cool_side = get_step(centre, SOUTH)
	var/obj/machinery/door/firedoor/firelock = allocate(/obj/machinery/door/firedoor/closed, centre)
	TEST_ASSERT(has_overlay(firelock, "firelock_alarm_type"), "A firelock shut by a fire alarm wasn't showing its alarm lights")

	set_air(hot_side, list(/datum/gas/oxygen = ONE_ATMOSPHERE * O2STANDARD, /datum/gas/nitrogen = ONE_ATMOSPHERE * N2STANDARD), 1000)
	expose(hot_side)
	expose(cool_side)

	TEST_ASSERT(has_overlay(firelock, "firelock_alarm_type"), "The firelock stopped alarming while there was still fire next to it")
```

## Findings without a test

| Finding | Status | Notes |
|---|---|---|
| CORE-2 | skipped | Needs SSair to pause in the middle of ACTIVETURFS while the turf's group is garbage-collected. |
| CORE-6 | skipped | Latent: only space has `run_later`, and it never has the higher pressure. |
| CORE-7 | skipped | Needs a fire spanning two connected z-levels; the test room is a single z-level. |
| GAS-4 | skipped | Handbook text only; the fix is a text edit. |
| PIPE-9 multi-z ventcrawl | skipped | Needs a z-level above. |
| DEV-4 | not a bug | `equalize()` garbage-collects `other`. |
| DEV-6 | not a bug | Wrong argument order, same result. |
| MACH-4 | not a bug | `process_atmos` has `waitfor = FALSE`. |
| MACH-12 | not a bug | Thermomachines have 0 static power. |
| HFR-2c | skipped | Pure hard delete with no observable effect. |
| PORT-11 tank leak message | skipped | Chat message and sound only. |
| ALARM-13 | skipped | Debug stack-trace text only. |
| MACH-11 | not fixed | Left out of `atmos/pressure-tanks` as unrelated. |

## Where the tests reach into internals

The tests were written to check behaviour wherever possible. Where they still read or set internal state, it falls into these groups:

- **Gas setup:** gas is set through `moles[...]`, `return_air()`, `adjust_gas()` and component `airs[]`, the way `gas_transfer.dm` does it.
- **SSair work lists (cordon_superconduction, ssair_null_entries):** they are the only way to see "will this be processed next tick". The tests clean up before asserting.
- **Power:**
  - The test room's power is cut by setting the area's `power_*` vars, which is the same state a dead APC leaves.
  - Power draw is read from the area's static load, or from a powernet's surplus.
- **UI:**
  - UI actions go through `ui_act` with a real `/datum/tgui`, by a human with `TRAIT_PRESERVE_UI_WITHOUT_CLIENT`.
  - Results are read from `ui_data()`, which is what the player sees.
- **Read directly because nothing else exposes them:**
  - an HFR part's `active`;
  - the HFR's `moderator_internal`;
  - an airlock's `locked`;
  - a fire sound's `parent`;
  - a circuit port's `value`;
  - overlay layers.
