ADMIN_VERB(fax_panel, R_ADMIN, "Fax Panel", "View and respond to faxes sent to CC.", ADMIN_CATEGORY_EVENTS)
	var/datum/fax_panel_interface/tgui = new(user.mob)
	tgui.ui_interact(user.mob)

/// Admin Fax Panel. Tool for sending fax messages faster.
/datum/fax_panel_interface
	/// List with available stamps
	var/stamp_list = list()

	/// Paper which admin edit and send.
	var/obj/item/paper/fax_paper = new /obj/item/paper(null)

	/// Default name of fax. Used when field with fax name not edited.
	var/sending_fax_name = "Secret"
	/// Default name of paper. paper - bluh-bluh. Used when field with paper name not edited.
	var/default_paper_name = "Standard Report"

/datum/fax_panel_interface/New()
	//Get all stamps
	for(var/stamp in valid_subtypesof(/obj/item/stamp))
		var/obj/item/stamp/real_stamp = new stamp()
		if(!istype(real_stamp, /obj/item/stamp/chameleon) && !istype(real_stamp, /obj/item/stamp/mod))
			var/stamp_detail = real_stamp.get_writing_implement_details()
			stamp_list += list(list(real_stamp.name, real_stamp.icon_state, stamp_detail["stamp_class"]))

	//Give our paper special status, to read everywhere.
	fax_paper.request_state = TRUE

/// Returns all the faxes an admin can send to. Looked up live, since faxes can be renamed, built or destroyed while the panel is open.
/datum/fax_panel_interface/proc/get_available_faxes()
	var/list/faxes = list()
	for(var/obj/machinery/fax/fax as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/fax))
		if(istype(fax, /obj/machinery/fax/admin))
			continue
		faxes += fax
	return faxes

/**
 * Return fax if name exists
 * Arguments:
 * * name - Name of fax what we try to find.
 */
/datum/fax_panel_interface/proc/get_fax_by_name(name)
	for(var/obj/machinery/fax/potential_fax as anything in get_available_faxes())
		if(potential_fax.fax_name == name)
			return potential_fax
	return null

/datum/fax_panel_interface/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AdminFax")
		ui.open()

/datum/fax_panel_interface/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/fax_panel_interface/ui_static_data(mob/user)
	var/list/data = list()

	data["faxes"] = list()
	data["stamps"] = list()

	for(var/stamp in stamp_list)
		data["stamps"] += list(stamp[1]) // send only names.

	for(var/obj/machinery/fax/another_fax as anything in get_available_faxes())
		data["faxes"] += list(another_fax.fax_name)

	return data

/datum/fax_panel_interface/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return

	if(!check_rights(R_ADMIN))
		return

	var/obj/machinery/fax/action_fax

	if(params["faxName"])
		action_fax = get_fax_by_name(params["faxName"])

	if(!action_fax && (action == "follow" || action == "send"))
		to_chat(ui.user, span_warning("No fax machine named \"[params["faxName"]]\" exists (it may have been renamed or destroyed). The fax list was refreshed."))
		update_static_data(ui.user, ui)
		return TRUE

	switch(action)

		if("follow")
			if(!isobserver(ui.user))
				SSadmin_verbs.dynamic_invoke_verb(ui.user, /datum/admin_verb/admin_ghost)

			ui.user.client?.admin_follow(action_fax)

		if("preview") // see saved variant
			if(!fax_paper)
				return
			fax_paper.ui_interact(ui.user)

		if("save") // save paper
			if(params["paperName"])
				default_paper_name = params["paperName"]
			if(params["fromWho"])
				sending_fax_name = params["fromWho"]

			fax_paper.clear_paper()
			var/stamp
			var/stamp_class

			for(var/needed_stamp in stamp_list)
				if(needed_stamp[1] == params["stamp"])
					stamp = needed_stamp[2]
					stamp_class = needed_stamp[3]
					break

			fax_paper.name = "paper — [default_paper_name]"
			fax_paper.add_raw_text(params["rawText"], advanced_html = TRUE)

			if(stamp)
				fax_paper.add_stamp(stamp_class, params["stampX"], params["stampY"], params["stampAngle"], stamp)

			fax_paper.update_static_data(ui.user) // OK, it's work, and update UI.

		if("send")
			//copy
			var/obj/item/paper/our_fax = fax_paper.copy(/obj/item/paper)
			our_fax.name = fax_paper.name
			//send
			action_fax.receive(our_fax, sending_fax_name)
			message_admins("[key_name_admin(ui.user)] has sent a custom fax message to [action_fax.name][ADMIN_FLW(action_fax)][ADMIN_SHOW_PAPER(fax_paper)].")
			log_admin("[key_name(ui.user)] has sent a custom fax message to [action_fax.name]")

		if("createPaper")
			var/obj/item/paper/our_paper = fax_paper.copy(/obj/item/paper, ui.user.loc)
			our_paper.name = fax_paper.name
