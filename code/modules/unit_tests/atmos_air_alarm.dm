/datum/unit_test/atmos_air_alarm
	abstract_type = /datum/unit_test/atmos_air_alarm

/// Makes a working, unlocked air alarm. Alarms built at runtime start as an empty frame.
/datum/unit_test/atmos_air_alarm/proc/make_alarm(turf/location = run_loc_floor_bottom_left)
	var/obj/machinery/airalarm/alarm = allocate(/obj/machinery/airalarm, location)
	alarm.buildstage = AIR_ALARM_BUILD_COMPLETE
	alarm.set_panel_open(FALSE)
	alarm.unlock()
	alarm.update_appearance()
	return alarm

/// Makes a mob that can use UIs without a client.
/datum/unit_test/atmos_air_alarm/proc/make_user(turf/location = run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, location)
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	return user

/// Presses a button on a machine's UI as the given user.
/datum/unit_test/atmos_air_alarm/proc/press(mob/user, obj/machinery/machine, action, list/params = list())
	var/datum/tgui/ui = allocate(/datum/tgui, user, machine, "test")
	ui.process_status()
	return machine.ui_act(action, params, ui, ui.state)

/// Connects a unary device to a new pipe port east of it, like freshly built piping waiting for its pipenet.
/datum/unit_test/atmos_air_alarm/proc/connect_to_port(obj/machinery/atmospherics/components/unary/device)
	var/obj/machinery/atmospherics/components/unary/portables_connector/port = allocate(/obj/machinery/atmospherics/components/unary/portables_connector, get_step(device, EAST), TRUE, WEST)
	device.atmos_init()
	port.atmos_init()
	SSair.add_to_rebuild_queue(device)

/// Makes a vent facing east, connected to a pipe port and with high pressure air behind it.
/datum/unit_test/atmos_air_alarm/proc/make_vent(turf/location = run_loc_floor_bottom_left)
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = allocate(/obj/machinery/atmospherics/components/unary/vent_pump, location, TRUE, EAST)
	connect_to_port(vent)
	var/datum/gas_mixture/pipe_air = vent.airs[1]
	pipe_air.temperature = T20C
	var/total_moles = 20 * ONE_ATMOSPHERE * pipe_air.volume / (R_IDEAL_GAS_EQUATION * T20C)
	pipe_air.assert_gases(/datum/gas/oxygen, /datum/gas/nitrogen)
	pipe_air.moles[/datum/gas/oxygen] = total_moles * O2STANDARD
	pipe_air.moles[/datum/gas/nitrogen] = total_moles * N2STANDARD
	return vent

/// Makes a scrubber facing east, connected to a pipe port.
/datum/unit_test/atmos_air_alarm/proc/make_scrubber(turf/location = run_loc_floor_bottom_left)
	var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber = allocate(/obj/machinery/atmospherics/components/unary/vent_scrubber, location, TRUE, EAST)
	connect_to_port(scrubber)
	return scrubber

/// Replaces a turf's air with the given partial pressures (kPa).
/datum/unit_test/atmos_air_alarm/proc/set_air(turf/open/location, list/gas_pressures, temperature = T20C)
	var/datum/gas_mixture/new_air = new(CELL_VOLUME)
	new_air.temperature = temperature
	for(var/gas_type in gas_pressures)
		new_air.add_gas(gas_type)
		new_air.moles[gas_type] = gas_pressures[gas_type] * CELL_VOLUME / (R_IDEAL_GAS_EQUATION * temperature)
	location.copy_air(new_air)
	return location.return_air()

/// Sets a turf to normal station air.
/datum/unit_test/atmos_air_alarm/proc/set_normal_air(turf/open/location)
	return set_air(location, list(/datum/gas/oxygen = ONE_ATMOSPHERE * O2STANDARD, /datum/gas/nitrogen = ONE_ATMOSPHERE * N2STANDARD))

/// Lets everything watching a turf know its air changed, the way atmos processing does.
/datum/unit_test/atmos_air_alarm/proc/expose(turf/open/location)
	var/datum/gas_mixture/air = location.return_air()
	location.temperature_expose(air, air.temperature)

/// Plugs a circuit into a machine with a USB cable and returns the circuit.
/datum/unit_test/atmos_air_alarm/proc/plug_circuit_into(obj/machinery/machine)
	var/obj/structure/bot/shell = allocate(/obj/structure/bot, get_turf(machine))
	var/obj/item/integrated_circuit/loaded/circuit = allocate(/obj/item/integrated_circuit/loaded)
	var/datum/component/shell/shell_component = shell.GetComponent(/datum/component/shell)
	shell_component.attach_circuit(circuit)
	var/obj/item/usb_cable/cable = allocate(/obj/item/usb_cable)
	SEND_SIGNAL(shell, COMSIG_ATOM_USB_CABLE_TRY_ATTACH, cable, null)
	SEND_SIGNAL(machine, COMSIG_ATOM_USB_CABLE_TRY_ATTACH, cable, null)
	return circuit

