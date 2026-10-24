#define HOURGLASS_STATES 7 //Remember to update if you change the sprite

/obj/item/hourglass
	name = "hourglass"
	desc = "Nanotrasen patented gravity invariant hourglass. Guaranteed to flow perfectly under any conditions."
	var/obj/effect/countdown/hourglass/countdown
	var/time = 1 MINUTES
	var/finish_time //So countdown doesn't need to fiddle with timers
	var/timing_id //if present we're timing
	var/step_timer_id //looping timer that advances the sand sprite while timing
	var/hand_activated = TRUE
	icon = 'icons/obj/toys/hourglass.dmi'
	icon_state = "hourglass_idle"

/obj/item/hourglass/Initialize(mapload)
	. = ..()
	countdown = new(src)

/obj/item/hourglass/attack_self(mob/user)
	. = ..()
	if(hand_activated)
		toggle(user)

/obj/item/hourglass/proc/toggle(mob/user)
	if(!timing_id)
		to_chat(user,span_notice("You flip the [src]."))
		start()
		flick("hourglass_flip",src)
	else
		to_chat(user,span_notice("You stop the [src].")) //Sand magically flows back because that's more convinient to use.
		stop()

/obj/item/hourglass/update_icon_state()
	if(!timing_id)
		icon_state = "hourglass_idle"
		return ..()
	// Derive the sand level from the time left instead of animate(): an animation is lost whenever the
	// item leaves and re-enters a client's view (picked up and dropped, or seen late), leaving the final frame.
	var/step_time = time / HOURGLASS_STATES
	var/step = clamp(HOURGLASS_STATES - ceil((finish_time - world.time) / step_time) + 1, 1, HOURGLASS_STATES)
	icon_state = "hourglass_[step]"
	return ..()

/obj/item/hourglass/proc/start()
	finish_time = world.time + time
	timing_id = addtimer(CALLBACK(src, PROC_REF(finish)), time, TIMER_STOPPABLE)
	countdown.start()
	step_timer_id = addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, update_appearance)), time / HOURGLASS_STATES, TIMER_STOPPABLE | TIMER_LOOP)
	update_appearance()

/obj/item/hourglass/proc/stop()
	if(timing_id)
		deltimer(timing_id)
		timing_id = null
	if(step_timer_id)
		deltimer(step_timer_id)
		step_timer_id = null
	countdown.stop()
	finish_time = null
	update_appearance()

/obj/item/hourglass/proc/finish()
	visible_message(span_notice("[src] stops."))
	stop()

/obj/item/hourglass/Destroy()
	if(step_timer_id)
		deltimer(step_timer_id)
		step_timer_id = null
	QDEL_NULL(countdown)
	. = ..()

//Admin events zone.
/obj/item/hourglass/admin
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	anchored = TRUE
	hand_activated = FALSE

/obj/item/hourglass/admin/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(user.client && user.client.holder)
		toggle(user)

/obj/item/hourglass/admin/attack_ghost(mob/user)
	if(user.client && user.client.holder)
		toggle(user)

#undef HOURGLASS_STATES
