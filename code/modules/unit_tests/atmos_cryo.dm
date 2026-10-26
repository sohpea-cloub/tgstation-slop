/datum/unit_test/atmos_cryo
	abstract_type = /datum/unit_test/atmos_cryo
	/// The test room's area, if a test cut its power
	var/area/unpowered_area

/datum/unit_test/atmos_cryo/Destroy()
	if(unpowered_area)
		unpowered_area.requires_power = initial(unpowered_area.requires_power)
		unpowered_area.power_equip = initial(unpowered_area.power_equip)
		unpowered_area.power_light = initial(unpowered_area.power_light)
		unpowered_area.power_environ = initial(unpowered_area.power_environ)
		unpowered_area.power_change()
		unpowered_area = null
	return ..()

/// Returns the test room turf offset from the bottom left corner
/datum/unit_test/atmos_cryo/proc/room_turf(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Makes the test room behave like an area with no working APC
/datum/unit_test/atmos_cryo/proc/cut_room_power()
	unpowered_area = get_area(run_loc_floor_bottom_left)
	unpowered_area.requires_power = TRUE
	unpowered_area.power_equip = FALSE
	unpowered_area.power_light = FALSE
	unpowered_area.power_environ = FALSE
	unpowered_area.power_change()

/// A cryo cell without power should not turn on and treat a patient put inside it
/datum/unit_test/atmos_cryo/cryo_needs_power

/datum/unit_test/atmos_cryo/cryo_needs_power/Run()
	var/mob/living/carbon/human/consistent/doctor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/cup/beaker/cryoxadone/beaker = allocate(/obj/item/reagent_containers/cup/beaker/cryoxadone)
	var/obj/machinery/cryo_cell/cryo = allocate(/obj/machinery/cryo_cell, room_turf(1, 0))

	doctor.put_in_active_hand(beaker)
	cryo.item_interaction(doctor, beaker)
	var/datum/gas_mixture/coolant = new
	coolant.adjust_gas(/datum/gas/oxygen, 100)
	coolant.temperature = 80
	cryo.assume_air(coolant)
	cryo.click_alt(doctor) // Open it

	cut_room_power()
	patient.adjust_brute_loss(30)
	patient.Unconscious(1 MINUTES)
	cryo.mouse_drop_receive(patient, doctor, list())

	var/volume_before = beaker.reagents.total_volume
	cryo.process(2)
	var/volume_after = beaker.reagents.total_volume

	TEST_ASSERT_EQUAL(volume_after, volume_before, "An unpowered cryo cell injected its patient with [volume_before - volume_after]u from its beaker")

/// A closed cryo cell without power can be pried open with a crowbar
/datum/unit_test/atmos_cryo/cryo_pry_open_unpowered

/datum/unit_test/atmos_cryo/cryo_pry_open_unpowered/Run()
	var/mob/living/carbon/human/consistent/doctor = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	var/obj/machinery/cryo_cell/cryo = allocate(/obj/machinery/cryo_cell, room_turf(1, 0))
	TEST_ASSERT(!cryo.state_open, "The cryo cell started open")

	cut_room_power()
	doctor.put_in_active_hand(crowbar)
	crowbar.melee_attack_chain(doctor, cryo)

	TEST_ASSERT(cryo.state_open, "Prying an unpowered cryo cell with a crowbar didn't open it")

/// Dragging a conscious patient onto an open cryo cell should shove them inside
/datum/unit_test/atmos_cryo/cryo_drag_in_conscious_patient

/datum/unit_test/atmos_cryo/cryo_drag_in_conscious_patient/Run()
	var/mob/living/carbon/human/consistent/doctor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/cryo_cell/cryo = allocate(/obj/machinery/cryo_cell, room_turf(1, 0))
	cryo.click_alt(doctor) // Open it

	cryo.mouse_drop_receive(patient, doctor, list())

	TEST_ASSERT_EQUAL(patient.loc, cryo, "Dragging a conscious patient onto an open cryo cell didn't put them inside")