/// In Cycle mode, once the room has been siphoned out the vents refill it.
/datum/unit_test/atmos_air_alarm/cycle_mode_refills

/datum/unit_test/atmos_air_alarm/cycle_mode_refills/Run()
	var/turf/open/room = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = make_user()
	var/obj/machinery/airalarm/alarm = make_alarm()
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = make_vent()
	set_normal_air(room)
	press(user, alarm, "mode", list("mode" = "[/datum/air_alarm_mode/cycle]"))

	// The scrubbers have siphoned the room out.
	set_air(room, list())
	expose(room)
	vent.process_atmos()

	var/pressure = room.return_air().return_pressure()
	TEST_ASSERT(pressure > WARNING_LOW_PRESSURE, "Cycle mode didn't refill the room after it was siphoned out (room is at [pressure] kPa)")

/// The air alarm's light turns red when the room loses its air.
/datum/unit_test/atmos_air_alarm/alarm_light_on_spacing

/datum/unit_test/atmos_air_alarm/alarm_light_on_spacing/Run()
	var/turf/open/room = run_loc_floor_bottom_left
	var/obj/machinery/airalarm/alarm = make_alarm()
	set_normal_air(room)
	expose(room)

	set_air(room, list())
	expose(room)
	TEST_ASSERT_EQUAL(alarm.light_color, "#FF0022", "The air alarm's light didn't turn red when the room was spaced")

/// Resetting a vent's external pressure target from the air alarm puts it back to one atmosphere.
/datum/unit_test/atmos_air_alarm/vent_reset_external_pressure

/datum/unit_test/atmos_air_alarm/vent_reset_external_pressure/Run()
	var/turf/open/room = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = make_user()
	var/obj/machinery/airalarm/alarm = make_alarm()
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = make_vent()
	set_normal_air(room)

	press(user, alarm, "power", list("ref" = REF(vent), "val" = 1))
	press(user, alarm, "set_external_pressure", list("ref" = REF(vent), "value" = 90))
	press(user, alarm, "reset_external_pressure", list("ref" = REF(vent)))
	vent.process_atmos()

	var/pressure = room.return_air().return_pressure()
	TEST_ASSERT(pressure <= ONE_ATMOSPHERE * 1.05, "After resetting its external target, the vent pumped a room at one atmosphere up to [pressure] kPa")

/// Cutting an air alarm's AI wire locks the AI out, and mending it lets the AI back in.
/datum/unit_test/atmos_air_alarm/ai_wire

