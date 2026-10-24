/// Fallback shuttle
/obj/docking_port/mobile/emergency/backup
	name = "backup shuttle"
	shuttle_id = "backup"
	dir = EAST

/obj/docking_port/mobile/emergency/backup/Initialize(mapload)
	// We want to be a valid emergency shuttle
	// but not be the main one, keep whatever's set
	// valid.
	// backup shuttle ignores `timid` because THERE SHOULD BE NO TOUCHING IT
	var/current_emergency = SSshuttle.emergency
	. = ..()
	SSshuttle.emergency = current_emergency
	SSshuttle.backup_shuttle = src

/obj/docking_port/mobile/emergency/backup/Destroy(force)
	if(SSshuttle.backup_shuttle == src)
		SSshuttle.backup_shuttle = null
	return ..()

/// Monastery shuttle
/obj/docking_port/mobile/monastery
	name = "monastery pod"
	shuttle_id = "mining_common" //set so mining can call it down
	launch_status = UNLAUNCHED //required for it to launch as a pod.

/obj/docking_port/mobile/monastery/on_emergency_dock()
	if(launch_status == ENDGAME_LAUNCHED)
		initiate_docking(SSshuttle.getDock("pod_away")) //docks our shuttle as any pod would
		mode = SHUTTLE_ENDGAME

/// Build Your Own Shuttle (BYOS) kit
/obj/docking_port/mobile/emergency/shuttle_build

/obj/docking_port/mobile/emergency/shuttle_build/postregister(replace = FALSE)
	. = ..()
	var/obj/docking_port/stationary/station_dock = SSshuttle.getDock("emergency_home")
	if(!station_dock)
		return
	// Show the landing marks first, so whoever stands in the docking area has a chance to move.
	create_ripples(station_dock, SHUTTLE_RIPPLE_TIME)
	addtimer(CALLBACK(src, PROC_REF(dock_at_station), station_dock), SHUTTLE_RIPPLE_TIME)

/// Docks the chassis with the station once the landing marks have been shown.
/obj/docking_port/mobile/emergency/shuttle_build/proc/dock_at_station(obj/docking_port/stationary/station_dock)
	remove_ripples()
	if(QDELETED(src) || QDELETED(station_dock) || get_docked() == station_dock)
		return
	// Anything else that moved us in the meantime (a call, an admin) already took over.
	if(mode != SHUTTLE_IDLE)
		return
	initiate_docking(station_dock)

/// The chassis is already at the station, so its engines only affect the escape flight, not the call time.
/obj/docking_port/mobile/emergency/shuttle_build/get_call_engine_coeff()
	return 1

/obj/docking_port/mobile/emergency/shuttle_build/alter_engines(mod)
	// A call (or recall) in progress is not slowed or sped up by engines being added or removed.
	if(mode == SHUTTLE_CALL || mode == SHUTTLE_RECALL)
		if(!mod)
			return
		engine_coeff = get_engine_coeff(mod)
		current_engine_power = max(0, current_engine_power + mod)
		return
	return ..()

