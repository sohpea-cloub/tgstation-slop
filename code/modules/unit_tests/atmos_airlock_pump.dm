/datum/unit_test/atmos_airlock_pump
	abstract_type = /datum/unit_test/atmos_airlock_pump

/// Returns the test room turf offset from the bottom left corner
/datum/unit_test/atmos_airlock_pump/proc/room_turf(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Total moles of gas on the floor of the test room
/datum/unit_test/atmos_airlock_pump/proc/room_moles()
	. = 0
	for(var/turf/open/floor in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		. += floor.return_air().total_moles()

/// Sets up an airlock pump at the middle of the room with an internal airlock north of it and an external one south of it
/datum/unit_test/atmos_airlock_pump/proc/make_airlock_pump(list/airlocks)
	airlocks["internal"] = allocate(/obj/machinery/door/airlock/external, room_turf(2, 3))
	airlocks["external"] = allocate(/obj/machinery/door/airlock/external, room_turf(2, 1))
	var/obj/machinery/atmospherics/components/unary/airlock_pump/pump = allocate(/obj/machinery/atmospherics/components/unary/airlock_pump, room_turf(2, 2), TRUE, NORTH)
	SSair.setup_template_machinery(list(pump))
	sleep(1 SECONDS) // Let the airlocks finish bolting
	return pump

/// Destroying the external airlock mid-cycle should stop the pump instead of leaving it pumping forever
/datum/unit_test/atmos_airlock_pump/airlock_pump_stops_when_airlock_destroyed

/datum/unit_test/atmos_airlock_pump/airlock_pump_stops_when_airlock_destroyed/Run()
	var/list/airlocks = list()
	var/obj/machinery/atmospherics/components/unary/airlock_pump/pump = make_airlock_pump(airlocks)
	var/obj/machinery/door/airlock/external = airlocks["external"]

	pump.airlock_act(external) // Start depressurizing
	qdel(external)

	var/moles_before = room_moles()
	pump.process_atmos()
	pump.process_atmos()
	var/moles_after = room_moles()

	TEST_ASSERT_EQUAL(moles_after, moles_before, "The airlock pump kept siphoning the room after its only external airlock was destroyed")

/// Airlocks left over from a broken cycling setup should be linkable by a new pump
/datum/unit_test/atmos_airlock_pump/airlock_pump_relinks_orphaned_airlock

/datum/unit_test/atmos_airlock_pump/airlock_pump_relinks_orphaned_airlock/Run()
	var/list/airlocks = list()
	make_airlock_pump(airlocks)
	qdel(airlocks["external"])

	// A new pump west of the surviving internal airlock, facing it, with a new external airlock behind it
	var/obj/machinery/door/airlock/external/new_external = allocate(/obj/machinery/door/airlock/external, room_turf(0, 3))
	allocate(/obj/machinery/atmospherics/components/unary/airlock_pump, room_turf(1, 3), TRUE, EAST)
	sleep(1 SECONDS) // Let the airlocks finish moving

	// A pump that sets up cycling bolts its external airlocks
	TEST_ASSERT(new_external.locked, "A new airlock pump couldn't link to an internal airlock whose old pump lost its external airlock")