/datum/unit_test/atmos_air_alarm/ai_wire/Run()
	var/obj/machinery/airalarm/alarm = make_alarm()
	allocate(/obj/machinery/camera/autoname, get_step(run_loc_floor_bottom_left, EAST))
	var/mob/dead/observer/fake_ghost = allocate(/mob/dead/observer)
	var/mob/living/silicon/ai/ai = allocate(/mob/living/silicon/ai, run_loc_floor_top_right, fake_ghost)
	ADD_TRAIT(ai, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(alarm.ui_status(ai, GLOB.default_state), UI_INTERACTIVE, "The AI couldn't use an untouched air alarm")

	alarm.wires.cut(WIRE_AI)
	TEST_ASSERT_EQUAL(alarm.ui_status(ai, GLOB.default_state), UI_CLOSE, "The AI could still use the air alarm after its AI wire was cut")

	alarm.wires.cut(WIRE_AI)
	TEST_ASSERT_EQUAL(alarm.ui_status(ai, GLOB.default_state), UI_INTERACTIVE, "The AI couldn't use the air alarm after its AI wire was mended")

/// A circuit setting a vent's external pressure target makes the vent pump the room to that pressure.
/datum/unit_test/atmos_air_alarm/circuit_vent_external_pressure

/datum/unit_test/atmos_air_alarm/circuit_vent_external_pressure/Run()
	var/turf/open/room = run_loc_floor_bottom_left
	var/obj/machinery/airalarm/alarm = make_alarm()
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = make_vent()
	set_normal_air(room)

	var/obj/item/integrated_circuit/circuit = plug_circuit_into(alarm)
	var/obj/item/circuit_component/air_alarm_vents/vent_control = locate() in circuit.attached_components
	TEST_ASSERT_NOTNULL(vent_control, "The air alarm didn't give the circuit a vent control component")
	vent_control.vents.set_input(vent.id_tag)
	vent_control.enable.set_input(COMPONENT_SIGNAL)
	vent_control.external_pressure.set_input(ONE_ATMOSPHERE * 2)
	vent.process_atmos()

	var/pressure = room.return_air().return_pressure()
	TEST_ASSERT(pressure > ONE_ATMOSPHERE * 1.5, "A circuit set the vent's external target to two atmospheres, but the vent left the room at [pressure] kPa")

/// The circuit scrubber control reports a siphoning scrubber as siphoning.
/datum/unit_test/atmos_air_alarm/circuit_scrubber_siphoning

/datum/unit_test/atmos_air_alarm/circuit_scrubber_siphoning/Run()
	var/mob/living/carbon/human/user = make_user()
	var/obj/machinery/airalarm/alarm = make_alarm()
	var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber = make_scrubber()
	press(user, alarm, "scrubbing", list("ref" = REF(scrubber), "val" = 0))

	var/obj/item/integrated_circuit/circuit = plug_circuit_into(alarm)
	var/obj/item/circuit_component/air_alarm_scrubbers/scrubber_control = locate() in circuit.attached_components
	TEST_ASSERT_NOTNULL(scrubber_control, "The air alarm didn't give the circuit a scrubber control component")
	scrubber_control.scrubbers.set_input(scrubber.id_tag)
	scrubber_control.request_update.set_input(COMPONENT_SIGNAL)
	TEST_ASSERT(scrubber_control.is_siphoning.value, "The circuit reported a siphoning scrubber as not siphoning")

/// A scrubber turned on by a circuit starts scrubbing the room.
/datum/unit_test/atmos_air_alarm/circuit_scrubber_starts_scrubbing

/datum/unit_test/atmos_air_alarm/circuit_scrubber_starts_scrubbing/Run()
	var/turf/open/room = run_loc_floor_bottom_left
	var/obj/machinery/airalarm/alarm = make_alarm()
	var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber = make_scrubber()
	var/co2_before = 5
	set_air(room, list(/datum/gas/oxygen = ONE_ATMOSPHERE * O2STANDARD, /datum/gas/nitrogen = ONE_ATMOSPHERE * N2STANDARD, /datum/gas/carbon_dioxide = co2_before))

	var/obj/item/integrated_circuit/circuit = plug_circuit_into(alarm)
	var/obj/item/circuit_component/air_alarm_scrubbers/scrubber_control = locate() in circuit.attached_components
	TEST_ASSERT_NOTNULL(scrubber_control, "The air alarm didn't give the circuit a scrubber control component")
	scrubber_control.scrubbers.set_input(scrubber.id_tag)
	scrubber_control.enable.set_input(COMPONENT_SIGNAL)

	// One pass of atmos processing over the things in the room that react to their turf's air.
	for(var/atom/sensitive as anything in SSair.atom_process.Copy())
		if(get_area(sensitive) == get_area(room))
			sensitive.process_exposure()

	var/datum/gas_mixture/air = room.return_air()
	var/co2_after = air.moles[/datum/gas/carbon_dioxide] * R_IDEAL_GAS_EQUATION * air.temperature / air.volume
	TEST_ASSERT(co2_after < co2_before * 0.98, "A scrubber turned on by a circuit didn't scrub any CO2 out of the room ([co2_after] kPa left)")

/// Turning a vent on or off from the air alarm with a vent that's no longer there does nothing.
/datum/unit_test/atmos_air_alarm/power_stale_vent

/datum/unit_test/atmos_air_alarm/power_stale_vent/Run()
	var/mob/living/carbon/human/user = make_user()
	var/obj/machinery/airalarm/alarm = make_alarm()
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = allocate(/obj/machinery/atmospherics/components/unary/vent_pump)
	var/vent_ref = REF(vent)
	qdel(vent)
	press(user, alarm, "power", list("ref" = vent_ref, "val" = 1))

/// Pressing "disconnect sensor" on an air alarm without a sensor does nothing.
/datum/unit_test/atmos_air_alarm/disconnect_missing_sensor

/datum/unit_test/atmos_air_alarm/disconnect_missing_sensor/Run()
	var/mob/living/carbon/human/user = make_user()
	var/obj/machinery/airalarm/alarm = make_alarm()
	press(user, alarm, "disconnect_sensor")

/// An air alarm ignores a threshold that isn't a number and keeps working.
/datum/unit_test/atmos_air_alarm/threshold_not_a_number

/datum/unit_test/atmos_air_alarm/threshold_not_a_number/Run()
	var/mob/living/carbon/human/user = make_user()
	var/obj/machinery/airalarm/alarm = make_alarm()
	press(user, alarm, "set_threshold", list("threshold" = "pressure", "threshold_type" = TLV_VAR_WARNING_MAX, "value" = "lots"))
	expose(run_loc_floor_bottom_left)
