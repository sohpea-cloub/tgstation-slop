/datum/unit_test/atmos_hfr_meltdown
	abstract_type = /datum/unit_test/atmos_hfr_meltdown
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

/datum/unit_test/atmos_hfr_meltdown/Destroy()
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
/datum/unit_test/atmos_hfr_meltdown/proc/build_reactor()
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
/datum/unit_test/atmos_hfr_meltdown/proc/press(action, list/params = list())
	var/datum/tgui/ui = new(user, interface, "Hypertorus")
	ui.process_status()
	. = interface.ui_act(action, params, ui, ui.state)
	qdel(ui)

/// Total moles of a gas in the test room's air.
/datum/unit_test/atmos_hfr_meltdown/proc/room_moles(gas_type)
	. = 0
	for(var/turf/open/floor in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		. += floor.return_air().moles[gas_type]

/// Stops the meltdown's explosion, so the test room survives it
/datum/unit_test/atmos_hfr_meltdown/proc/cancel_explosion(datum/source)
	SIGNAL_HANDLER
	return COMSIG_CANCEL_EXPLOSION

/// The recipe can't be changed while fusion is running.
/datum/unit_test/atmos_hfr_meltdown/recipe_locked_while_running

/datum/unit_test/atmos_hfr_meltdown/recipe_locked_while_running/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	press("start_power")
	press("fuel", list("mode" = "h2_t2_fuel"))
	TEST_ASSERT_EQUAL(interface.ui_data(user)["selected"], "h2_t2_fuel", "Selecting a recipe while the reactor is cold did not work")

	core.internal_fusion.adjust_gas(/datum/gas/hydrogen, 1000)
	core.internal_fusion.adjust_gas(/datum/gas/tritium, 1000)
	core.internal_fusion.temperature = 800
	core.process_atmos(1)
	TEST_ASSERT(interface.ui_data(user)["power_level"] > 0, "The reactor did not reach a fusion level, so the test setup is wrong")

	press("fuel", list("mode" = "h2_o2_fuel"))
	TEST_ASSERT_EQUAL(interface.ui_data(user)["selected"], "h2_t2_fuel", "The recipe was changed while fusion was running")

/// Power and cooling can't be turned off while fusion is running.
/datum/unit_test/atmos_hfr_meltdown/power_and_cooling_locked_while_running

/datum/unit_test/atmos_hfr_meltdown/power_and_cooling_locked_while_running/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	press("start_power")
	press("start_cooling")
	press("fuel", list("mode" = "h2_t2_fuel"))
	var/list/data = interface.ui_data(user)
	TEST_ASSERT(data["start_power"] && data["start_cooling"], "Turning on power and cooling while the reactor is cold did not work")

	core.internal_fusion.adjust_gas(/datum/gas/hydrogen, 1000)
	core.internal_fusion.adjust_gas(/datum/gas/tritium, 1000)
	core.internal_fusion.temperature = 800
	core.process_atmos(1)
	TEST_ASSERT(interface.ui_data(user)["power_level"] > 0, "The reactor did not reach a fusion level, so the test setup is wrong")

	press("start_power")
	press("start_cooling")
	data = interface.ui_data(user)
	if(!data["start_power"])
		TEST_FAIL("Power was turned off while fusion was running")
	if(!data["start_cooling"])
		TEST_FAIL("Cooling was turned off while fusion was running")

/// A non-critical meltdown's EMP reaches out to its light range, not just its heavy range.
/datum/unit_test/atmos_hfr_meltdown/meltdown_emp_light_range

/datum/unit_test/atmos_hfr_meltdown/meltdown_emp_light_range/Run()
	core = allocate(/obj/machinery/atmospherics/components/unary/hypertorus/core, run_loc_floor_bottom_left, TRUE)
	RegisterSignal(core, COMSIG_ATOM_EXPLODE, PROC_REF(cancel_explosion))
	// Hydrogen + oxygen at level 1: heavy EMP range 3, light range 5.
	core.selected_fuel = GLOB.hfr_fuels_list["h2_o2_fuel"]
	core.power_level = 1

	var/obj/item/stock_parts/power_store/cell/cell = allocate(/obj/item/stock_parts/power_store/cell/high, run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(get_dist(core, cell), 4, "The cell is not 4 tiles from the core")
	var/charge_before = cell.charge

	core.meltdown()
	TEST_ASSERT(cell.charge < charge_before, "A cell 4 tiles away was not hit by the meltdown's EMP")

/// A meltdown releases all of the fusion and moderator gas into the room.
/datum/unit_test/atmos_hfr_meltdown/meltdown_releases_all_gas

/datum/unit_test/atmos_hfr_meltdown/meltdown_releases_all_gas/Run()
	var/turf/centre = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	core = allocate(/obj/machinery/atmospherics/components/unary/hypertorus/core, centre, TRUE)
	RegisterSignal(core, COMSIG_ATOM_EXPLODE, PROC_REF(cancel_explosion))
	// Plasma + oxygen: no EMP or radiation, 5 gas pockets.
	core.selected_fuel = GLOB.hfr_fuels_list["plasma_o2_fuel"]
	core.power_level = 1
	core.internal_fusion.adjust_gas(/datum/gas/helium, 1000)
	core.internal_fusion.temperature = T20C
	core.moderator_internal.adjust_gas(/datum/gas/helium, 1000)
	core.moderator_internal.temperature = T20C

	var/helium_before = room_moles(/datum/gas/helium)
	core.meltdown()
	var/released = room_moles(/datum/gas/helium) - helium_before
	TEST_ASSERT(abs(released - 2000) < 1, "Meltdown released [released] of the reactor's 2000 mol of helium")

/// Cold coolant heals the core by at most the cold coolant maximum per second, and barely at all just under the threshold.
/datum/unit_test/atmos_hfr_meltdown/cold_coolant_heal_rate

/datum/unit_test/atmos_hfr_meltdown/cold_coolant_heal_rate/Run()
	if(!build_reactor())
		return
	interface.multitool_act(user, multitool)
	press("start_power")

	// Enough fusion mass to not heal from a thin mix, cold enough to stay at level 0.
	core.internal_fusion.adjust_gas(/datum/gas/nitrogen, 1500)
	core.internal_fusion.temperature = T20C
	core.airs[1].adjust_gas(/datum/gas/nitrogen, 100)

	var/max_heal_percent = HYPERTORUS_COLD_COOLANT_MAX_RESTORE / core.melting_point * 100
	var/cold_heal = heal_percent_per_second(TCMB)
	if(cold_heal > max_heal_percent)
		TEST_FAIL("Coolant at [TCMB] K healed [cold_heal]% integrity per second, more than the maximum of [max_heal_percent]%")
	var/warm_heal = heal_percent_per_second(HYPERTORUS_COLD_COOLANT_THRESHOLD - 1000)
	if(warm_heal > max_heal_percent * 0.05)
		TEST_FAIL("Coolant just under the threshold healed [warm_heal]% integrity per second, expected close to 0")

/// Runs the core for 10 seconds with coolant at the given temperature, and returns how much integrity it healed per second, in percent
/datum/unit_test/atmos_hfr_meltdown/cold_coolant_heal_rate/proc/heal_percent_per_second(coolant_temperature)
	var/seconds = 10
	core.airs[1].temperature = coolant_temperature
	core.critical_threshold_proximity = 450
	var/integrity_before = core.get_integrity_percent()
	core.process_atmos(seconds)
	return (core.get_integrity_percent() - integrity_before) / seconds
