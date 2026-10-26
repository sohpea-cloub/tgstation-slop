/datum/unit_test/atmos_compare_early_exit
	abstract_type = /datum/unit_test/atmos_compare_early_exit

/// Two large mixtures whose moles differ by a tiny fraction of their contents compare as similar
/datum/unit_test/atmos_compare_early_exit/compare_large_mixtures

/datum/unit_test/atmos_compare_early_exit/compare_large_mixtures/Run()
	var/datum/gas_mixture/first_mix = allocate(/datum/gas_mixture)
	var/datum/gas_mixture/second_mix = allocate(/datum/gas_mixture)
	first_mix.temperature = T20C
	second_mix.temperature = T20C
	first_mix.moles[/datum/gas/nitrogen] = 2000
	second_mix.moles[/datum/gas/nitrogen] = 2001

	var/result = first_mix.compare(second_mix)
	TEST_ASSERT_EQUAL(result, "", "2000 mol and 2001 mol of nitrogen at the same temperature should compare as similar")

/// compare() with cmp_archive judges the archived state, ignoring changes made since archive()
/datum/unit_test/atmos_compare_early_exit/compare_uses_archive

/datum/unit_test/atmos_compare_early_exit/compare_uses_archive/Run()
	var/datum/gas_mixture/first_mix = allocate(/datum/gas_mixture)
	var/datum/gas_mixture/second_mix = allocate(/datum/gas_mixture)
	var/datum/gas_mixture/third_mix = allocate(/datum/gas_mixture)
	for(var/datum/gas_mixture/mix as anything in list(first_mix, second_mix, third_mix))
		mix.temperature = T20C
	first_mix.moles[/datum/gas/nitrogen] = 100
	second_mix.moles[/datum/gas/nitrogen] = 100
	third_mix.moles[/datum/gas/nitrogen] = 50
	first_mix.archive()
	second_mix.archive()
	third_mix.archive()

	// Moves gas out of the first mix, so only its current state differs from the second mix
	first_mix.share(third_mix, 0.2, 0.2)

	var/result = first_mix.compare(second_mix, TRUE)
	TEST_ASSERT_EQUAL(result, "", "Mixtures with identical archived states should compare as similar when comparing archives")
