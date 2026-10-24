///Burdened grants some mutations upon injuring yourself sufficiently
/datum/brain_trauma/special/burdened
	name = "Flagellating Compulsions"
	desc = "Patient feels compelled to injure themselves in various incapacitating and horrific ways. \
		There seems to be an odd genetic \"sequence\" gradually expressed upon following these compulsions."
	scan_desc = "damaged frontal lobe"
	symptoms = "Experiences an overwhelming compulsion to self-harm, often engaging in behaviors that lead to significant physical injury. \
		This compulsion is driven by an intense psychological need to feel pain and suffering, \
		believing that through this self-inflicted harm, they can achieve a deeper understanding of universal truths and the nature of existence."
	gain_text = span_notice("You feel burdened!")
	lose_text = span_warning("You no longer feel the need to burden yourself!")
	random_gain = FALSE
	/// goes from 0 to 9 (but can be beyond 9, just does nothing) and gives rewards. increased by disabling yourself with debuffs
	var/burden_level = 0
	/// Static list of organ slots that add burden when lost
	var/static/list/burden_organ_slots = list(
		ORGAN_SLOT_BRAIN,
		ORGAN_SLOT_HEART,
		ORGAN_SLOT_LUNGS,
		ORGAN_SLOT_EYES,
		ORGAN_SLOT_EARS,
		ORGAN_SLOT_TONGUE,
		ORGAN_SLOT_LIVER,
		ORGAN_SLOT_STOMACH,
	)

/datum/brain_trauma/special/burdened/on_gain()
	RegisterSignal(owner, COMSIG_CARBON_GAIN_ORGAN, PROC_REF(organ_added_burden))
	RegisterSignal(owner, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(organ_removed_burden))

	RegisterSignal(owner, COMSIG_CARBON_ATTACH_LIMB, PROC_REF(limbs_added_burden))
	RegisterSignal(owner, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(limbs_removed_burden))

	RegisterSignal(owner, COMSIG_CARBON_GAIN_ADDICTION, PROC_REF(addict_added_burden))
	RegisterSignal(owner, COMSIG_CARBON_LOSE_ADDICTION, PROC_REF(addict_removed_burden))

	RegisterSignal(owner, COMSIG_CARBON_GAIN_MUTATION, PROC_REF(mutation_added_burden))
	RegisterSignal(owner, COMSIG_CARBON_LOSE_MUTATION, PROC_REF(mutation_removed_burden))

	RegisterSignal(owner, COMSIG_CARBON_GAIN_TRAUMA, PROC_REF(trauma_added_burden))
	RegisterSignal(owner, COMSIG_CARBON_LOSE_TRAUMA, PROC_REF(trauma_removed_burden))

	RegisterSignal(owner, COMSIG_LIVING_REVIVE, PROC_REF(owner_revived))

	for (var/i in 1 to count_burden())
		update_burden(TRUE, silent = TRUE)

	queue_burden_recalculation()
	return ..()

/datum/brain_trauma/special/burdened/on_lose()
	UnregisterSignal(owner, list(
		COMSIG_CARBON_GAIN_ORGAN,
		COMSIG_CARBON_LOSE_ORGAN,
		COMSIG_CARBON_ATTACH_LIMB,
		COMSIG_CARBON_REMOVE_LIMB,
		COMSIG_CARBON_GAIN_ADDICTION,
		COMSIG_CARBON_LOSE_ADDICTION,
		COMSIG_CARBON_GAIN_MUTATION,
		COMSIG_CARBON_LOSE_MUTATION,
		COMSIG_CARBON_GAIN_TRAUMA,
		COMSIG_CARBON_LOSE_TRAUMA,
		COMSIG_LIVING_REVIVE,
	))

	for (var/i in 1 to burden_level)
		update_burden(FALSE, silent = TRUE)

	return ..()

/// Works out what burden_level the owner's current condition is worth: every missing vital organ, missing limb, addiction, negative mutation and severe trauma counts for one.
/datum/brain_trauma/special/burdened/proc/count_burden()
	. = 0
	if(!owner)
		return
	for (var/burden_slot in burden_organ_slots)
		if (!owner.get_organ_slot(burden_slot) && is_burdensome_organ(owner, burden_slot, null, FALSE))
			.++

	var/list/missing_limbs = owner.get_missing_limbs()
	. += length(missing_limbs) + length(owner.mind?.active_addictions)

	if (owner.dna)
		for (var/datum/mutation/mutation in owner.dna.mutations)
			if (mutation.quality == NEGATIVE)
				.++

	for (var/datum/brain_trauma/severe/trauma in owner.get_traumas())
		.++

