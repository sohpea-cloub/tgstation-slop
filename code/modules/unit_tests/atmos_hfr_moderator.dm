/datum/unit_test/atmos_hfr_moderator
	abstract_type = /datum/unit_test/atmos_hfr_moderator
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

/datum/unit_test/atmos_hfr_moderator/Destroy()
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
/datum/unit_test/atmos_hfr_moderator/proc/build_reactor()
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
/datum/unit_test/atmos_hfr_moderator/proc/press(action, list/params = list())
	var/datum/tgui/ui = new(user, interface, "Hypertorus")
	ui.process_status()
	. = interface.ui_act(action, params, ui, ui.state)
	qdel(ui)

/// Moderator gas that a fusion level turns into byproducts is used up, not added to.
/datum/unit_test/atmos_hfr_moderator/moderator_consumes_gas

/datum/unit_test/atmos_hfr_moderator/moderator_consumes_gas/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	press("start_power")
	press("fuel", list("mode" = "h2_t2_fuel"))

	// A level 1 fusion mix, with enough BZ in the moderator to make halon.
	core.internal_fusion.adjust_gas(/datum/gas/hydrogen, 1000)
	core.internal_fusion.adjust_gas(/datum/gas/tritium, 1000)
	core.internal_fusion.temperature = 800
	core.moderator_internal.adjust_gas(/datum/gas/bz, 200)
	core.moderator_internal.temperature = T20C

	var/bz_before = core.moderator_internal.moles[/datum/gas/bz]
	for(var/i in 1 to 3)
		core.process_atmos(1)

	var/halon_made = waste_output.airs[1].moles[/datum/gas/halon]
	TEST_ASSERT(halon_made > 0, "The reactor made no halon from its BZ moderator, so the test setup is wrong")
	var/bz_after = core.moderator_internal.moles[/datum/gas/bz]
	TEST_ASSERT(bz_after < bz_before, "Moderator BZ went from [bz_before] to [bz_after] mol while making [halon_made] mol of halon")

