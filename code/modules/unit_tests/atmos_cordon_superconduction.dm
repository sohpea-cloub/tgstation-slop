/datum/unit_test/atmos_cordon_superconduction
	abstract_type = /datum/unit_test/atmos_cordon_superconduction

/// Runs superconduction on whichever of the given turfs SSair has scheduled, the way one SSair pass would.
/datum/unit_test/atmos_cordon_superconduction/proc/superconduct_pass(list/turf/turfs)
	for(var/turf/conducting as anything in SSair.active_super_conductivity & turfs)
		conducting.super_conduct()

/// Room temperature cordons heated by a nearby fire stop superconducting once the fire is gone.
/datum/unit_test/atmos_cordon_superconduction/cold_cordon_stops_superconducting

/datum/unit_test/atmos_cordon_superconduction/cold_cordon_stops_superconducting/Run()
	var/turf/open/hot_floor = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	var/turf/cordon_one = locate(hot_floor.x + 1, hot_floor.y, hot_floor.z)
	var/turf/cordon_two = locate(hot_floor.x + 2, hot_floor.y, hot_floor.z)
	cordon_one.ChangeTurf(/turf/cordon)
	cordon_two.ChangeTurf(/turf/cordon)
	// What SSair does with changed turfs at the start of its next fire.
	cordon_one.immediate_calculate_adjacent_turfs()
	cordon_two.immediate_calculate_adjacent_turfs()
	var/list/turf/cordons = list(cordon_one, cordon_two)

	// A fire next to the cordon starts superconducting, then burns out.
	hot_floor.air.temperature = 1000
	hot_floor.consider_superconductivity(starting = TRUE)
	superconduct_pass(cordons + hot_floor)
	restore_atmos()
	for(var/i in 1 to 5)
		superconduct_pass(cordons + hot_floor)

	var/still_conducting = length(SSair.active_super_conductivity & cordons)
	SSair.active_super_conductivity -= cordons + hot_floor
	cordon_one.ChangeTurf(/turf/open/indestructible)
	cordon_two.ChangeTurf(/turf/open/indestructible)
	restore_atmos()

	TEST_ASSERT_EQUAL(still_conducting, 0, "Room temperature cordons were still superconducting 5 passes after the fire went out")

/// A floor with hot air in the corner of the map superconducts without erroring.
/datum/unit_test/atmos_cordon_superconduction/hot_floor_at_map_edge_superconducts

/datum/unit_test/atmos_cordon_superconduction/hot_floor_at_map_edge_superconducts/Run()
	var/z = run_loc_floor_bottom_left.z
	var/turf/corner = locate(1, 1, z)
	var/list/turf/neighbours = list(locate(1, 2, z), locate(2, 1, z))
	var/list/original_types = list()
	for(var/turf/changing as anything in neighbours + corner)
		original_types[changing] = changing.type
	// Walls don't conduct, so the only directions left to conduct in are off the map.
	for(var/turf/neighbour as anything in neighbours)
		neighbour.ChangeTurf(/turf/closed/wall)
	var/turf/open/floor/hot_floor = corner.ChangeTurf(/turf/open/floor/iron)
	hot_floor.immediate_calculate_adjacent_turfs()
	hot_floor.air.temperature = 1000

	var/error
	if(hot_floor.consider_superconductivity(starting = TRUE))
		try
			hot_floor.super_conduct()
		catch(var/exception/caught)
			error = "[caught] ([caught.file]:[caught.line])"

	SSair.active_super_conductivity -= hot_floor
	for(var/turf/changed as anything in original_types)
		changed.ChangeTurf(original_types[changed])

	TEST_ASSERT_NULL(error, "Superconducting from a floor in the corner of the map errored")