/**
 * Queues a recalculation of burden_level from the owner's actual condition on the next tick.
 * Burden used to be counted up and down by 1 per event, which drifted from reality whenever something
 * changed the body without sending a matching event (limbs and organs regrown by a full heal or revival, ...)
 * and left the owner at a level that no longer matched their rewards.
 * It's deferred so it doesn't see a half finished change (signals are sent before a mutation is added or removed, etc.) and so a burst of changes only costs one recount.
 */
/datum/brain_trauma/special/burdened/proc/queue_burden_recalculation()
	addtimer(CALLBACK(src, PROC_REF(recalculate_burden)), 1, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_DELETE_ME)

/// Brings burden_level in line with count_burden(), and makes sure the rewards for that level are in place.
/datum/brain_trauma/special/burdened/proc/recalculate_burden()
	if(QDELETED(src) || QDELETED(owner))
		return
	var/target = count_burden()
	while(burden_level != target)
		var/increase = burden_level < target
		// only the last step talks, a jump of several levels at once would spam
		update_burden(increase, silent = (burden_level + (increase ? 1 : -1) != target))
		if(QDELETED(src))
			return
	sync_burden_rewards()

/// Gives or takes the mutations that burden_level should have, whether or not that level was just crossed (they can be lost without it going down, e.g. telekinesis when losing your head)
/datum/brain_trauma/special/burdened/proc/sync_burden_rewards()
	var/datum/dna/dna = owner?.dna
	if(!dna)
		return
	if(burden_level >= 3)
		grant_burden_mutation(/datum/mutation/telepathy)
		grant_burden_mutation(/datum/mutation/unintelligible)
		if(!owner.get_filter("burden_outline"))
			owner.add_filter("burden_outline", 9, list("type" = "outline", "color" = "#6c6eff"))
	else
		dna.remove_mutation(/datum/mutation/telepathy, MUTATION_SOURCE_BURDENED_TRAUMA)
		dna.remove_mutation(/datum/mutation/unintelligible, MUTATION_SOURCE_BURDENED_TRAUMA)
		owner.remove_filter("burden_outline")
	if(burden_level >= 6)
		grant_burden_mutation(/datum/mutation/telekinesis)
		grant_burden_mutation(/datum/mutation/mindreader)
	else
		dna.remove_mutation(/datum/mutation/telekinesis, MUTATION_SOURCE_BURDENED_TRAUMA)
		dna.remove_mutation(/datum/mutation/mindreader, MUTATION_SOURCE_BURDENED_TRAUMA)

/// Adds a mutation from this trauma unless it's already ours or the owner can't have it right now (dead, or missing the limb it needs), so we can try again later without nagging
/datum/brain_trauma/special/burdened/proc/grant_burden_mutation(mutation_type)
	var/datum/dna/dna = owner.dna
	var/datum/mutation/existing = dna.get_mutation(mutation_type)
	if(existing && (MUTATION_SOURCE_BURDENED_TRAUMA in existing.sources))
		return
	var/datum/mutation/prototype = GET_INITIALIZED_MUTATION(mutation_type)
	if(owner.stat == DEAD || (prototype.limb_req && !owner.get_bodypart(prototype.limb_req)))
		return
	dna.add_mutation(mutation_type, MUTATION_SOURCE_BURDENED_TRAUMA)

