/// Used for tracking mobs that have had synthetic blood injected into them.
/// The higher the synth content, the more nerfed the blood is for blood worms.
/// This decays over time while the mob is alive.
/datum/component/synth_blood
	// This has a performance improvement over COMPONENT_DUPE_HIGHLANDER as it skips creating a new component instance.
	dupe_mode = COMPONENT_DUPE_UNIQUE_PASSARGS

	/// 0-1 of how synthetic this mobs blood is right now.
	var/synth_content = 0
	/// 0-1 of how much of this mobs blood is unusable for blood worm growth right now (e.g. blood extracted from a blood worm host).
	var/unusable_content = 0

/datum/component/synth_blood/Initialize(new_synth_content = 0, new_unusable_content = 0)
	if (!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	if (new_synth_content <= 0 && new_unusable_content <= 0)
		return COMPONENT_REDUNDANT

	synth_content = clamp(new_synth_content, 0, 1)
	unusable_content = clamp(new_unusable_content, 0, 1)

	RegisterSignal(parent, COMSIG_LIVING_LIFE, PROC_REF(on_life))

/datum/component/synth_blood/InheritComponent(datum/component/synth_blood/new_component, i_am_original, new_synth_content, new_unusable_content)
	if (new_component)
		new_synth_content = new_component.synth_content
		new_unusable_content = new_component.unusable_content
	if (new_synth_content <= 0 && new_unusable_content <= 0)
		qdel(src)
		return

	synth_content = clamp(new_synth_content, 0, 1)
	unusable_content = clamp(new_unusable_content, 0, 1)

/datum/component/synth_blood/Destroy(force)
	UnregisterSignal(parent, COMSIG_LIVING_LIFE)
	return ..()

/datum/component/synth_blood/proc/on_life(mob/living/living_parent, seconds_per_tick, times_fired)
	SIGNAL_HANDLER
	if (synth_content <= 0 && unusable_content <= 0)
		qdel(src)
	else if (living_parent.stat != DEAD)
		// Ten minutes (or 600 seconds) to fully clear synth and unusable content from one to zero.
		synth_content = max(synth_content - (1/600) * seconds_per_tick, 0)
		unusable_content = max(unusable_content - (1/600) * seconds_per_tick, 0)
