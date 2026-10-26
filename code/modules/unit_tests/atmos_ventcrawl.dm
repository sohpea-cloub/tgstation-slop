/datum/unit_test/atmos_ventcrawl
	abstract_type = /datum/unit_test/atmos_ventcrawl

/// Returns the turf dx, dy tiles from the bottom left of the test room
/datum/unit_test/atmos_ventcrawl/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Builds an atmos machine the way wrenching down a pipe fitting does, then builds its pipenets
/datum/unit_test/atmos_ventcrawl/proc/place(type, dx, dy, dir = SOUTH)
	var/obj/machinery/atmospherics/device = allocate(type, spot(dx, dy), null, dir)
	device.on_construction(null, device.pipe_color, device.piping_layer)
	while(length(SSair.rebuild_queue) || length(SSair.expansion_queue))
		SSair.process_rebuilds()
	return device

/// A closed valve doesn't let ventcrawlers through
/datum/unit_test/atmos_ventcrawl/closed_valve_blocks_ventcrawlers

/datum/unit_test/atmos_ventcrawl/closed_valve_blocks_ventcrawlers/Run()
	var/obj/machinery/atmospherics/components/unary/passive_vent/vent = place(/obj/machinery/atmospherics/components/unary/passive_vent, 1, 2, EAST)
	place(/obj/machinery/atmospherics/components/binary/valve, 2, 2, EAST)
	place(/obj/machinery/atmospherics/pipe/smart, 3, 2)
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, spot(1, 2), FALSE, "gray")
	mouse.move_into_vent(vent)

	vent.relaymove(mouse, EAST)
	TEST_ASSERT_EQUAL(mouse.loc, vent, "Mouse crawled through a closed valve")
