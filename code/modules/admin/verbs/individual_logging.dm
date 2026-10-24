/// Shows the individual logs of a mob, or, with no mob (it was deleted, e.g. the player disconnected and their body is gone),
/// of the persistent client of target_ckey, which keeps the logs the player made across mobs and disconnects.
/proc/show_individual_logging_panel(mob/M, source = LOGSRC_CKEY, type = INDIVIDUAL_ATTACK_LOG, target_ckey)
	var/datum/persistent_client/persistent_client
	if(M)
		if(!ismob(M))
			return
		target_ckey = M.ckey
		persistent_client = M.persistent_client
	else
		target_ckey = ckey(target_ckey)
		persistent_client = GLOB.persistent_clients_by_ckey[target_ckey]
		if(!persistent_client)
			return
		source = LOGSRC_CKEY

	var/ntype = text2num(type)

	//Add client links
	var/list/dat = list()
	if(target_ckey)
		dat += "<center><p>Ckey</p></center>"
		dat += "<center>"
		dat += individual_logging_panel_link(M, INDIVIDUAL_GAME_LOG, LOGSRC_CKEY, "Game Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_ATTACK_LOG, LOGSRC_CKEY, "Attack Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_SAY_LOG, LOGSRC_CKEY, "Say Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_EMOTE_LOG, LOGSRC_CKEY, "Emote Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_COMMS_LOG, LOGSRC_CKEY, "Comms Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_OOC_LOG, LOGSRC_CKEY, "OOC Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_SHOW_ALL_LOG, LOGSRC_CKEY, "Show All", source, ntype, target_ckey)
		dat += "</center>"
	else
		dat += "<p> No ckey attached to mob </p>"

	dat += "<hr style='background:#000000; border:0; height:1px'>"
	dat += "<center><p>Mob</p></center>"
	//Add the links for the mob specific log
	if(!M)
		dat += "<p> The mob no longer exists </p>"
	else
		dat += "<center>"
		dat += individual_logging_panel_link(M, INDIVIDUAL_GAME_LOG, LOGSRC_MOB, "Game Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_ATTACK_LOG, LOGSRC_MOB, "Attack Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_SAY_LOG, LOGSRC_MOB, "Say Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_EMOTE_LOG, LOGSRC_MOB, "Emote Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_COMMS_LOG, LOGSRC_MOB, "Comms Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_OOC_LOG, LOGSRC_MOB, "OOC Log", source, ntype, target_ckey)
		dat += " | "
		dat += individual_logging_panel_link(M, INDIVIDUAL_SHOW_ALL_LOG, LOGSRC_MOB, "Show All", source, ntype, target_ckey)
		dat += "</center>"

	dat += "<hr style='background:#000000; border:0; height:1px'>"

	var/list/log_source = M?.logging
	if(source == LOGSRC_CKEY && persistent_client)
		log_source = persistent_client.logging

	var/list/concatenated_logs = list()
	for(var/log_type in log_source)
		var/nlog_type = text2num(log_type)
		if(nlog_type & ntype)
			var/list/all_the_entrys = log_source[log_type]
			for(var/entry in all_the_entrys)
				concatenated_logs += "<b>[entry]</b><br>[all_the_entrys[entry]]"

	if(length(concatenated_logs))
		sortTim(concatenated_logs, cmp = GLOBAL_PROC_REF(cmp_text_dsc)) //Sort by timestamp.
		dat += "<font size=2px>"
		dat += concatenated_logs.Join("<br>")
		dat += "</font>"

	var/datum/browser/popup = new(usr, "invidual_logging_[M ? key_name(M) : target_ckey]", "Individual Logs", 600, 600)
	popup.set_content(dat.Join())
	popup.open()

/proc/individual_logging_panel_link(mob/M, log_type, log_src, label, selected_src, selected_type, target_ckey)
	var/slabel = label
	if(selected_type == log_type && selected_src == log_src)
		slabel = "<b>\[[label]\]</b>"
	//This is necessary because num2text drops digits and rounds on big numbers. If more defines get added in the future it could break again.
	log_type = num2text(log_type, MAX_BITFLAG_DIGITS)
	var/target = M ? "individuallog=[REF(M)]" : "individuallogckey=[target_ckey]"
	return "<a href='byond://?_src_=holder;[HrefToken()];[target];log_type=[log_type];log_src=[log_src]'>[slabel]</a>"

ADMIN_VERB(show_ckey_logs, R_ADMIN, "Show Ckey Logs", "Show the individual logs of a ckey, even when the player disconnected and has no mob left.", ADMIN_CATEGORY_GAME)
	var/list/ckeys = sort_list(assoc_to_keys(GLOB.persistent_clients_by_ckey))
	if(!length(ckeys))
		to_chat(user, span_warning("No player has connected yet."), confidential = TRUE)
		return
	var/chosen_ckey = tgui_input_list(user, "Pick a ckey", "Show Ckey Logs", ckeys)
	if(!chosen_ckey)
		return
	log_admin("[key_name(user)] checked the individual logs of [chosen_ckey].")
	var/datum/persistent_client/persistent_client = GLOB.persistent_clients_by_ckey[chosen_ckey]
	show_individual_logging_panel(persistent_client?.mob, LOGSRC_CKEY, INDIVIDUAL_ATTACK_LOG, chosen_ckey)
