/datum/unit_test/atmos_gas_tanks
	abstract_type = /datum/unit_test/atmos_gas_tanks

/// Returns the total moles of gas on the given turf.
/datum/unit_test/atmos_gas_tanks/proc/turf_moles(turf/open/target)
	var/datum/gas_mixture/air = target.return_air()
	return air.total_moles()

/// Fails unless the gas on the turf grew by expected_gain moles.
/datum/unit_test/atmos_gas_tanks/proc/check_turf_gain(turf/open/target, moles_before, expected_gain, what)
	var/gained = turf_moles(target) - moles_before
	TEST_ASSERT(abs(gained - expected_gain) < max(0.01, expected_gain * 0.001), "[what]: expected [expected_gain] mol to reach the floor, but [gained] mol did")

/// Gas leaking from a broken tank worn on someone's back reaches the air around them.
/datum/unit_test/atmos_gas_tanks/worn_tank_leak_reaches_air

/datum/unit_test/atmos_gas_tanks/worn_tank_leak_reaches_air/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/wearer = EASY_ALLOCATE()
	var/obj/item/tank/internals/oxygen/tank = EASY_ALLOCATE()
	TEST_ASSERT(wearer.equip_to_slot_if_possible(tank, ITEM_SLOT_BACK), "Couldn't put the tank on the wearer's back")

	tank.take_damage(tank.max_integrity * 0.6, sound_effect = FALSE)
	TEST_ASSERT(!QDELETED(tank), "The tank was destroyed instead of just broken")

	var/datum/gas_mixture/tank_air = tank.return_air()
	var/tank_moles = tank_air.total_moles()
	var/floor_moles = turf_moles(floor)
	tank.process(1)
	var/leaked = tank_moles - tank_air.total_moles()

	TEST_ASSERT(leaked > 0, "The broken tank didn't leak")
	check_turf_gain(floor, floor_moles, leaked, "Leak from a worn tank")

/// A tank that ruptures in someone's hand releases its gas into the air.
/datum/unit_test/atmos_gas_tanks/held_tank_rupture_reaches_air

/datum/unit_test/atmos_gas_tanks/held_tank_rupture_reaches_air/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/holder = EASY_ALLOCATE()
	var/obj/item/tank/internals/plasma/tank = EASY_ALLOCATE()
	TEST_ASSERT(holder.put_in_hands(tank), "Couldn't put the tank in the holder's hand")
	var/datum/gas_mixture/tank_air = tank.return_air()
	var/tank_moles = tank_air.total_moles()
	var/floor_moles = turf_moles(floor)

	tank.take_damage(tank.max_integrity, sound_effect = FALSE)

	TEST_ASSERT(QDELETED(tank), "The tank did not rupture")
	check_turf_gain(floor, floor_moles, tank_moles, "Ruptured held tank")

/// Someone breathing from an external tank stops breathing from it when the tank is deleted.
/datum/unit_test/atmos_gas_tanks/deleted_external_tank_closes_internals

/datum/unit_test/atmos_gas_tanks/deleted_external_tank_closes_internals/Run()
	var/mob/living/carbon/human/consistent/patient = EASY_ALLOCATE()
	var/obj/item/clothing/mask/breath/mask = EASY_ALLOCATE()
	var/obj/item/tank/internals/oxygen/tank = EASY_ALLOCATE()
	TEST_ASSERT(patient.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK), "Couldn't put the breath mask on the patient")
	TEST_ASSERT(patient.open_internals(tank, is_external = TRUE), "Couldn't connect the patient to the external tank")

	qdel(tank)
	patient.breathe()

	TEST_ASSERT(!patient.failed_last_breath && !patient.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "The patient suffocated on the internals of a deleted external tank instead of breathing the room's air")

/// Toggling stabilization on a worn captain's jetpack stops the wearer drifting.
/datum/unit_test/atmos_gas_tanks/captain_jetpack_stabilization

/datum/unit_test/atmos_gas_tanks/captain_jetpack_stabilization/Run()
	var/mob/living/carbon/human/consistent/captain = EASY_ALLOCATE()
	var/obj/item/tank/jetpack/captain/jetpack = EASY_ALLOCATE()
	TEST_ASSERT(captain.equip_to_slot_if_possible(jetpack, ITEM_SLOT_BACK), "Couldn't put the jetpack on the captain's back")

	var/datum/action/item_action/toggle_jetpack/toggle = locate() in jetpack.actions
	var/datum/action/item_action/jetpack_stabilization/stabilization = locate() in jetpack.actions
	TEST_ASSERT_NOTNULL(toggle, "The jetpack has no toggle action")
	TEST_ASSERT_NOTNULL(stabilization, "The jetpack has no stabilization action")

	toggle.Trigger()
	TEST_ASSERT(HAS_TRAIT(captain, TRAIT_NOGRAV_ALWAYS_DRIFT), "Turning on the unstabilized jetpack didn't make the captain drift")

	stabilization.Trigger()
	TEST_ASSERT(!HAS_TRAIT(captain, TRAIT_NOGRAV_ALWAYS_DRIFT), "The captain still drifts after turning jetpack stabilization on")
