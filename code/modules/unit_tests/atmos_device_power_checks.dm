/datum/unit_test/atmos_device_power_checks
	abstract_type = /datum/unit_test/atmos_device_power_checks
	/// Every atmos machine placed with place(), so we can settle their pipenets
	var/list/obj/machinery/atmospherics/placed = list()
	/// The area we cut power to, if any, so it can be restored
	var/area/unpowered_area

/datum/unit_test/atmos_device_power_checks/Destroy()
	if(unpowered_area)
		unpowered_area.requires_power = initial(unpowered_area.requires_power)
		unpowered_area.power_equip = TRUE
		unpowered_area.power_light = TRUE
		unpowered_area.power_environ = TRUE
		unpowered_area.power_change()
		unpowered_area = null
	placed = null
	return ..()

/// Returns the turf dx, dy tiles from the bottom left of the test room
/datum/unit_test/atmos_device_power_checks/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Builds an atmos machine the way wrenching down a pipe fitting does, then builds its pipenets
/datum/unit_test/atmos_device_power_checks/proc/place(type, dx, dy, dir = SOUTH)
	var/obj/machinery/atmospherics/device = allocate(type, spot(dx, dy), null, dir)
	device.on_construction(null, device.pipe_color, device.piping_layer)
	placed += device
	while(length(SSair.rebuild_queue) || length(SSair.expansion_queue))
		SSair.process_rebuilds()
	return device

/// Puts gas into a pipe's pipenet
/datum/unit_test/atmos_device_power_checks/proc/fill(obj/machinery/atmospherics/pipe/pipe, gas_type, moles, temperature = T20C)
	var/datum/gas_mixture/air = pipe.return_air()
	air.adjust_gas(gas_type, moles)
	air.temperature = temperature

/// Lets every pipenet we built share its gas with the machines on it
/datum/unit_test/atmos_device_power_checks/proc/settle_pipenets()
	var/list/datum/pipeline/nets = list()
	for(var/obj/machinery/atmospherics/thing as anything in placed)
		if(!QDELETED(thing))
			nets |= thing.return_pipenets()
	nets -= null
	for(var/datum/pipeline/net as anything in nets)
		net.process()

/// One atmos tick for the given machine: it processes, then the pipenets settle
/datum/unit_test/atmos_device_power_checks/proc/atmos_tick(obj/machinery/atmospherics/machine, times = 1)
	for(var/i in 1 to times)
		machine.process_atmos()
		settle_pipenets()

/// Kills the test room's power, like its APC running dry
/datum/unit_test/atmos_device_power_checks/proc/cut_power()
	unpowered_area = get_area(run_loc_floor_bottom_left)
	unpowered_area.requires_power = TRUE
	unpowered_area.power_equip = FALSE
	unpowered_area.power_light = FALSE
	unpowered_area.power_environ = FALSE
	unpowered_area.power_change()

/// Has user press a button in machine's UI
/datum/unit_test/atmos_device_power_checks/proc/press(mob/user, obj/machinery/machine, action, list/params)
	// Our test mob has no client, which would close any UI it opens
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/tgui/ui = allocate(/datum/tgui, user, machine, "unit test")
	ui.process_status()
	if(ui.status != UI_INTERACTIVE)
		TEST_FAIL("[user] could not use [machine]'s UI")
		return
	machine.ui_act(action, params, ui, ui.state)

/// Has user ctrl-click the target
/datum/unit_test/atmos_device_power_checks/proc/ctrl_click(mob/user, atom/target)
	click_wrapper(user, target, list(LEFT_CLICK = 1, BUTTON = LEFT_CLICK, CTRL_CLICK = 1))

/// A gas mixer in the middle of the room, with inputs north and west and its output south
/datum/unit_test/atmos_device_power_checks/mixer
	abstract_type = /datum/unit_test/atmos_device_power_checks/mixer
	/// The mixer under test
	var/obj/machinery/atmospherics/components/trinary/mixer/mixer
	/// The pipe on the mixer's first input, filled with nitrogen
	var/obj/machinery/atmospherics/pipe/input1
	/// The pipe on the mixer's second input, filled with oxygen
	var/obj/machinery/atmospherics/pipe/input2
	/// The pipe on the mixer's output, if it has one
	var/obj/machinery/atmospherics/pipe/output
	/// The human who turned the mixer on
	var/mob/living/carbon/human/user

