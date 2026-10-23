/// The minimum delay value that the delay component can have.
#define COMP_DELAY_MIN_VALUE 0.1

/**
 * # Delay Component
 *
 * Delays a signal by a specified duration.
 */
/obj/item/circuit_component/delay
	display_name = "Delay"
	desc = "A component that delays a signal by a specified duration. Timer gets reset when triggered again."
	category = "Utility"

	/// Amount to delay by
	var/datum/port/input/delay_amount
	/// Input signal to fire the delay
	var/datum/port/input/trigger
	/// Interrupts the delay before it fires
	var/datum/port/input/interrupt

	var/timer_id = TIMER_ID_NULL

	/// The output of the signal
	var/datum/port/output/output

/obj/item/circuit_component/delay/populate_ports()
	delay_amount = add_input_port("Delay", PORT_TYPE_NUMBER, trigger = null)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(trigger_delay))
	interrupt = add_input_port("Interrupt", PORT_TYPE_SIGNAL, trigger = PROC_REF(interrupt_timer))

	output = add_output_port("Result", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/delay/proc/trigger_delay(datum/port/input/port)
	CIRCUIT_TRIGGER
	// Always clear the previous timer first. TIMER_UNIQUE can't be relied on to do this: the signal's value
	// (world.time in seconds) is part of the callback's arguments, so each trigger would get a different hash
	// and the delayed signals would pile up instead of resetting.
	if(timer_id != TIMER_ID_NULL)
		deltimer(timer_id)
		timer_id = TIMER_ID_NULL
	var/delay = delay_amount.value
	if(delay > COMP_DELAY_MIN_VALUE)
		// Convert delay into deciseconds
		timer_id = addtimer(CALLBACK(src, PROC_REF(finish_delay), trigger.value), delay*10, TIMER_STOPPABLE)
	else
		output.set_output(trigger.value)

/// Called when the delay runs out.
/obj/item/circuit_component/delay/proc/finish_delay(signal_value)
	timer_id = TIMER_ID_NULL
	output.set_output(signal_value)

/obj/item/circuit_component/delay/proc/interrupt_timer(datum/port/input/port)
	CIRCUIT_TRIGGER
	if(timer_id != TIMER_ID_NULL)
		deltimer(timer_id)
		timer_id = TIMER_ID_NULL

#undef COMP_DELAY_MIN_VALUE
