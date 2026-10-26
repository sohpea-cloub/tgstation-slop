/datum/unit_test/atmos_gates
	abstract_type = /datum/unit_test/atmos_gates
	/// Every atmos machine placed with place(), so we can settle their pipenets
	var/list/obj/machinery/atmospherics/placed = list()

/datum/unit_test/atmos_gates/Destroy()
	placed = null
	return ..()

/// Returns the turf dx, dy tiles from the bottom left of the test room
/datum/unit_test/atmos_gates/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Builds an atmos machine the way wrenching down a pipe fitting does, then builds its pipenets
/datum/unit_test/atmos_gates/proc/place(type, dx, dy, dir = SOUTH)
	var/obj/machinery/atmospherics/device = allocate(type, spot(dx, dy), null, dir)
	device.on_construction(null, device.pipe_color, device.piping_layer)
	placed += device
	while(length(SSair.rebuild_queue) || length(SSair.expansion_queue))
		SSair.process_rebuilds()
	return device

/// Puts gas into a pipe's pipenet
/datum/unit_test/atmos_gates/proc/fill(obj/machinery/atmospherics/pipe/pipe, gas_type, moles, temperature = T20C)
	var/datum/gas_mixture/air = pipe.return_air()
	air.adjust_gas(gas_type, moles)
	air.temperature = temperature

/// Lets every pipenet we built share its gas with the machines on it
/datum/unit_test/atmos_gates/proc/settle_pipenets()
	var/list/datum/pipeline/nets = list()
	for(var/obj/machinery/atmospherics/thing as anything in placed)
		if(!QDELETED(thing))
			nets |= thing.return_pipenets()
	nets -= null
	for(var/datum/pipeline/net as anything in nets)
		net.process()

/// One atmos tick for the given machine: it processes, then the pipenets settle
/datum/unit_test/atmos_gates/proc/atmos_tick(obj/machinery/atmospherics/machine, times = 1)
	for(var/i in 1 to times)
		machine.process_atmos()
		settle_pipenets()

/// Has user press a button in machine's UI
/datum/unit_test/atmos_gates/proc/press(mob/user, obj/machinery/machine, action, list/params)
	// Our test mob has no client, which would close any UI it opens
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/tgui/ui = allocate(/datum/tgui, user, machine, "unit test")
	ui.process_status()
	if(ui.status != UI_INTERACTIVE)
		TEST_FAIL("[user] could not use [machine]'s UI")
		return
	machine.ui_act(action, params, ui, ui.state)

/// Has user ctrl-click the target
/datum/unit_test/atmos_gates/proc/ctrl_click(mob/user, atom/target)
	click_wrapper(user, target, list(LEFT_CLICK = 1, BUTTON = LEFT_CLICK, CTRL_CLICK = 1))

/// Has user alt-click the target
/datum/unit_test/atmos_gates/proc/alt_click(mob/user, atom/target)
	click_wrapper(user, target, list(LEFT_CLICK = 1, BUTTON = LEFT_CLICK, ALT_CLICK = 1))

/// Alt-clicking a pressure gate sets it to the maximum its UI shows
/datum/unit_test/atmos_gates/pressure_gate_maximize

/datum/unit_test/atmos_gates/pressure_gate_maximize/Run()
	var/obj/machinery/atmospherics/components/binary/pressure_valve/gate = place(/obj/machinery/atmospherics/components/binary/pressure_valve, 2, 2, EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, spot(2, 3))
	alt_click(user, gate)
	var/list/data = gate.ui_data(user)
	TEST_ASSERT_EQUAL(data["pressure"], data["max_pressure"], "Alt-clicking the pressure gate didn't set it to the maximum shown in its UI")

/// A passive gate can't be set above the maximum its UI shows
/datum/unit_test/atmos_gates/passive_gate_max

/datum/unit_test/atmos_gates/passive_gate_max/Run()
	var/obj/machinery/atmospherics/components/binary/passive_gate/gate = place(/obj/machinery/atmospherics/components/binary/passive_gate, 2, 2, EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, spot(2, 3))
	press(user, gate, "pressure", list("pressure" = 9000))
	var/list/data = gate.ui_data(user)
	TEST_ASSERT(data["pressure"] <= data["max_pressure"], "Passive gate was set to [data["pressure"]] kPa, above the maximum of [data["max_pressure"]] kPa shown in its UI")

/// A pressure gate stops showing gas flowing once gas stops flowing through it
/datum/unit_test/atmos_gates/pressure_gate_flow_sprite

/datum/unit_test/atmos_gates/pressure_gate_flow_sprite/Run()
	var/obj/machinery/atmospherics/components/binary/pressure_valve/gate = place(/obj/machinery/atmospherics/components/binary/pressure_valve, 2, 2, EAST)
	var/obj/machinery/atmospherics/pipe/input = place(/obj/machinery/atmospherics/pipe/smart, 1, 2)
	var/obj/machinery/atmospherics/pipe/output = place(/obj/machinery/atmospherics/pipe/smart, 3, 2)
	fill(input, /datum/gas/nitrogen, 100)
	settle_pipenets()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, spot(2, 3))
	ctrl_click(user, gate)

	atmos_tick(gate)
	TEST_ASSERT(findtext(gate.icon_state, "flow"), "Pressure gate didn't show gas flowing while it was ([gate.icon_state])")

	atmos_tick(gate, 30)
	var/output_moles = output.return_air().total_moles()
	atmos_tick(gate)
	TEST_ASSERT_EQUAL(output.return_air().total_moles(), output_moles, "Gas was still flowing through the pressure gate after 30 ticks")
	TEST_ASSERT(!findtext(gate.icon_state, "flow"), "Pressure gate still shows gas flowing after it stopped ([gate.icon_state])")

/// A temperature gate stops showing gas flowing once gas stops flowing through it
/datum/unit_test/atmos_gates/temperature_gate_flow_sprite

/datum/unit_test/atmos_gates/temperature_gate_flow_sprite/Run()
	var/obj/machinery/atmospherics/components/binary/temperature_gate/gate = place(/obj/machinery/atmospherics/components/binary/temperature_gate, 2, 2, EAST)
	var/obj/machinery/atmospherics/pipe/input = place(/obj/machinery/atmospherics/pipe/smart, 1, 2)
	var/obj/machinery/atmospherics/pipe/output = place(/obj/machinery/atmospherics/pipe/smart, 3, 2)
	fill(input, /datum/gas/nitrogen, 100, 150)
	settle_pipenets()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, spot(2, 3))
	ctrl_click(user, gate)

	atmos_tick(gate)
	TEST_ASSERT(findtext(gate.icon_state, "flow"), "Temperature gate didn't show gas flowing while it was ([gate.icon_state])")

	atmos_tick(gate, 30)
	var/output_moles = output.return_air().total_moles()
	atmos_tick(gate)
	TEST_ASSERT_EQUAL(output.return_air().total_moles(), output_moles, "Gas was still flowing through the temperature gate after 30 ticks")
	TEST_ASSERT(!findtext(gate.icon_state, "flow"), "Temperature gate still shows gas flowing after it stopped ([gate.icon_state])")
