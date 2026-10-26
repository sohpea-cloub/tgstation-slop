/datum/unit_test/atmos_vents_scrubbers
	abstract_type = /datum/unit_test/atmos_vents_scrubbers

/// Returns the turf dx, dy tiles from the bottom left of the test room
/datum/unit_test/atmos_vents_scrubbers/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Builds an atmos machine the way wrenching down a pipe fitting does, then builds its pipenets
/datum/unit_test/atmos_vents_scrubbers/proc/place(type, dx, dy, dir = SOUTH)
	var/obj/machinery/atmospherics/device = allocate(type, spot(dx, dy), null, dir)
	device.on_construction(null, device.pipe_color, device.piping_layer)
	while(length(SSair.rebuild_queue) || length(SSair.expansion_queue))
		SSair.process_rebuilds()
	return device

/// An overclocked vent pump whose fan wears out is not destroyed
/datum/unit_test/atmos_vents_scrubbers/overclocked_vent_survives

/datum/unit_test/atmos_vents_scrubbers/overclocked_vent_survives/Run()
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = place(/obj/machinery/atmospherics/components/unary/vent_pump, 2, 3, SOUTH)
	place(/obj/machinery/atmospherics/pipe/smart, 2, 2)
	vent.set_on(TRUE)
	vent.toggle_overclock("unit test")

	for(var/i in 1 to 500)
		if(QDELETED(vent))
			break
		vent.process_atmos()
	TEST_ASSERT(!QDELETED(vent), "Overclocked vent was destroyed when its fan wore out")

/// Scrubbers, with their power draw on the test room
/datum/unit_test/atmos_vents_scrubbers/scrubber
	abstract_type = /datum/unit_test/atmos_vents_scrubbers/scrubber
	/// The scrubber under test
	var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber

/datum/unit_test/atmos_vents_scrubbers/scrubber/Destroy()
	scrubber = null
	return ..()

/// Builds a scrubber on a pipe and turns it on, scrubbing
/datum/unit_test/atmos_vents_scrubbers/scrubber/proc/build_scrubber()
	scrubber = place(/obj/machinery/atmospherics/components/unary/vent_scrubber, 2, 2, SOUTH)
	place(/obj/machinery/atmospherics/pipe/smart, 2, 1)
	scrubber.set_on(TRUE)
	scrubber.set_scrubbing(ATMOS_DIRECTION_SCRUBBING)

/// How much power the test room's machines are drawing on the environment channel
/datum/unit_test/atmos_vents_scrubbers/scrubber/proc/room_power_draw()
	var/area/room = get_area(run_loc_floor_bottom_left)
	return room.energy_usage[AREA_USAGE_STATIC_ENVIRON]

/// A siphoning scrubber draws more power than one scrubbing a single gas
/datum/unit_test/atmos_vents_scrubbers/scrubber/siphon_power

/datum/unit_test/atmos_vents_scrubbers/scrubber/siphon_power/Run()
	build_scrubber()
	var/scrubbing_draw = room_power_draw()
	scrubber.set_scrubbing(ATMOS_DIRECTION_SIPHONING)
	TEST_ASSERT(room_power_draw() > scrubbing_draw, "Siphoning scrubber drew [room_power_draw()], no more than the [scrubbing_draw] it drew scrubbing CO2")

/// A scrubber draws more power once it is scrubbing the tiles around it
/datum/unit_test/atmos_vents_scrubbers/scrubber/widenet_power

/datum/unit_test/atmos_vents_scrubbers/scrubber/widenet_power/Run()
	build_scrubber()
	var/normal_draw = room_power_draw()
	scrubber.set_widenet(TRUE)
	var/turf/open/room = get_turf(scrubber)
	scrubber.atmos_expose(room.return_air(), room.return_air().temperature)
	TEST_ASSERT(room_power_draw() > normal_draw, "Widenet scrubber drew [room_power_draw()], no more than the [normal_draw] it drew normally")

/// A scrubber draws more power when it is told to scrub more gases
/datum/unit_test/atmos_vents_scrubbers/scrubber/filter_power

/datum/unit_test/atmos_vents_scrubbers/scrubber/filter_power/Run()
	build_scrubber()
	var/one_gas_draw = room_power_draw()
	scrubber.toggle_filters("plasma")
	TEST_ASSERT(room_power_draw() > one_gas_draw, "Scrubber scrubbing CO2 and plasma drew [room_power_draw()], no more than the [one_gas_draw] it drew scrubbing CO2")
