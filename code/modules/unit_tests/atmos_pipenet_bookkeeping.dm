/datum/unit_test/atmos_pipenet_bookkeeping
	abstract_type = /datum/unit_test/atmos_pipenet_bookkeeping
	/// The human who wrenches down every pipe built by build()
	var/mob/living/carbon/human/builder
	/// The builder's wrench
	var/obj/item/wrench/builder_wrench

/// Returns the test room turf at the given offset from the bottom left corner
/datum/unit_test/atmos_pipenet_bookkeeping/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Returns a human standing in the corner of the test room, holding the given tool
/datum/unit_test/atmos_pipenet_bookkeeping/proc/make_engineer(obj/item/tool)
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent)
	if(tool)
		engineer.put_in_hands(tool, forced = TRUE)
	return engineer

/// Drops a pipe fitting on a turf, the same way the RPD dispenses one
/datum/unit_test/atmos_pipenet_bookkeeping/proc/make_fitting(turf/where, pipe_type, dir = SOUTH, init_dir = ALL_CARDINALS, color = ATMOS_COLOR_OMNI)
	var/obj/machinery/atmospherics/path = pipe_type
	var/fitting_type = initial(path.construction_type) || /obj/item/pipe
	return new fitting_type(where, pipe_type, dir, null, color, ispath(pipe_type, /obj/machinery/atmospherics/pipe/smart) ? init_dir : null)

/// Dispenses a fitting and wrenches it down, like an RPD in wrench mode, then lets SSair rebuild the pipenets unless told not to
/datum/unit_test/atmos_pipenet_bookkeeping/proc/build(dx, dy, pipe_type, dir = SOUTH, init_dir = ALL_CARDINALS, color = ATMOS_COLOR_OMNI, rebuild = TRUE)
	var/turf/where = spot(dx, dy)
	var/obj/item/pipe/fitting = make_fitting(where, pipe_type, dir, init_dir, color)
	if(isnull(builder))
		builder_wrench = allocate(/obj/item/wrench)
		builder = make_engineer(builder_wrench)
	fitting.wrench_act(builder, builder_wrench)
	var/obj/machinery/atmospherics/built = locate(pipe_type) in where
	TEST_ASSERT_NOTNULL(built, "Failed to build [pipe_type] at [dx], [dy]")
	if(rebuild)
		settle()
	return built

/// Lets SSair finish every queued pipenet rebuild, like it would on its next fire
/datum/unit_test/atmos_pipenet_bookkeeping/proc/settle()
	while(length(SSair.rebuild_queue) || length(SSair.expansion_queue))
		SSair.process_rebuilds()

/// Adds some nitrogen to a gas mixture
/datum/unit_test/atmos_pipenet_bookkeeping/proc/add_nitrogen(datum/gas_mixture/mix, moles)
	mix.adjust_gas(/datum/gas/nitrogen, moles)
	mix.set_temperature(T20C)

/// A pump inside a pipe loop keeps both its ports connected when the loop is joined to another network
/datum/unit_test/atmos_pipenet_bookkeeping/looped_pump_joins_network

/datum/unit_test/atmos_pipenet_bookkeeping/looped_pump_joins_network/Run()
	// A pump with a pipe loop running from its output back around to its input
	var/obj/machinery/atmospherics/components/binary/pump/pump = build(1, 0, /obj/machinery/atmospherics/components/binary/pump, EAST)
	build(0, 0, /obj/machinery/atmospherics/pipe/smart)
	build(0, 1, /obj/machinery/atmospherics/pipe/smart)
	build(1, 1, /obj/machinery/atmospherics/pipe/smart)
	build(2, 1, /obj/machinery/atmospherics/pipe/smart)
	build(2, 0, /obj/machinery/atmospherics/pipe/smart)
	// A separate pipe, then a pipe joining it to the loop
	var/obj/machinery/atmospherics/pipe/smart/other_network = build(3, 2, /obj/machinery/atmospherics/pipe/smart)
	build(3, 1, /obj/machinery/atmospherics/pipe/smart)

	var/datum/gas_mixture/pump_output = pump.return_analyzable_air()[2]
	add_nitrogen(pump_output, 10)

	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	var/mob/living/carbon/human/engineer = make_engineer(wrench)
	wrench.melee_attack_chain(engineer, pump)
	TEST_ASSERT(QDELETED(pump), "Failed to unwrench the pump")

	TEST_ASSERT_EQUAL(other_network.return_air().total_moles(), 10, "Gas in the pump was lost when it was unwrenched from the joined network")

/// A component moved away from its pipe by a shuttle keeps the gas inside it
/datum/unit_test/atmos_pipenet_bookkeeping/shuttle_move_keeps_component_gas

/datum/unit_test/atmos_pipenet_bookkeeping/shuttle_move_keeps_component_gas/Run()
	var/obj/machinery/atmospherics/components/binary/pump/pump = build(1, 1, /obj/machinery/atmospherics/components/binary/pump, EAST)
	build(2, 1, /obj/machinery/atmospherics/pipe/smart)
	add_nitrogen(pump.return_analyzable_air()[2], 10)

	// The shuttle carrying the pump moves north, leaving the pipe behind
	var/turf/old_turf = spot(1, 1)
	var/turf/new_turf = spot(1, 2)
	pump.onShuttleMove(new_turf, old_turf, null, NORTH)
	pump.afterShuttleMove(old_turf, null, NORTH, NORTH, NORTH, 0)
	pump.lateShuttleMove(old_turf, null, NORTH)
	settle()

	var/total_moles = 0
	for(var/datum/gas_mixture/pump_air as anything in pump.return_analyzable_air())
		total_moles += pump_air?.total_moles()
	TEST_ASSERT_EQUAL(total_moles, 10, "The pump lost its gas when the shuttle moved it away from its pipe")

/// Building a pipe that joins a network to a pipe still waiting for its pipenet rebuild connects them all
/datum/unit_test/atmos_pipenet_bookkeeping/build_next_to_rebuilding_pipe

/datum/unit_test/atmos_pipenet_bookkeeping/build_next_to_rebuilding_pipe/Run()
	var/obj/machinery/atmospherics/pipe/smart/north_pipe = build(1, 2, /obj/machinery/atmospherics/pipe/smart)
	var/obj/machinery/atmospherics/pipe/smart/south_pipe = build(1, 0, /obj/machinery/atmospherics/pipe/smart)
	var/obj/machinery/atmospherics/pipe/smart/removed_pipe = build(2, 0, /obj/machinery/atmospherics/pipe/smart)
	add_nitrogen(north_pipe.return_air(), 10)

	// Removing a pipe leaves its neighbour waiting for SSair to rebuild its pipenet
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	var/mob/living/carbon/human/engineer = make_engineer(wrench)
	wrench.melee_attack_chain(engineer, removed_pipe)
	TEST_ASSERT(QDELETED(removed_pipe), "Failed to unwrench the pipe")

	// Before that rebuild happens, join the two pipes
	build(1, 1, /obj/machinery/atmospherics/pipe/smart, rebuild = FALSE)
	settle()

	TEST_ASSERT_EQUAL(south_pipe.return_air().total_moles(), 10, "Gas from the north pipe did not reach the south pipe")
