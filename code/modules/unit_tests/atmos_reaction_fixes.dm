/datum/unit_test/atmos_reaction_fixes
	abstract_type = /datum/unit_test/atmos_reaction_fixes

/// Anti-noblium converting the last traces of other gases reports the reaction and leaves no empty gas entries
/datum/unit_test/atmos_reaction_fixes/antinoblium_cleanup_reacts
	/// Whether the mix sent COMSIG_GASMIX_REACTED
	var/reacted_signal = FALSE

/// Records that the mix reacted
/datum/unit_test/atmos_reaction_fixes/antinoblium_cleanup_reacts/proc/on_reacted()
	SIGNAL_HANDLER
	reacted_signal = TRUE

/datum/unit_test/atmos_reaction_fixes/antinoblium_cleanup_reacts/Run()
	var/datum/gas_mixture/mix = allocate(/datum/gas_mixture)
	mix.temperature = T20C
	mix.moles[/datum/gas/antinoblium] = 10
	mix.moles[/datum/gas/nitrogen] = 0.005
	RegisterSignal(mix, COMSIG_GASMIX_REACTED, PROC_REF(on_reacted))

	var/result = mix.react()

	TEST_ASSERT(result, "react() reported no reaction after anti-noblium converted the remaining nitrogen")
	TEST_ASSERT(reacted_signal, "COMSIG_GASMIX_REACTED was not sent after anti-noblium converted the remaining nitrogen")
	TEST_ASSERT(!(/datum/gas/nitrogen in mix.moles), "The mix kept an empty nitrogen entry after anti-noblium converted it")
