// The gas miner's static power setting. miner.dm undefines its own copy.
#define GASMINER_POWER_STATIC 1

/datum/unit_test/atmos_scanners_misc
	abstract_type = /datum/unit_test/atmos_scanners_misc

/// Places a cable with a well supplied powernet under the given turf and returns it.
/datum/unit_test/atmos_scanners_misc/proc/make_powered_cable(turf/location)
	var/obj/structure/cable/cable = allocate(/obj/structure/cable, location)
	var/datum/powernet/net = allocate(/datum/powernet)
	net.add_cable(cable)
	net.avail = 100000 // Small enough that single precision floats keep whole watts.
	return cable

/// Makes a working, unlocked air alarm. Alarms built at runtime start as an empty frame.
/datum/unit_test/atmos_scanners_misc/proc/make_alarm(turf/location = run_loc_floor_bottom_left)
	var/obj/machinery/airalarm/alarm = allocate(/obj/machinery/airalarm, location)
	alarm.buildstage = AIR_ALARM_BUILD_COMPLETE
	alarm.set_panel_open(FALSE)
	alarm.unlock()
	alarm.update_appearance()
	return alarm

/// Makes a mob that can use UIs without a client.
/datum/unit_test/atmos_scanners_misc/proc/make_user(turf/location = run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, location)
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	return user

/// Presses a button on a machine's UI as the given user.
/datum/unit_test/atmos_scanners_misc/proc/press(mob/user, obj/machinery/machine, action, list/params = list())
	var/datum/tgui/ui = allocate(/datum/tgui, user, machine, "test")
	ui.process_status()
	return machine.ui_act(action, params, ui, ui.state)

/// Replaces a turf's air with the given partial pressures (kPa).
/datum/unit_test/atmos_scanners_misc/proc/set_air(turf/open/location, list/gas_pressures, temperature = T20C)
	var/datum/gas_mixture/new_air = new(CELL_VOLUME)
	new_air.temperature = temperature
	for(var/gas_type in gas_pressures)
		new_air.add_gas(gas_type)
		new_air.moles[gas_type] = gas_pressures[gas_type] * CELL_VOLUME / (R_IDEAL_GAS_EQUATION * temperature)
	location.copy_air(new_air)
	return location.return_air()

/// Lets everything watching a turf know its air changed, the way atmos processing does.
/datum/unit_test/atmos_scanners_misc/proc/expose(turf/open/location)
	var/datum/gas_mixture/air = location.return_air()
	location.temperature_expose(air, air.temperature)

/// Returns TRUE if the atom shows an overlay whose icon state contains the given text.
/datum/unit_test/atmos_scanners_misc/proc/has_overlay(atom/thing, state_text)
	for(var/mutable_appearance/overlay as anything in thing.overlays)
		if(findtext(overlay.icon_state, state_text))
			return TRUE
	return FALSE

/// A gas miner set to a static power draw draws that much power.
/datum/unit_test/atmos_scanners_misc/miner_static_power_draw

/datum/unit_test/atmos_scanners_misc/miner_static_power_draw/Run()
	var/obj/structure/cable/cable = make_powered_cable(run_loc_floor_bottom_left)
	var/obj/machinery/atmospherics/miner/oxygen/miner = EASY_ALLOCATE()
	miner.power_draw = GASMINER_POWER_STATIC

	var/surplus_before = cable.surplus()
	miner.process(1)
	var/drawn = surplus_before - cable.surplus()

	TEST_ASSERT_EQUAL(drawn, miner.power_draw_static, "The gas miner drew the wrong amount of power on its static power setting")

/// A gas miner that is switched off and on again draws the same power as before.
/datum/unit_test/atmos_scanners_misc/miner_power_after_reactivation

/datum/unit_test/atmos_scanners_misc/miner_power_after_reactivation/Run()
	var/obj/structure/cable/cable = make_powered_cable(run_loc_floor_bottom_left)
	var/obj/machinery/atmospherics/miner/oxygen/miner = EASY_ALLOCATE()

	var/surplus_before = cable.surplus()
	miner.process(1)
	var/drawn_first = surplus_before - cable.surplus()

	miner.set_active(FALSE)
	miner.process(1)
	miner.set_active(TRUE)

	surplus_before = cable.surplus()
	miner.process(1)
	var/drawn_again = surplus_before - cable.surplus()

	TEST_ASSERT_EQUAL(drawn_again, drawn_first, "The gas miner drew a different amount of power after being switched off and on")

/// Asking a meter's circuit for data does not runtime when the meter isn't attached to a pipe.
/datum/unit_test/atmos_scanners_misc/meter_circuit_without_pipe

/datum/unit_test/atmos_scanners_misc/meter_circuit_without_pipe/Run()
	var/obj/machinery/meter/meter = EASY_ALLOCATE()
	var/obj/item/integrated_circuit/loaded/circuit = EASY_ALLOCATE()
	var/obj/item/usb_cable/usb = EASY_ALLOCATE()
	circuit.set_on(TRUE)
	usb.attached_circuit = circuit // Normally set by touching the cable to the circuit's shell.

	var/result = SEND_SIGNAL(meter, COMSIG_ATOM_USB_CABLE_TRY_ATTACH, usb, null)
	TEST_ASSERT(result & COMSIG_USB_CABLE_ATTACHED, "Couldn't connect the circuit to the meter")
	var/obj/item/circuit_component/atmos_meter/meter_component = locate() in circuit.attached_components
	TEST_ASSERT_NOTNULL(meter_component, "Connecting to the meter didn't add its circuit component")

	meter_component.request_data.set_input(COMPONENT_SIGNAL)

