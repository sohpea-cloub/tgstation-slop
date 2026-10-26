/datum/unit_test/atmos_portable_gas_release
	abstract_type = /datum/unit_test/atmos_portable_gas_release

/// Returns the total moles of gas on the given turf.
/datum/unit_test/atmos_portable_gas_release/proc/turf_moles(turf/open/target)
	var/datum/gas_mixture/air = target.return_air()
	return air.total_moles()

/// Fails unless the gas on the turf grew by expected_gain moles.
/datum/unit_test/atmos_portable_gas_release/proc/check_turf_gain(turf/open/target, moles_before, expected_gain, what)
	var/gained = turf_moles(target) - moles_before
	TEST_ASSERT(abs(gained - expected_gain) < max(0.01, expected_gain * 0.001), "[what]: expected [expected_gain] mol to reach the floor, but [gained] mol did")

/// A canister destroyed by an explosion puts its gas onto the floor once, no more.
/datum/unit_test/atmos_portable_gas_release/canister_explosion_conserves_gas

/datum/unit_test/atmos_portable_gas_release/canister_explosion_conserves_gas/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/obj/machinery/portable_atmospherics/canister/oxygen/canister = EASY_ALLOCATE()
	var/datum/gas_mixture/canister_air = canister.return_air()
	var/canister_moles = canister_air.total_moles()
	var/floor_moles = turf_moles(floor)

	canister.ex_act(EXPLODE_DEVASTATE)

	TEST_ASSERT(QDELETED(canister), "The canister survived a devastating explosion")
	check_turf_gain(floor, floor_moles, canister_moles, "Exploded canister")

/// A portable pump destroyed by an explosion puts its gas onto the floor once, no more.
/datum/unit_test/atmos_portable_gas_release/pump_explosion_conserves_gas

/datum/unit_test/atmos_portable_gas_release/pump_explosion_conserves_gas/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/obj/machinery/portable_atmospherics/pump/pump = EASY_ALLOCATE()
	var/datum/gas_mixture/pump_air = pump.return_air()
	pump_air.adjust_gas(/datum/gas/nitrogen, 100)
	var/pump_moles = pump_air.total_moles()
	var/floor_moles = turf_moles(floor)

	pump.ex_act(EXPLODE_DEVASTATE)

	TEST_ASSERT(QDELETED(pump), "The pump survived a devastating explosion")
	check_turf_gain(floor, floor_moles, pump_moles, "Exploded pump")

/// Destroying a pipe scrubber releases the gas in both of its tanks and leaves no canister behind.
/datum/unit_test/atmos_portable_gas_release/pipe_scrubber_destruction_releases_gas

/datum/unit_test/atmos_portable_gas_release/pipe_scrubber_destruction_releases_gas/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/obj/machinery/portable_atmospherics/pipe_scrubber/scrubber = EASY_ALLOCATE()
	var/list/datum/gas_mixture/mixes = scrubber.return_analyzable_air()
	TEST_ASSERT_EQUAL(length(mixes), 2, "Expected the pipe scrubber to have two gas mixtures")
	var/datum/gas_mixture/scrubber_air = mixes[1]
	var/datum/gas_mixture/internal_tank_air = mixes[2]
	scrubber_air.adjust_gas(/datum/gas/nitrogen, 50)
	internal_tank_air.adjust_gas(/datum/gas/nitrogen, 150)
	var/scrubber_moles = scrubber_air.total_moles() + internal_tank_air.total_moles()
	var/floor_moles = turf_moles(floor)

	scrubber.take_damage(scrubber.max_integrity, sound_effect = FALSE)

	TEST_ASSERT(QDELETED(scrubber), "The pipe scrubber was not destroyed")
	var/obj/machinery/portable_atmospherics/canister/left_behind = locate() in floor
	if(left_behind)
		var/datum/gas_mixture/left_air = left_behind.return_air()
		TEST_FAIL("Destroying the pipe scrubber dropped its internal tank as a usable canister holding [left_air.total_moles()] mol")
	check_turf_gain(floor, floor_moles, scrubber_moles, "Destroyed pipe scrubber")

/// Cutting a canister apart gives back the hypernoblium crystal that was inserted into it.
/datum/unit_test/atmos_portable_gas_release/canister_deconstruction_returns_crystal

/datum/unit_test/atmos_portable_gas_release/canister_deconstruction_returns_crystal/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/engineer = EASY_ALLOCATE()
	var/obj/machinery/portable_atmospherics/canister/canister = EASY_ALLOCATE()
	var/obj/item/hypernoblium_crystal/crystal = EASY_ALLOCATE()
	var/obj/item/weldingtool/welder = EASY_ALLOCATE()

	engineer.put_in_active_hand(crystal, forced = TRUE)
	crystal.melee_attack_chain(engineer, canister)
	TEST_ASSERT(QDELETED(crystal), "The crystal was not used up when inserted into the canister")

	engineer.put_in_active_hand(welder, forced = TRUE)
	welder.attack_self(engineer)
	welder.melee_attack_chain(engineer, canister, list(RIGHT_CLICK = TRUE))

	TEST_ASSERT(QDELETED(canister), "The canister was not cut apart")
	TEST_ASSERT_NOTNULL(locate(/obj/item/hypernoblium_crystal) in floor, "Cutting the canister apart lost its hypernoblium crystal")

/// A tank ejected from a broken canister can be deleted later without the canister reacting to it.
/datum/unit_test/atmos_portable_gas_release/broken_canister_releases_tank

/datum/unit_test/atmos_portable_gas_release/broken_canister_releases_tank/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = EASY_ALLOCATE()
	var/obj/machinery/portable_atmospherics/canister/canister = EASY_ALLOCATE()
	var/obj/item/tank/internals/oxygen/tank = EASY_ALLOCATE()

	user.put_in_active_hand(tank, forced = TRUE)
	tank.melee_attack_chain(user, canister)
	TEST_ASSERT_EQUAL(tank.loc, canister, "The tank wasn't inserted into the canister")

	canister.take_damage(canister.max_integrity * 0.7, sound_effect = FALSE)
	TEST_ASSERT(!QDELETED(canister), "The canister was destroyed instead of just broken")
	TEST_ASSERT_EQUAL(tank.loc, floor, "The broken canister didn't drop its tank")

	// The canister no longer holds this tank, so deleting it must not touch the canister.
	qdel(tank)
