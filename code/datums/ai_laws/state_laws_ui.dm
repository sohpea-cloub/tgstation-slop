/// Basic UI that Silicons can use to state their laws.
/datum/state_laws_ui
	/// Silicon that owns this UI.
	VAR_PRIVATE/mob/living/silicon/owner
	/// List of law texts the user has unchecked, and so will not be stated.
	/// Everything else (including laws added after the UI was last reset) is stated.
	VAR_PRIVATE/list/not_to_state = list()
	/// Whether the UI is locked to prevent multiple state law calls.
	VAR_PRIVATE/locked = FALSE

/datum/state_laws_ui/New(mob/living/silicon/owner)
	src.owner = owner

/// Resets the selection so every law is stated again.
/// Call this when changing the silicon's lawset entirely
/datum/state_laws_ui/proc/reset_stated_laws()
	not_to_state.Cut()

/datum/state_laws_ui/Destroy()
	owner = null
	return ..()

/datum/state_laws_ui/proc/get_laws_ui_data()
	var/list/law_data = list()
	var/zeroth = iscyborg(owner) && owner.laws.zeroth_borg || owner.laws.zeroth
	if(zeroth)
		law_data += list(law_to_ui_data(zeroth, 0, "hacked"))
	for(var/law in owner.laws.hacked)
		law_data += list(law_to_ui_data(law, ion_num(), "hacked"))
	var/number = 1
	for(var/law, is_ioned in owner.laws.inherent)
		law_data += list(law_to_ui_data(law, is_ioned ? ion_num() : number++, "core"))
	for(var/law, is_ioned in owner.laws.supplied)
		law_data += list(law_to_ui_data(law, is_ioned ? ion_num() : number++, "supplied"))
	return law_data

/datum/state_laws_ui/proc/law_to_ui_data(law_text, law_number, law_type)
	return list(
		"text" = law_text,
		"number" = law_number,
		"type" = law_type
	)

/datum/state_laws_ui/ui_close(mob/user)
	reset_stated_laws()

/datum/state_laws_ui/ui_state(mob/user)
	return GLOB.not_incapacitated_state

/datum/state_laws_ui/ui_interact(mob/user, datum/tgui/ui)
	ASSERT(user == owner, "Non-owner [user] tried to access [owner]'s [type] UI.")
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "StateLawUi")
		ui.open()

/datum/state_laws_ui/ui_data(mob/user)
	var/list/data = list()

	data["locked"] = locked
	var/list/all_laws = get_laws_ui_data()
	var/list/stated_laws = list()
	for(var/list/law_data as anything in all_laws)
		if(!(law_data["text"] in not_to_state))
			stated_laws += law_data["text"]
	data["stated_laws"] = stated_laws
	data["all_laws"] = all_laws

	return data

/datum/state_laws_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("toggle_stated")
			var/law = params["law"]
			if(law)
				if(law in not_to_state)
					not_to_state -= law
				else
					not_to_state += law
			return TRUE
		if("state_laws")
			state_laws()
			SStgui.close_uis(src)
			return TRUE

/datum/state_laws_ui/proc/state_laws(force_all_laws = FALSE)
	set waitfor = FALSE

	if(locked)
		return

	locked = TRUE

	var/forced_log_message = "stating laws[force_all_laws ? ", forced" : ""]"
	// Create a cache of our laws before we start, so if they're changed mid-statement, nothing strange happens
	var/lawcache_zeroth = iscyborg(owner) && owner.laws.zeroth_borg || owner.laws.zeroth
	var/list/lawcache_hacked = owner.laws.hacked.Copy()
	var/list/lawcache_inherent = owner.laws.inherent.Copy()
	var/list/lawcache_supplied = owner.laws.supplied.Copy()
	var/list/not_to_state_cached = not_to_state.Copy()

	//"radiomod" is inserted before a hardcoded message to change if and how it is handled by an internal radio.
	owner.say("[owner.radiomod] Current Active Laws:", forced = forced_log_message)
	sleep(1 SECONDS)

	if (lawcache_zeroth && (force_all_laws || !(lawcache_zeroth in not_to_state_cached)))
		owner.say("[owner.radiomod] 0. [lawcache_zeroth]", forced = forced_log_message, message_mods = list(MODE_SEQUENTIAL = TRUE, SAY_MOD_VERB = "states"))
		sleep(1 SECONDS)

	for (var/law in lawcache_hacked)
		if (force_all_laws || !(law in not_to_state_cached))
			owner.say("[owner.radiomod] [ion_num()]. [law]", forced = forced_log_message, message_mods = list(MODE_SEQUENTIAL = TRUE, SAY_MOD_VERB = "states"))
			sleep(1 SECONDS)

	var/number = 1
	for (var/law_text, is_ioned in lawcache_inherent)
		if (force_all_laws || !(law_text in not_to_state_cached))
			owner.say("[owner.radiomod] [is_ioned ? ion_num() : number]. [law_text]", forced = forced_log_message, message_mods = list(MODE_SEQUENTIAL = TRUE, SAY_MOD_VERB = "states"))
			if(!is_ioned)
				number++
			sleep(1 SECONDS)

	for (var/law_text, is_ioned in lawcache_supplied)
		if (force_all_laws || !(law_text in not_to_state_cached))
			owner.say("[owner.radiomod] [is_ioned ? ion_num() : number]. [law_text]", forced = forced_log_message, message_mods = list(MODE_SEQUENTIAL = TRUE, SAY_MOD_VERB = "states"))
			if(!is_ioned)
				number++
			sleep(1 SECONDS)

	addtimer(VARSET_CALLBACK(src, locked, FALSE), 3 SECONDS)