/// Closing AtmoZphere stops it from handling right-clicks on the PDA.
/datum/unit_test/atmos_scanners_misc/atmozphere_close_releases_pda

/datum/unit_test/atmos_scanners_misc/atmozphere_close_releases_pda/Run()
	var/mob/living/carbon/human/consistent/user = EASY_ALLOCATE()
	var/obj/item/modular_computer/pda/crew/atmos/pda = EASY_ALLOCATE()
	user.put_in_active_hand(pda, forced = TRUE)
	var/datum/computer_file/program/atmosscan/app = pda.find_file_by_name("atmosscan")
	TEST_ASSERT_NOTNULL(app, "The atmospherics PDA has no AtmoZphere app")

	TEST_ASSERT(pda.open_program(user, app, open_ui = FALSE), "Couldn't open AtmoZphere")
	app.ui_act("scantoggle", list())
	TEST_ASSERT(pda.attack_self_secondary(user), "AtmoZphere in click mode didn't scan on right-click")

	app.kill_program(user)
	TEST_ASSERT(!pda.attack_self_secondary(user), "AtmoZphere still scans on right-click after being closed")

/// Dropping one of two held gas analyzers keeps the storm detection the other one gives.
/datum/unit_test/atmos_scanners_misc/analyzer_storm_detection_with_two

/datum/unit_test/atmos_scanners_misc/analyzer_storm_detection_with_two/Run()
	var/mob/living/carbon/human/consistent/user = EASY_ALLOCATE()
	var/obj/item/analyzer/first = EASY_ALLOCATE()
	var/obj/item/analyzer/second = EASY_ALLOCATE()
	user.put_in_hands(first)
	user.put_in_hands(second)
	TEST_ASSERT(HAS_TRAIT(user, TRAIT_DETECT_STORM), "Holding gas analyzers didn't give storm detection")

	user.dropItemToGround(first)
	TEST_ASSERT_EQUAL(second.loc, user, "The second analyzer isn't held anymore")
	TEST_ASSERT(HAS_TRAIT(user, TRAIT_DETECT_STORM), "Dropping one of two gas analyzers removed storm detection")
/// A monitor-only atmos console can't be used to change the chamber's injector.
/datum/unit_test/atmos_scanners_misc/monitor_console_cant_control

/datum/unit_test/atmos_scanners_misc/monitor_console_cant_control/Run()
	var/mob/living/carbon/human/user = make_user()
	allocate(/obj/machinery/atmospherics/components/unary/outlet_injector, get_step(run_loc_floor_bottom_left, NORTH))
	allocate(/obj/machinery/air_sensor/incinerator_tank, get_step(get_step(run_loc_floor_bottom_left, NORTH), NORTH))
	var/obj/machinery/computer/atmos_control/nocontrol/incinerator/console = allocate(/obj/machinery/computer/atmos_control/nocontrol/incinerator, get_step(run_loc_floor_bottom_left, EAST))

	var/list/chamber = console.ui_data(user)["chambers"][1]
	TEST_ASSERT_NOTNULL(chamber["input_info"], "The console didn't find the chamber's injector")
	var/was_active = chamber["input_info"]["active"]

	press(user, console, "toggle_input", list("chamber" = ATMOS_GAS_MONITOR_INCINERATOR))

	chamber = console.ui_data(user)["chambers"][1]
	TEST_ASSERT_EQUAL(chamber["input_info"]["active"], was_active, "A monitor-only console toggled the chamber's injector")

/// The atmos alert console's screen switches to the priority alert when an alarm escalates.
/datum/unit_test/atmos_scanners_misc/alert_console_escalation

/datum/unit_test/atmos_scanners_misc/alert_console_escalation/Run()
	var/turf/open/room = run_loc_floor_bottom_left
	var/obj/machinery/computer/atmos_alert/console = allocate(/obj/machinery/computer/atmos_alert, run_loc_floor_top_right)
	make_alarm()

	set_air(room, list(/datum/gas/oxygen = ONE_ATMOSPHERE * O2STANDARD, /datum/gas/nitrogen = ONE_ATMOSPHERE * N2STANDARD - 7, /datum/gas/carbon_dioxide = 7))
	expose(room)
	console.process()
	TEST_ASSERT(has_overlay(console, "alert:1"), "The alert console didn't show a minor alert for a warning-level alarm")

	set_air(room, list(/datum/gas/oxygen = ONE_ATMOSPHERE * O2STANDARD, /datum/gas/nitrogen = ONE_ATMOSPHERE * N2STANDARD - 15, /datum/gas/carbon_dioxide = 15))
	expose(room)
	console.process()
	TEST_ASSERT(has_overlay(console, "alert:2"), "The alert console didn't switch to a priority alert when the alarm escalated to a hazard")

#undef GASMINER_POWER_STATIC
