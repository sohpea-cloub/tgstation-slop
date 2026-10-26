# Atmospherics audit

This is an audit of the atmospherics code at `87b933384df`. It produced:
- one file per area, listing each finding's ID, location, cause and in-game effect;
- 25 fix branches, each cut from `master`. Each branch has two commits:
  1. unit tests that fail on `master` because of the bugs;
  2. the fix, which makes them pass.

This branch (`atmos/overview`) only holds these documents. The tests live on the fix branches.

| File | Area | Findings |
|---|---|---|
| [core.md](core.md) | SSair, LINDA turfs, excited groups, superconduction, fire | CORE-1..8 |
| [gas-mixtures.md](gas-mixtures.md) | Gas mixture procs, reactions, handbook text | GAS-1..4 |
| [pipes.md](pipes.md) | Pipenets, components base, pipe construction, RPD | PIPE-1..9 |
| [devices.md](devices.md) | Pumps, valves, gates, filters, mixers, vents, scrubbers | DEV-1..10 |
| [machines.md](machines.md) | Pressure tanks, airlock pump, electrolyzer, crystallizer, cryo, thermomachine | MACH-1..14 |
| [hfr.md](hfr.md) | Hypertorus fusion reactor | HFR-1..10 |
| [portables.md](portables.md) | Canisters, portable pumps/scrubbers, tanks, jetpacks, analyzers, meters, miners | PORT-1..11 |
| [alarms.md](alarms.md) | Air alarms, air alarm circuits, atmos consoles, firelocks, lungs | ALARM-1..14 |
| [tests.md](tests.md) | Which test covers which finding, and why some findings have none | |

Each finding's confidence is one of:
- **Verified:** re-read by hand after the audit.
- **Confirmed:** traced end to end by the area audit.
- **Plausible:** depends on something that wasn't fully traced.

Each finding in the area files also says which branch fixes it.

## Fix branches

Each link opens the branch's diff against `master`. The "Review notes" column lists the judgement calls a reviewer is most likely to question.

### Core simulation and gas mixtures

| Branch | Findings | What the fix does | Review notes |
|---|---|---|---|
| [`atmos/compare-early-exit`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/compare-early-exit) | GAS-1 | `compare()`'s early exit now sums the same (archived) lists as the rest of the proc, and applies the same relative threshold. | Keeps #97681's optimisation rather than reverting it. |
| [`atmos/share-energy`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/share-energy) | GAS-2 | `share()` does its conduction inline from the new heat capacities, instead of calling `temperature_share()`, which reset the sharer to its archived temperature. | Changes long-standing core sharing math. It's cheaper than before. `temperature_share()` itself is unchanged. |
| [`atmos/reaction-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/reaction-fixes) | GAS-3, GAS-4 | The antinoblium cleanup returns REACTING when it converted gas, and the handbook text is corrected. | Pure antinoblium still reports no reaction, so it doesn't run GC every tick. |
| [`atmos/cordon-superconduction`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cordon-superconduction) | CORE-1 | Cordons get `thermal_conductivity = 0`, and `super_conduct()` skips directions off the map. | Cordons no longer conduct heat at all. |
| [`atmos/ssair-null-entries`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ssair-null-entries) | CORE-4, CORE-5 | `process_atmos_machinery()` and `process_atoms()` now skip and remove nulls, like the other phases do. | CORE-2 is not fixed: no way to reach it was found. |
| [`atmos/fire-sound`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/fire-sound) | CORE-7, CORE-8 | `update_sound()` uses `set_parent()`, and hot groups track z-levels properly. | The sound still loses its parent if the turf it is currently playing from is changed. That predates this branch. |

### Pipes and construction

| Branch | Findings | What the fix does | Review notes |
|---|---|---|---|
| [`atmos/pipenet-bookkeeping`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pipenet-bookkeeping) | PIPE-2, PIPE-3, PIPE-8 | `replace_pipenet()` replaces every matching port. `nullify_node()` no longer nulls `airs`. Joining a pipeline that is mid-rebuild deletes both pipelines so the rebuild merges them with their gas. | Overlaps the existing local branch `fix/pipenet-merge-55275`, which makes the same `replace_pipenet()` change. |
| [`atmos/rpd`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/rpd) | PIPE-1, PIPE-4 | Reprogramming only clears the smart pipe's own nodes, so its pipeline survives. The unwrench upgrade finds the dropped fitting on the turf. | The upgrade may pick a loose fitting that was already on the same tile. |
| [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes) | PIPE-5, PIPE-6, PIPE-7, PIPE-9 (pink), ALARM-9, ALARM-13, CORE-3, CORE-6 | One-line typo and precedence fixes across 7 files. | Pink is appended to the colour order list rather than placed alphabetically. |

### Devices

| Branch | Findings | What the fix does | Review notes |
|---|---|---|---|
| [`atmos/ventcrawl`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ventcrawl) | DEV-2, PIPE-9 (multi-z) | Valves that start closed clear `VENTCRAWL_ALLOWED`. Only multi-z adapters connect across z-levels. | The multi-z part has no test, because Runtime Station has one deck. |
| [`atmos/device-power-checks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/device-power-checks) | DEV-1, DEV-5, DEV-10 | The mixer's power check uses `\|\|`. The dual-port vent checks `is_operational`. Mixer concentrations are clamped. | |
| [`atmos/gates`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gates) | DEV-7, DEV-9 | Both gates use a 100 atm maximum everywhere, and `is_gas_flowing` is reset every tick. | 100 atm is the limit #53362/#53375 intended. The passive gate's UI now goes up to 10132 kPa. |
| [`atmos/vents-scrubbers`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/vents-scrubbers) | DEV-3, DEV-8 | An overclocked vent switches off when its fan would break, instead of being destroyed. Scrubber power is recalculated when siphoning, widenet or filters change. | #79932 removed the old disable code, so a reviewer may consider destruction intended. |

