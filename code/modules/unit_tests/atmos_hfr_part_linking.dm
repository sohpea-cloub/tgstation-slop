/datum/unit_test/atmos_hfr_part_linking
	abstract_type = /datum/unit_test/atmos_hfr_part_linking
	/// The reactor's core
	var/obj/machinery/atmospherics/components/unary/hypertorus/core/core
	/// The reactor's interface, west of the core
	var/obj/machinery/hypertorus/interface/interface
	/// The reactor's fuel input, north of the core
	var/obj/machinery/atmospherics/components/unary/hypertorus/fuel_input/fuel_input
	/// The reactor's moderator input, south of the core
	var/obj/machinery/atmospherics/components/unary/hypertorus/moderator_input/moderator_input
	/// The reactor's waste output, east of the core
	var/obj/machinery/atmospherics/components/unary/hypertorus/waste_output/waste_output
	/// The human who builds and runs the reactor
	var/mob/living/carbon/human/user
	/// The user's multitool
	var/obj/item/multitool/multitool
	/// The user's screwdriver
	var/obj/item/screwdriver/screwdriver
	/// The user's crowbar
	var/obj/item/crowbar/crowbar

/datum/unit_test/atmos_hfr_part_linking/Destroy()
	// The core still holds the corners it linked, so keeping it alive while this test waits to be
	// garbage collected would make them hard deletes.
	core = null
	interface = null
	fuel_input = null
	moderator_input = null
	waste_output = null
	user = null
	multitool = null
	screwdriver = null
	crowbar = null
	return ..()

/// Builds a reactor from its boxes in the middle of the test room, with the user standing next to the interface (west of it).
/datum/unit_test/atmos_hfr_part_linking/proc/build_reactor()
	var/turf/centre = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	user = allocate(/mob/living/carbon/human/consistent, get_step(get_step(centre, WEST), WEST))
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	multitool = allocate(/obj/item/multitool)
	screwdriver = allocate(/obj/item/screwdriver)
	crowbar = allocate(/obj/item/crowbar)

	for(var/direction in GLOB.diagonals)
		allocate(/obj/item/hfr_box/corner, get_step(centre, direction))
	allocate(/obj/item/hfr_box/body/fuel_input, get_step(centre, NORTH))
	allocate(/obj/item/hfr_box/body/moderator_input, get_step(centre, SOUTH))
	allocate(/obj/item/hfr_box/body/waste_output, get_step(centre, EAST))
	allocate(/obj/item/hfr_box/body/interface, get_step(centre, WEST))
	var/obj/item/hfr_box/core/core_box = allocate(/obj/item/hfr_box/core, centre)
	core_box.multitool_act(user, multitool)

	core = locate() in centre
	fuel_input = locate() in get_step(centre, NORTH)
	moderator_input = locate() in get_step(centre, SOUTH)
	waste_output = locate() in get_step(centre, EAST)
	interface = locate() in get_step(centre, WEST)
	if(!core || !fuel_input || !moderator_input || !waste_output || !interface)
		TEST_FAIL("Failed to build the reactor from its boxes")
		return FALSE
	return TRUE

/// Presses a button on the interface's UI as the user.
/datum/unit_test/atmos_hfr_part_linking/proc/press(action, list/params = list())
	var/datum/tgui/ui = new(user, interface, "Hypertorus")
	ui.process_status()
	. = interface.ui_act(action, params, ui, ui.state)
	qdel(ui)

/// Screwdrivers a part open and crowbars it apart.
/datum/unit_test/atmos_hfr_part_linking/proc/deconstruct_part(obj/machinery/part)
	part.screwdriver_act(user, screwdriver)
	part.crowbar_act(user, crowbar)

/// Deconstructs a port and builds a fresh one in the same spot, facing the same way.
/datum/unit_test/atmos_hfr_part_linking/proc/replace_part(obj/machinery/atmospherics/components/unary/hypertorus/part)
	var/part_type = part.type
	var/turf/part_loc = part.loc
	var/part_dir = part.dir
	deconstruct_part(part)
	return allocate(part_type, part_loc, TRUE, part_dir)

