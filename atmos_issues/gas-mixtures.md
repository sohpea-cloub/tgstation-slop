# Gas mixtures, gas types and reactions

## GAS-1: `compare()`'s total_moles early exit ignores `cmp_archive` and changes the equality rule (medium, verified)

- **Fixed in:** [`atmos/compare-early-exit`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/compare-early-exit)
- **Location:** `code/modules/atmospherics/gasmixtures/gas_mixture.dm:473-476`. Added by 72ecf748280, "Optimize compare() (#97681)".
- **What's wrong:**
  - `var/total_delta = abs(values_sum(moles) - values_sum(sample.moles))` always reads the current moles. It should read `cached_moles` and `sample_cached_moles`, which hold the archived values when `cmp_archive` is set.
  - It returns `"total_moles"` on the absolute threshold alone (more than about 0.104 mol). It skips the relative check that the per-gas loop applies (`abs_delta > gas_moles * MINIMUM_AIR_RATIO_TO_MOVE`).
- **Effect:**
  - Two turfs each holding 2000 mol of N2, 1 mol apart, used to count as equal. They now count as different.
    - High-pressure areas such as burn chambers and ordnance keep getting re-activated and pulled into excited groups.
    - The SSair difference check (`controllers/subsystem/air.dm:570`) is affected the same way.
  - After a turf has shared with one neighbour, `compare(enemy, TRUE)` can report a difference that the archive-based `share()` won't act on.

## GAS-2: `share()` → `temperature_share()` discards the sharer's mixing temperature (low-medium, confirmed)

- **Fixed in:** [`atmos/share-energy`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/share-energy)
- **Location:** `gas_mixture.dm:424-430` and `448-461`
- **What's wrong:**
  - Line 425 sets `sharer.temperature` from the heat carried in by the moved gas.
  - When the heat capacity changes by less than 10%, line 430 calls `temperature_share()`. That proc sets the sharer's temperature from `sharer.temperature_archived` instead, which throws away the line 425 result.
  - It also divides by the archived heat capacities.
- **Arithmetic (both mixtures N2, `our_coeff` 0.2):**
  - Before: self is 105 mol at 400 K, sharer is 100 mol at 300 K. Total energy is 1,440,000 J.
  - After: total energy is 1,438,801 J, so about 1.2 kJ is lost in a single share.
- **Effect:** energy is not conserved in any LINDA share where gas flows between turfs whose temperatures differ by more than 0.5 K.

## GAS-3: The antinoblium cleanup branch zeroes gases but returns NO_REACTION (low, confirmed)

- **Fixed in:** [`atmos/reaction-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/reaction-fixes)
- **Location:** `code/modules/atmospherics/gasmixtures/reactions.dm:1230-1240`
- **What's wrong:** when `total_not_antinoblium_moles < MINIMUM_MOLE_COUNT`, the code sets `. = NO_REACTION`, then zeroes the other gases and adds their moles to antinoblium. `react()` only garbage-collects and sends `COMSIG_GASMIX_REACTED` when `.` is true.
- **Effect:** zero-mole entries remain in the mix. The change isn't reported, so the reaction recorder misses it.

## GAS-4: Handbook entries in `reaction_factors.dm` contradict the code (low, confirmed)

- **Fixed in:** [`atmos/reaction-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/reaction-fixes)
- **Halon** (lines 191, 193):
  - The text says CO2 is produced at 5 mol per mol of halon. The code (`reactions.dm:870`) makes pluoxium at 2.5 per halon.
  - The text says halon needs FIRE_MINIMUM_TEMPERATURE_TO_EXIST (373 K). The real requirement is `HALON_COMBUSTION_MIN_TEMPERATURE`, 343 K.
- **Freon fire** (lines 65-67, 73):
  - The text says it occurs between 60 and 283 K. The minimum is actually 20 K, and between 20 and 60 K it runs at half scale.
  - The O2 ratio is described backwards: the code gives about 0.55 at 60 K and 1.4 at 283 K.
- **Water vapor** (lines 3-4): the text says freezing consumes none. The code consumes `MOLES_GAS_VISIBLE` whenever `freeze_turf()` succeeds.
- **Plasma fire** (lines 28-29): the text says "at least 97 times" more O2. The threshold is 96, and 96 itself counts.

## Checked, nothing solid

- **Reaction bodies:** heat-capacity ordering, mole bookkeeping against each reaction's factors, requirement temperatures and return values.
- **Gas mixture procs:** merge, remove, equalize, copy, the gas transfer in share, and react's hypernoblium handling.
- **Data:** the gas type count and `moles_visible`.
- **Other files:** `atmos_reaction_recorder.dm` and `atmos_gas_reagents.dm`.
