/datum/unit_test/atmos_ssair_null_entries
	abstract_type = /datum/unit_test/atmos_ssair_null_entries

/// A null left in the atmos machinery list by a hard deleted machine is skipped without erroring.
/datum/unit_test/atmos_ssair_null_entries/null_atmos_machine_is_skipped

/datum/unit_test/atmos_ssair_null_entries/null_atmos_machine_is_skipped/Run()
	// If SSair moves on past the null, the machine it processes next is this one.
	allocate(/obj/machinery/meter)
	SSair.atmos_machinery += null

	var/list/saved_run = SSair.currentrun
	var/error
	try
		SSair.process_atmos_machinery()
	catch(var/exception/caught)
		error = "[caught] ([caught.file]:[caught.line])"
	SSair.currentrun = saved_run
	SSair.atmos_machinery -= null

	TEST_ASSERT_NULL(error, "Processing atmos machinery with a null entry errored")

/// Atoms queued for atmos processing before a null entry still get processed.
/datum/unit_test/atmos_ssair_null_entries/null_atom_does_not_block_processing

/datum/unit_test/atmos_ssair_null_entries/null_atom_does_not_block_processing/Run()
	var/turf/open/hot_floor = run_loc_floor_bottom_left
	hot_floor.air.temperature = T0C + 2000
	var/obj/structure/grille/grille = allocate(/obj/structure/grille, hot_floor)
	var/start_integrity = grille.get_integrity()
	SSair.atom_process += null

	// Two SSair fires.
	var/list/saved_run = SSair.currentrun
	SSair.process_atoms()
	SSair.process_atoms()
	SSair.currentrun = saved_run
	SSair.atom_process -= null
	restore_atmos()

	TEST_ASSERT(grille.get_integrity() < start_integrity, "A grille in a 2273 K room was never processed by SSair")
