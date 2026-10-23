///List of all vars that will not be copied over when using duplicate_object()
GLOBAL_LIST_INIT(duplicate_forbidden_vars, list(
	// these are grandfathered in, i'm too afraid to remove them
	"area", // unknown (possibly /obj/machinery/power/apc?)
	"group", // unknown
	"parent", // unknown
	nameof(/atom/movable::important_recursive_contents),
	nameof(/atom/movable::locs),
	nameof(/atom::active_hud_list),
	nameof(/atom::appearance),
	nameof(/atom::contents),
	nameof(/atom::hud_list),
	nameof(/atom::loc),
	nameof(/atom::managed_overlays),
	nameof(/atom::managed_vis_overlays),
	nameof(/atom::overlays),
	nameof(/atom::pixloc),
	nameof(/atom::reagents),
	nameof(/atom::update_on_z),
	nameof(/atom::verbs),
	nameof(/atom::x),
	nameof(/atom::y),
	nameof(/atom::z),
	nameof(/datum::_active_timers),
	nameof(/datum::_datum_components),
	nameof(/datum::_listen_lookup),
	nameof(/datum::_signal_procs),
	nameof(/datum::_status_traits),
	nameof(/datum::cooldowns),
	nameof(/datum::parent_type),
	nameof(/datum::tag),
	nameof(/datum::tgui_shared_states),
	nameof(/datum::type),
	nameof(/datum::vars),
	nameof(/mob/living/carbon::bodyparts),
	nameof(/mob/living/carbon::hand_bodyparts),
	nameof(/mob/living/carbon::implants),
	nameof(/mob/living/carbon::organs),
	nameof(/mob/living/carbon::organs_slot),
	nameof(/mob/living/carbon::overlays_standing),
	nameof(/mob/living/carbon::real_bodypart_cache),
	nameof(/mob/living/simple_animal::AIStatus),
	nameof(/mob/living::quirks),
	nameof(/mob/living::status_effects),
	nameof(/mob::actions),
	nameof(/mob::ckey),
	nameof(/mob::computer_id),
	nameof(/mob::held_items),
	nameof(/mob::key),
	nameof(/mob::lastKnownIP),
	nameof(/mob::stat),
	nameof(/turf::atmos_adjacent_turfs),
	// cables work out their links in Initialize(), copying them would claim links to cables that aren't there
	nameof(/obj/structure/cable::linked_dirs),
	nameof(/obj/structure/cable::is_fully_initialized),
))
GLOBAL_PROTECT(duplicate_forbidden_vars)

/// Called on the copy made by duplicate_object() once its vars have been transferred, for things that need more than that to work.
/atom/proc/on_duplicated(atom/original)
	return

/**
 * # duplicate_object
 *
 * Makes a copy of an item and transfers most vars over, barring GLOB.duplicate_forbidden_vars
 * Args:
 * original - Atom being duplicated
 * spawning_location - Turf where the duplicated atom will be spawned at.
 */
/proc/duplicate_object(atom/original, turf/spawning_location)
	RETURN_TYPE(original.type)
	if(!original)
		return

	if(ishuman(original))
		var/mob/living/carbon/human/original_human = original
		return original_human.make_full_human_copy(spawning_location)

	var/atom/made_copy = new original.type(spawning_location)

	for(var/atom_vars in (original.vars - GLOB.duplicate_forbidden_vars))
		var/var_value = original.vars[atom_vars]
		if(isdatum(var_value))
			continue // this would reference the original's object, that will break when it is used or deleted.

		if(islist(var_value))
			var/list/var_list = var_value
			var_value = var_list.Copy()

		made_copy.vars[atom_vars] = var_value

	made_copy.on_duplicated(original)
	return made_copy
