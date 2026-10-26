/datum/unit_test/atmos_electrolyzer_crystallizer
	abstract_type = /datum/unit_test/atmos_electrolyzer_crystallizer
	/// The test room's area, if a test cut its power
	var/area/unpowered_area

/datum/unit_test/atmos_electrolyzer_crystallizer/Destroy()
	if(unpowered_area)
		unpowered_area.requires_power = initial(unpowered_area.requires_power)
		unpowered_area.power_equip = initial(unpowered_area.power_equip)
		unpowered_area.power_light = initial(unpowered_area.power_light)
		unpowered_area.power_environ = initial(unpowered_area.power_environ)
		unpowered_area.power_change()
		unpowered_area = null
	return ..()

/// Returns the test room turf offset from the bottom left corner
/datum/unit_test/atmos_electrolyzer_crystallizer/proc/room_turf(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Makes the test room behave like an area with no working APC
/datum/unit_test/atmos_electrolyzer_crystallizer/proc/cut_room_power()
	unpowered_area = get_area(run_loc_floor_bottom_left)
	unpowered_area.requires_power = TRUE
	unpowered_area.power_equip = FALSE
	unpowered_area.power_light = FALSE
	unpowered_area.power_environ = FALSE
	unpowered_area.power_change()

/// An unanchored electrolyzer whose cell can't pay for a tick should stop working
/datum/unit_test/atmos_electrolyzer_crystallizer/electrolyzer_stops_on_drained_cell

/datum/unit_test/atmos_electrolyzer_crystallizer/electrolyzer_stops_on_drained_cell/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/stock_parts/power_store/cell/cell = allocate(/obj/item/stock_parts/power_store/cell)
	var/obj/machinery/electrolyzer/electrolyzer = allocate(/obj/machinery/electrolyzer, room_turf(1, 1))
	cell.use(cell.charge - 5, force = TRUE) // Nearly empty

	electrolyzer.screwdriver_act(user, screwdriver)
	user.put_in_active_hand(cell)
	electrolyzer.item_interaction(user, cell)
	electrolyzer.screwdriver_act(user, screwdriver)
	electrolyzer.click_alt(user)

	var/datum/gas_mixture/air = electrolyzer.loc.return_air()
	air.adjust_gas(/datum/gas/water_vapor, 500)

	for(var/i in 1 to 5)
		electrolyzer.process_atmos()
	var/hydrogen_before = air.moles[/datum/gas/hydrogen]
	for(var/i in 1 to 5)
		electrolyzer.process_atmos()
	var/hydrogen_after = air.moles[/datum/gas/hydrogen]

	TEST_ASSERT_EQUAL(hydrogen_after, hydrogen_before, "An electrolyzer with a [cell.charge] J cell kept making hydrogen")

/// An anchored electrolyzer in an area without power should stop working
/datum/unit_test/atmos_electrolyzer_crystallizer/electrolyzer_needs_area_power

/datum/unit_test/atmos_electrolyzer_crystallizer/electrolyzer_needs_area_power/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	var/obj/machinery/electrolyzer/electrolyzer = allocate(/obj/machinery/electrolyzer, room_turf(1, 1))
	cut_room_power()

	electrolyzer.wrench_act(user, wrench)
	TEST_ASSERT(electrolyzer.anchored, "Failed to anchor the electrolyzer")
	electrolyzer.click_alt(user)

	var/datum/gas_mixture/air = electrolyzer.loc.return_air()
	air.adjust_gas(/datum/gas/water_vapor, 500)

	electrolyzer.process_atmos()
	var/hydrogen_before = air.moles[/datum/gas/hydrogen]
	for(var/i in 1 to 5)
		electrolyzer.process_atmos()
	var/hydrogen_after = air.moles[/datum/gas/hydrogen]

	TEST_ASSERT_EQUAL(hydrogen_after, hydrogen_before, "An anchored electrolyzer in an unpowered area kept making hydrogen")

/// The crystallizer's gas input rate should be a rate in moles, not a fraction of the input gas
/datum/unit_test/atmos_electrolyzer_crystallizer/crystallizer_gas_input_is_moles

/datum/unit_test/atmos_electrolyzer_crystallizer/crystallizer_gas_input_is_moles/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/atmospherics/components/binary/crystallizer/crystallizer = allocate(/obj/machinery/atmospherics/components/binary/crystallizer, room_turf(1, 1))
	SSair.setup_template_machinery(list(crystallizer))
	var/datum/tgui/ui = allocate(/datum/tgui, user, crystallizer, "Crystallizer")

	crystallizer.ui_act("recipe", list("mode" = "hyper_crystalium"), ui, ui.state)
	crystallizer.ui_act("gas_input", list("gas_input" = 10), ui, ui.state)
	crystallizer.ui_act("power", list(), ui, ui.state)

	var/datum/gas_mixture/input = crystallizer.airs[2]
	input.adjust_gas(/datum/gas/oxygen, 5000)

	crystallizer.process_atmos()

	var/removed = 5000 - input.moles[/datum/gas/oxygen]
	TEST_ASSERT(removed <= 100, "A crystallizer set to 10 mol/s pulled [removed] moles of oxygen from its input in one tick")

/// Crystallizer products should always get a quality in their name
/datum/unit_test/atmos_electrolyzer_crystallizer/crystallizer_product_has_quality

/datum/unit_test/atmos_electrolyzer_crystallizer/crystallizer_product_has_quality/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/atmospherics/components/binary/crystallizer/crystallizer = allocate(/obj/machinery/atmospherics/components/binary/crystallizer, room_turf(1, 1))
	SSair.setup_template_machinery(list(crystallizer))
	var/datum/tgui/ui = allocate(/datum/tgui, user, crystallizer, "Crystallizer")

	crystallizer.ui_act("recipe", list("mode" = "hyper_crystalium"), ui, ui.state)
	crystallizer.ui_act("power", list(), ui, ui.state)

	// Plenty of gas at a temperature that neither gains nor loses quality, with a fractional amount of quality already lost
	crystallizer.internal.adjust_gas(/datum/gas/oxygen, 2000)
	crystallizer.internal.adjust_gas(/datum/gas/hypernoblium, 170)
	crystallizer.internal.temperature = 200
	crystallizer.quality_loss = 15.5

	var/turf/output_turf = get_step(crystallizer, SOUTH)
	var/obj/item/hypernoblium_crystal/crystal
	for(var/i in 1 to 30)
		crystallizer.process_atmos()
		crystal = locate() in output_turf
		if(crystal)
			break

	TEST_ASSERT_NOTNULL(crystal, "The crystallizer never finished a crystal")
	TEST_ASSERT_NOTEQUAL(copytext(crystal.name, 1, 2), " ", "The crystallizer made a crystal with no quality in its name: \"[crystal.name]\"")