/// Builds the mixer and its pipes, fills the inputs and turns the mixer on
/datum/unit_test/atmos_device_power_checks/mixer/proc/build_mixer(with_output = TRUE)
	mixer = place(/obj/machinery/atmospherics/components/trinary/mixer, 2, 2, SOUTH)
	input1 = place(/obj/machinery/atmospherics/pipe/smart, 2, 3)
	input2 = place(/obj/machinery/atmospherics/pipe/smart, 1, 2)
	if(with_output)
		output = place(/obj/machinery/atmospherics/pipe/smart, 2, 1)
	fill(input1, /datum/gas/nitrogen, 50)
	fill(input2, /datum/gas/oxygen, 50)
	settle_pipenets()
	user = allocate(/mob/living/carbon/human/consistent, spot(3, 2))
	ctrl_click(user, mixer)

/datum/unit_test/atmos_device_power_checks/mixer/Destroy()
	mixer = null
	input1 = null
	input2 = null
	output = null
	user = null
	return ..()

/// A gas mixer stops mixing when it loses power
/datum/unit_test/atmos_device_power_checks/mixer/needs_power

/datum/unit_test/atmos_device_power_checks/mixer/needs_power/Run()
	build_mixer()
	atmos_tick(mixer)
	TEST_ASSERT(output.return_air().total_moles() > 0, "Powered mixer did not mix any gas into its output")

	cut_power()
	var/output_moles = output.return_air().total_moles()
	atmos_tick(mixer)
	TEST_ASSERT_EQUAL(output.return_air().total_moles(), output_moles, "Mixer kept mixing gas into its output after losing power")

/// A gas mixer with nothing attached to its output doesn't take gas from its inputs
/datum/unit_test/atmos_device_power_checks/mixer/needs_output

/datum/unit_test/atmos_device_power_checks/mixer/needs_output/Run()
	build_mixer(with_output = FALSE)
	var/input_moles = input1.return_air().total_moles()
	atmos_tick(mixer)
	TEST_ASSERT_EQUAL(input1.return_air().total_moles(), input_moles, "Mixer with no output pipe drained gas from its input")

/// A gas mixer given an out of range concentration still mixes
/datum/unit_test/atmos_device_power_checks/mixer/concentration_out_of_range

/datum/unit_test/atmos_device_power_checks/mixer/concentration_out_of_range/Run()
	build_mixer()
	press(user, mixer, "node1", list("concentration" = 150))
	atmos_tick(mixer)
	TEST_ASSERT(output.return_air().total_moles() > 0, "Mixer set to 150% on node 1 stopped mixing")

/// A dual-port vent stops pumping when it loses power
/datum/unit_test/atmos_device_power_checks/dual_port_vent_needs_power

/datum/unit_test/atmos_device_power_checks/dual_port_vent_needs_power/Run()
	var/obj/machinery/atmospherics/components/binary/dp_vent_pump/vent = place(/obj/machinery/atmospherics/components/binary/dp_vent_pump, 2, 2, EAST)
	var/obj/machinery/atmospherics/pipe/input = place(/obj/machinery/atmospherics/pipe/smart, 1, 2)
	fill(input, /datum/gas/nitrogen, 50)
	settle_pipenets()
	vent.external_pressure_bound = ONE_ATMOSPHERE * 2
	vent.set_on(TRUE)
	var/turf/open/room = get_turf(vent)

	var/room_moles = room.return_air().total_moles()
	atmos_tick(vent)
	TEST_ASSERT(room.return_air().total_moles() > room_moles, "Powered dual-port vent did not pump any gas into the room")

	cut_power()
	room_moles = room.return_air().total_moles()
	atmos_tick(vent)
	TEST_ASSERT_EQUAL(room.return_air().total_moles(), room_moles, "Dual-port vent kept pumping gas into the room after losing power")