/// Burden is recalculated once the owner is back on their feet, rewards can't be given to a corpse
/datum/brain_trauma/special/burdened/proc/owner_revived(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	queue_burden_recalculation()

/**
 * Called by hooked signals whenever burden_level var needs to go up or down by 1.
 * Sends messages on burden level, gives powers and takes them if needed, etc
 *
 * Arguments:
 * * increase: whether to tick burden_level up or down 1
 * * silent: if TRUE, this does not print out any to_chats
 */
/datum/brain_trauma/special/burdened/proc/update_burden(increase, silent = FALSE)
	var/datum/dna/dna = owner?.dna
	if(!dna)
		qdel(src)
		return
	//adjust burden
	burden_level = increase ? burden_level + 1 : burden_level - 1
	if(burden_level < 0)
		burden_level = 0
	//send a message and handle rewards
	switch(burden_level)
		if(0)
			if (!silent)
				to_chat(owner, span_warning("You feel no weight on your shoulders. You are not feeling [GLOB.deity]'s suffering."))
		if(1)
			if (!silent)
				if(increase)
					to_chat(owner, span_notice("You begin to feel the scars on [GLOB.deity]. You must continue to burden yourself."))
				else
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You are barely feeling [GLOB.deity]'s suffering."))
		if(2)
			if(increase)
				if (!silent)
					to_chat(owner, span_notice("You have done well to understand [GLOB.deity]. You are almost at a breakthrough."))
			else
				if (!silent)
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You have lost some universal truths."))
				dna.remove_mutation(/datum/mutation/telepathy, MUTATION_SOURCE_BURDENED_TRAUMA)
				dna.remove_mutation(/datum/mutation/unintelligible, MUTATION_SOURCE_BURDENED_TRAUMA)
				owner.remove_filter("burden_outline")
		if(3)
			if(increase)
				if (!silent)
					to_chat(owner, span_notice("Your suffering is only a fraction of [GLOB.deity]'s, and yet the universal truths are coming to you."))
				dna.add_mutation(/datum/mutation/telepathy, MUTATION_SOURCE_BURDENED_TRAUMA)
				dna.add_mutation(/datum/mutation/unintelligible, MUTATION_SOURCE_BURDENED_TRAUMA)
				owner.add_filter("burden_outline", 9, list("type" = "outline", "color" = "#6c6eff"))
			else
				if (!silent)
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You feel like you're about to forget."))
		if(4)
			if (!silent)
				if(increase)
					to_chat(owner, span_notice("It hurts, each ounce of pain a lesson told. How does [GLOB.deity] bear this weight?"))
				else
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You're growing further from your goal."))
		if(5)
			if(increase)
				if (!silent)
					to_chat(owner, span_notice("Your body is a canvas of loss. You are almost at a breakthrough."))
			else
				if (!silent)
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You have lost some universal truths."))
				dna.remove_mutation(/datum/mutation/telekinesis, MUTATION_SOURCE_BURDENED_TRAUMA)
				dna.remove_mutation(/datum/mutation/mindreader, MUTATION_SOURCE_BURDENED_TRAUMA)
		if(6)
			if(increase)
				if (!silent)
					to_chat(owner, span_notice("Your suffering is respectful, your scars immaculate. More universal truths are clear, but you do not fully understand yet."))
				dna.add_mutation(/datum/mutation/telekinesis, MUTATION_SOURCE_BURDENED_TRAUMA)
				dna.add_mutation(/datum/mutation/mindreader, MUTATION_SOURCE_BURDENED_TRAUMA)
			else
				if (!silent)
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You feel like you're about to forget."))
		if(7)
			if (!silent)
				if(increase)
					to_chat(owner, span_notice("The weight on your shoulders is immense. [GLOB.deity] is shattered across the cosmos."))
				else
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You're growing further from your goal."))
		if(8)
			if (!silent)
				if(increase)
					to_chat(owner, span_notice("You're on the cusp of another breakthrough. [GLOB.deity] lost everything."))
				else
					to_chat(owner, span_warning("The weight on your shoulders feels lighter. You have lost some universal truths."))
		if(9)
			if(increase)
				if (!silent)
					to_chat(owner, span_notice("You have finally broken yourself enough to understand [GLOB.deity]. It's all so clear to you."))
				var/mob/living/carbon/human/knower = owner
				if(!istype(knower))
					return
				INVOKE_ASYNC(knower, TYPE_PROC_REF(/mob/living/carbon/human, slow_psykerize))

/datum/brain_trauma/special/burdened/proc/is_burdensome_organ(mob/burdened, organ_slot, obj/item/organ/organ, special)
	if(special) //aheals
		return
	if(!ishuman(burdened))
		return //mobs that don't care about organs
	var/mob/living/carbon/human/burdened_human = burdened
	var/datum/species/burdened_species = burdened_human.dna?.species
	if(!burdened_species)
		return

	/// only organs that are slotted in these count. because there's a lot of useless organs to cheese with.
	var/list/critical_slots = burden_organ_slots.Copy()
	if(!burdened_species.mutantheart)
		critical_slots -= ORGAN_SLOT_HEART
	if(!burdened_species.mutanttongue)
		critical_slots -= ORGAN_SLOT_TONGUE
	if(!burdened_species.mutantlungs)
		critical_slots -= ORGAN_SLOT_LUNGS
	if(!burdened_species.mutantstomach)
		critical_slots -= ORGAN_SLOT_STOMACH
	if(!burdened_species.mutantliver)
		critical_slots -= ORGAN_SLOT_LIVER

	if(!(organ_slot in critical_slots))
		return FALSE
	if(istype(organ, /obj/item/organ/eyes))
		var/obj/item/organ/eyes/eyes = organ
		if(eyes.tint < TINT_BLIND) //unless you were already blinded by them (flashlight eyes), this is adding burden!
			return TRUE
		return FALSE
	return TRUE

/// Signal to recalculate burden_level (see recalculate_burden proc) if an organ is added
/datum/brain_trauma/special/burdened/proc/organ_added_burden(mob/burdened, obj/item/organ/new_organ, special)
	SIGNAL_HANDLER

	if(new_organ.slot in burden_organ_slots)
		queue_burden_recalculation() //the recount decides whether it matters (a replacement organ inserted as special changes nothing, a regrown one does)

/// Signal to recalculate burden_level (see recalculate_burden proc) if an organ is removed
/datum/brain_trauma/special/burdened/proc/organ_removed_burden(mob/burdened, obj/item/organ/old_organ, special)
	SIGNAL_HANDLER

	if(old_organ.slot in burden_organ_slots)
		queue_burden_recalculation()

/// Signal to recalculate burden_level (see recalculate_burden proc) if a limb is added
/datum/brain_trauma/special/burdened/proc/limbs_added_burden(datum/source, obj/item/bodypart/new_limb, special)
	SIGNAL_HANDLER

	queue_burden_recalculation() //instaswapped limbs (special) don't change the count, regrown ones do

/// Signal to recalculate burden_level (see recalculate_burden proc) if a limb is removed
/datum/brain_trauma/special/burdened/proc/limbs_removed_burden(datum/source, obj/item/bodypart/old_limb, special, dismembered)
	SIGNAL_HANDLER

	queue_burden_recalculation() //instaswapped limbs (special) don't change the count, regrown ones do

/// Signal to recalculate burden_level (see recalculate_burden proc) if an addiction is added
/datum/brain_trauma/special/burdened/proc/addict_added_burden(datum/addiction/new_addiction, datum/mind/addict_mind)
	SIGNAL_HANDLER

	queue_burden_recalculation()

/// Signal to recalculate burden_level (see recalculate_burden proc) if an addiction is removed
/datum/brain_trauma/special/burdened/proc/addict_removed_burden(datum/addiction/old_addiction, datum/mind/nonaddict_mind)
	SIGNAL_HANDLER

	queue_burden_recalculation()

/// Signal to recalculate burden_level (see recalculate_burden proc) if a mutation is added
/datum/brain_trauma/special/burdened/proc/mutation_added_burden(mob/living/carbon/burdened, datum/mutation/mutation_type, class)
	SIGNAL_HANDLER

	if(initial(mutation_type.quality) == NEGATIVE)
		queue_burden_recalculation()

/// Signal to recalculate burden_level (see recalculate_burden proc) if a mutation is removed
/datum/brain_trauma/special/burdened/proc/mutation_removed_burden(mob/living/carbon/burdened, datum/mutation/mutation_type)
	SIGNAL_HANDLER

	if(initial(mutation_type.quality) == NEGATIVE)
		queue_burden_recalculation()

/// Signal to recalculate burden_level (see recalculate_burden proc) if a trauma is added
/datum/brain_trauma/special/burdened/proc/trauma_added_burden(mob/living/carbon/burdened, datum/brain_trauma/trauma_added)
	SIGNAL_HANDLER

	if(istype(trauma_added, /datum/brain_trauma/severe))
		queue_burden_recalculation()

/// Signal to recalculate burden_level (see recalculate_burden proc) if a trauma is removed
/datum/brain_trauma/special/burdened/proc/trauma_removed_burden(mob/living/carbon/burdened, datum/brain_trauma/trauma_removed)
	SIGNAL_HANDLER

	if(istype(trauma_removed, /datum/brain_trauma/severe))
		queue_burden_recalculation()
