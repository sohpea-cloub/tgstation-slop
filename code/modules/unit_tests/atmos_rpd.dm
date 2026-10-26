// The RPD's mode flags, as its UI sets them. RPD.dm undefines its own copies.
#define RPD_DESTROY_MODE (1<<2)
#define RPD_REPROGRAM_MODE (1<<3)

/datum/unit_test/atmos_rpd
	abstract_type = /datum/unit_test/atmos_rpd
	/// The human who wrenches down every pipe built by build()
	var/mob/living/carbon/human/builder
	/// The builder's wrench
	var/obj/item/wrench/builder_wrench

/// Returns the test room turf at the given offset from the bottom left corner
/datum/unit_test/atmos_rpd/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Returns a human standing in the corner of the test room, holding the given tool
/datum/unit_test/atmos_rpd/proc/make_engineer(obj/item/tool)
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent)
	if(tool)
		engineer.put_in_hands(tool, forced = TRUE)
	return engineer

/// Drops a pipe fitting on a turf, the same way the RPD dispenses one
/datum/unit_test/atmos_rpd/proc/make_fitting(turf/where, pipe_type, dir = SOUTH, init_dir = ALL_CARDINALS, color = ATMOS_COLOR_OMNI)
	var/obj/machinery/atmospherics/path = pipe_type
	var/fitting_type = initial(path.construction_type) || /obj/item/pipe
	return new fitting_type(where, pipe_type, dir, null, color, ispath(pipe_type, /obj/machinery/atmospherics/pipe/smart) ? init_dir : null)

/// Dispenses a fitting and wrenches it down, like an RPD in wrench mode, then lets SSair rebuild the pipenets unless told not to
/datum/unit_test/atmos_rpd/proc/build(dx, dy, pipe_type, dir = SOUTH, init_dir = ALL_CARDINALS, color = ATMOS_COLOR_OMNI, rebuild = TRUE)
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
/datum/unit_test/atmos_rpd/proc/settle()
	while(length(SSair.rebuild_queue) || length(SSair.expansion_queue))
		SSair.process_rebuilds()

/// Adds some nitrogen to a gas mixture
/datum/unit_test/atmos_rpd/proc/add_nitrogen(datum/gas_mixture/mix, moles)
	mix.adjust_gas(/datum/gas/nitrogen, moles)
	mix.set_temperature(T20C)

/// Reprogramming a connected smart pipe with the RPD to allow a new direction joins the new neighbour into its network
/datum/unit_test/atmos_rpd/rpd_reprogram_connects

/datum/unit_test/atmos_rpd/rpd_reprogram_connects/Run()
	var/obj/machinery/atmospherics/pipe/smart/west_pipe = build(0, 0, /obj/machinery/atmospherics/pipe/smart)
	var/obj/machinery/atmospherics/pipe/smart/reprogrammed = build(1, 0, /obj/machinery/atmospherics/pipe/smart, init_dir = EAST|WEST)
	var/obj/machinery/atmospherics/pipe/smart/north_pipe = build(1, 1, /obj/machinery/atmospherics/pipe/smart)
	add_nitrogen(west_pipe.return_air(), 10)
	TEST_ASSERT_EQUAL(north_pipe.return_air().total_moles(), 0, "The north pipe should start out disconnected")

	var/obj/item/pipe_dispenser/rpd = allocate(/obj/item/pipe_dispenser)
	var/mob/living/carbon/human/engineer = make_engineer(rpd)
	rpd.mode = RPD_REPROGRAM_MODE
	rpd.p_init_dir = ALL_CARDINALS
	rpd.melee_attack_chain(engineer, reprogrammed)
	settle()

	TEST_ASSERT_EQUAL(north_pipe.return_air().total_moles(), 10, "Gas from the west pipe did not reach the north pipe after reprogramming the middle pipe")
	TEST_ASSERT_EQUAL(west_pipe.return_air().total_moles(), 10, "Gas in the west pipe was not conserved after reprogramming the middle pipe")

/// Removing a pipe with the RPD's unwrench upgrade in destroy mode also gets rid of the pipe fitting
/datum/unit_test/atmos_rpd/rpd_unwrench_destroys

/datum/unit_test/atmos_rpd/rpd_unwrench_destroys/Run()
	var/obj/machinery/atmospherics/pipe/smart/pipe = build(1, 1, /obj/machinery/atmospherics/pipe/smart)

	var/obj/item/pipe_dispenser/rpd = allocate(/obj/item/pipe_dispenser)
	var/mob/living/carbon/human/engineer = make_engineer(rpd)
	var/obj/item/rpd_upgrade/unwrench/upgrade = allocate(/obj/item/rpd_upgrade/unwrench)
	rpd.melee_attack_chain(engineer, upgrade)
	TEST_ASSERT(QDELETED(upgrade), "Failed to install the unwrench upgrade")

	rpd.mode = RPD_DESTROY_MODE
	rpd.melee_attack_chain(engineer, pipe)
	TEST_ASSERT(QDELETED(pipe), "The RPD did not unwrench the pipe")
	var/obj/item/pipe/fitting = locate() in spot(1, 1)
	TEST_ASSERT_NULL(fitting, "The RPD left the unwrenched pipe fitting behind instead of destroying it")

#undef RPD_DESTROY_MODE
#undef RPD_REPROGRAM_MODE
