/datum/unit_test/atmos_share_energy
	abstract_type = /datum/unit_test/atmos_share_energy

/// Sharing between mixtures at different temperatures conserves their total thermal energy
/datum/unit_test/atmos_share_energy/share_conserves_energy

/datum/unit_test/atmos_share_energy/share_conserves_energy/Run()
	var/datum/gas_mixture/hot_mix = allocate(/datum/gas_mixture)
	var/datum/gas_mixture/cold_mix = allocate(/datum/gas_mixture)
	hot_mix.moles[/datum/gas/nitrogen] = 105
	hot_mix.temperature = 400
	cold_mix.moles[/datum/gas/nitrogen] = 100
	cold_mix.temperature = 300
	hot_mix.archive()
	cold_mix.archive()

	var/energy_before = hot_mix.thermal_energy() + cold_mix.thermal_energy()
	hot_mix.share(cold_mix, 0.2, 0.2)
	var/energy_after = hot_mix.thermal_energy() + cold_mix.thermal_energy()

	TEST_ASSERT(abs(energy_after - energy_before) <= energy_before * 1e-5, "Sharing changed total thermal energy from [energy_before] J to [energy_after] J")