### Machines

| Branch | Findings | What the fix does | Review notes |
|---|---|---|---|
| [`atmos/pressure-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pressure-tanks) | MACH-1, MACH-2 | A cut pressure tank releases only its share of the shared mix, by volume, as pipelines do in `temporarily_store_air()`. Joining mixes are collected with `|=`, as pipelines do with `other_airs`, and each is merged once. | |
| [`atmos/airlock-pump`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/airlock-pump) | MACH-3, MACH-13 | `break_all_links()` turns the pump off and unlinks each airlock through `unset_cycle_pump()`. | Bolted airlocks now announce "Link broken, unbolting." when links break. |
| [`atmos/cryo`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/cryo) | MACH-8, MACH-10, MACH-14 | It only turns on when closing if operational. Conscious patients go through the shove timer. The crowbar passes the user to `default_pry_open()`. | |
| [`atmos/electrolyzer-crystallizer`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/electrolyzer-crystallizer) | MACH-5, MACH-6, MACH-7, MACH-9 | The electrolyzer uses its leftover cell charge and needs area power when anchored. The crystallizer injects `gas_input` moles per tick. Quality is floored into a named band. | The UI label "moles/s" and the original docs were taken as the intent for MACH-7. |

### HFR

| Branch | Findings | What the fix does | Review notes |
|---|---|---|---|
| [`atmos/hfr-moderator`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-moderator) | HFR-1 | Restores the 8 minus signs lost in #95327. | |
| [`atmos/hfr-part-linking`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-part-linking) | HFR-2, HFR-5, HFR-6, HFR-7, HFR-10 | Deleting a part calls `deactivate()`. `deactivate()` unregisters signals and clears `machine_parts` and the interface's core. A failed scan forgets its parts. `ui_act` and the inactive click are guarded. | |
| [`atmos/hfr-meltdown`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/hfr-meltdown) | HFR-3, HFR-4, HFR-8, HFR-9 | `ui_act` enforces the power-level locks. The EMP uses its light range. Gas pockets get equal shares. The cold-coolant heal follows its defines. A meltdown with no recipe no longer gets stuck. | **Balance-visible:** cold coolant heals about half as much. Only the power-level locks are enforced, not the UI's other button conditions. |

### Portables and tanks

| Branch | Findings | What the fix does | Review notes |
|---|---|---|---|
| [`atmos/portable-gas-release`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/portable-gas-release) | PORT-1, PORT-2, PORT-5, PORT-6 | Removes the double-releasing `ex_act`. The pipe scrubber uses `on_deconstruction`. The canister calls `..()` so the crystal comes back. `canister_break` unregisters the holding tank. | The pipe scrubber now listens for `COMSIG_MACHINERY_BROKEN` on its tank. |
| [`atmos/gas-tanks`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/gas-tanks) | PORT-3, PORT-4, PORT-7, PORT-11 (leak message) | Adds `/mob/assume_air`, which passes gas to the mob's loc. A tank's `Destroy` cuts off internals. The jetpack slot check is fixed. The rupture no longer also says "springs a leak". | **Wider effect:** all gas given to a mob now reaches the air, for example exhaled breath inside another mob, or a held balloon. |

### Alarms, consoles and lungs

| Branch | Findings | What the fix does | Review notes |
|---|---|---|---|
| [`atmos/lungs`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/lungs) | ALARM-1, ALARM-3 | `\|\|` becomes `&&` (regression from #97883). The lost-gas check tests for a null entry (regression from #96448). | |
| [`atmos/air-alarm`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/air-alarm) | ALARM-2, ALARM-4, ALARM-5, ALARM-6, ALARM-7, ALARM-11, ALARM-14 | The hazard messages are an else-if chain with no early return. The vent reset uses 1 atm. The AI wire uses `!mend`. The circuit ports are fixed and re-register processing. The three runtimes are guarded. | `set_threshold` rejects non-numbers, but adds no range check. |
| [`atmos/scanners-misc`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/scanners-misc) | PORT-8, PORT-9, PORT-10, PORT-11 (analyzer), ALARM-8, ALARM-10 | Miner power modes work. The meter circuit is null-safe. AtmoZphere unregisters on close. The analyzer trait source is per item. Monitor-only consoles reject control. The alert console redraws on escalation. | Miners on "no power" keep drawing normal active power, as they have since #60317. |

## Not fixed

- **CORE-2** (null excited group in `share_end`): no way to reach it was found, and the right guard isn't obvious.
- **MACH-11** (tank frame runtimes on a stack with no material): a one-line missing `return`, left out of `atmos/pressure-tanks` as unrelated.
- **ALARM-12** (firelock generic alarm cleared near fire): it's unclear whether this is intended, so it has no branch. Its test is kept in [tests.md](tests.md#alarm-12-test-not-on-any-branch).
- **Not bugs** (confirmed while writing tests): DEV-4, DEV-6, MACH-4, MACH-12. Each is explained in its area file.

## Found along the way, outside atmos

- `code/modules/wiremod/shell/brain_computer_interface.dm:360` passes the wrong arguments to `default_pry_open(user, user, tool, ...)`. This is the same kind of mistake as MACH-14.

## Running a branch's tests

Each fix branch's first commit adds `code/modules/unit_tests/atmos_<group>.dm`, where the group is the branch name with dashes turned into underscores. To run just that file's tests, check out the fix branch and use [test_area.sh](test_area.sh) from this branch. It runs against any checkout set in `ATMOS_ROOT`:

```bash
ATMOS_ROOT=/path/to/checkout-of-atmos/hfr-part-linking bash atmos_issues/test_area.sh hfr_part_linking
```

The script works on copies: it writes a `tgstation.atmos_<group>.dme` and a `_unit_tests.atmos_<group>.dm` that include only that group's file and focus its tests, then compiles and runs them. Extra test types given after the group are focused too (e.g. `/datum/unit_test/lungs`). It needs:
- `dm.exe` and `dd.exe` from `C:\Program Files (x86)\BYOND\bin`, or from `$BYOND_BIN`;
- `data/next_map.json` set to Runtime Station (created if missing).

Results are in `data/atmos_tests/<group>.run.log`. Delete the generated files afterwards.