/// Total moles of a gas in the test room's air.
/datum/unit_test/atmos_hfr_part_linking/proc/room_moles(gas_type)
	. = 0
	for(var/turf/open/floor in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		. += floor.return_air().moles[gas_type]

/// A cracked part that was replaced no longer counts as the reactor's crack: a new crack forms on a part that is there, and gas leaks out of it into the room.
/datum/unit_test/atmos_hfr_part_linking/replaced_cracked_part_leaks

/datum/unit_test/atmos_hfr_part_linking/replaced_cracked_part_leaks/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	press("start_power")

	// Overfill the moderator at low pressure so it cracks a part without exploding.
	core.moderator_internal.adjust_gas(/datum/gas/helium, 12000)
	core.moderator_internal.temperature = T20C
	core.process_atmos(1)

	// Replace all three ports, which removes the cracked one whichever it is.
	for(var/obj/machinery/atmospherics/components/unary/hypertorus/part as anything in list(fuel_input, moderator_input, waste_output))
		replace_part(part)
		TEST_ASSERT(QDELETED(part), "[part] was not deconstructed")
	// The reactor notices its ports are gone on the next tick and shuts down.
	core.process_atmos(1)
	TEST_ASSERT(!core.active, "The reactor did not shut down after its ports were removed")
	interface.multitool_act(user, multitool)
	TEST_ASSERT(core.active, "The reactor did not reactivate after its ports were replaced")

	// Still overfull, so a new crack forms; then raise the pressure so it leaks steadily.
	core.process_atmos(1)
	core.moderator_internal.temperature = 1100
	core.process_atmos(1)

	TEST_ASSERT(room_moles(/datum/gas/helium) > 0, "No moderator gas leaked into the room from an overfull, pressurised moderator")

/// Fixing a failed build by replacing a part lets the reactor activate.
/datum/unit_test/atmos_hfr_part_linking/activates_after_replacing_part

/datum/unit_test/atmos_hfr_part_linking/activates_after_replacing_part/Run()
	if(!build_reactor())
		return
	// The waste output is missing, so linking fails.
	var/turf/waste_loc = waste_output.loc
	deconstruct_part(waste_output)
	interface.multitool_act(user, multitool)
	TEST_ASSERT(!core.active, "The reactor activated with a missing waste output")

	// Swap the fuel input and add the missing waste output.
	replace_part(fuel_input)
	allocate(/obj/machinery/atmospherics/components/unary/hypertorus/waste_output, waste_loc, TRUE, EAST)
	interface.multitool_act(user, multitool)
	TEST_ASSERT(core.active, "The reactor did not activate after it was fully built")

/// Deconstructing a core that was never activated leaves the parts around it alone.
/datum/unit_test/atmos_hfr_part_linking/core_deconstruction_keeps_parts

/datum/unit_test/atmos_hfr_part_linking/core_deconstruction_keeps_parts/Run()
	if(!build_reactor())
		return
	// The waste output is missing, so linking fails.
	deconstruct_part(waste_output)
	interface.multitool_act(user, multitool)
	TEST_ASSERT(!core.active, "The reactor activated with a missing waste output")

	deconstruct_part(core)
	TEST_ASSERT(QDELETED(core), "The core was not deconstructed")
	TEST_ASSERT(!QDELETED(fuel_input), "Deconstructing the core deleted the fuel input")
	TEST_ASSERT(!QDELETED(moderator_input), "Deconstructing the core deleted the moderator input")
	TEST_ASSERT(!QDELETED(interface), "Deconstructing the core deleted the interface")

/// Re-linking a reactor that was shut down by opening a part doesn't re-register signals it still holds.
/datum/unit_test/atmos_hfr_part_linking/relink_after_shutdown

/datum/unit_test/atmos_hfr_part_linking/relink_after_shutdown/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	TEST_ASSERT(core.active, "The reactor did not activate")

	fuel_input.screwdriver_act(user, screwdriver)
	core.process_atmos(1)
	TEST_ASSERT(!core.active, "Opening the fuel input did not shut the reactor down")
	fuel_input.screwdriver_act(user, screwdriver)

	// Fails through the runtime this raises, if any.
	interface.multitool_act(user, multitool)
	TEST_ASSERT(core.active, "The reactor did not reactivate")

/// Clicking an interface that hasn't been activated only tells the user to activate it.
/datum/unit_test/atmos_hfr_part_linking/click_inactive_interface

/datum/unit_test/atmos_hfr_part_linking/click_inactive_interface/Run()
	if(!build_reactor())
		return
	// Fails through the runtime this raises, if any.
	click_wrapper(user, interface)

/// Using the interface after the reactor shuts down doesn't runtime.
/datum/unit_test/atmos_hfr_part_linking/interface_after_shutdown

/datum/unit_test/atmos_hfr_part_linking/interface_after_shutdown/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	fuel_input.screwdriver_act(user, screwdriver)
	core.process_atmos(1)
	TEST_ASSERT(!core.active, "Opening the fuel input did not shut the reactor down")

	// Fails through the runtime this raises, if any.
	press("fuel", list("mode" = "h2_t2_fuel"))

/// Deconstructing a part of an active reactor shuts the rest of the reactor down straight away.
/datum/unit_test/atmos_hfr_part_linking/part_removal_shuts_down

/datum/unit_test/atmos_hfr_part_linking/part_removal_shuts_down/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	TEST_ASSERT(interface.active, "The reactor did not activate")

	deconstruct_part(fuel_input)
	TEST_ASSERT(QDELETED(fuel_input), "The fuel input was not deconstructed")
	TEST_ASSERT(!interface.active, "The interface stayed active after the fuel input was deconstructed")
	TEST_ASSERT(!moderator_input.active, "The moderator input stayed active after the fuel input was deconstructed")
