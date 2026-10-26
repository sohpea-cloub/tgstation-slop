/datum/unit_test/atmos_small_fixes
	abstract_type = /datum/unit_test/atmos_small_fixes
	/// The human who wrenches down every pipe built by build()
	var/mob/living/carbon/human/builder
	/// The builder's wrench
	var/obj/item/wrench/builder_wrench

/// Returns the test room turf at the given offset from the bottom left corner
/datum/unit_test/atmos_small_fixes/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Returns a human standing in the corner of the test room, holding the given tool
/datum/unit_test/atmos_small_fixes/proc/make_engineer(obj/item/tool)
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent)
	if(tool)
		engineer.put_in_hands(tool, forced = TRUE)
	return engineer

/// Drops a pipe fitting on a turf, the same way the RPD dispenses one
/datum/unit_test/atmos_small_fixes/proc/make_fitting(turf/where, pipe_type, dir = SOUTH, init_dir = ALL_CARDINALS, color = ATMOS_COLOR_OMNI)
	var/obj/machinery/atmospherics/path = pipe_type
	var/fitting_type = initial(path.construction_type) || /obj/item/pipe
	return new fitting_type(where, pipe_type, dir, null, color, ispath(pipe_type, /obj/machinery/atmospherics/pipe/smart) ? init_dir : null)

/// Dispenses a fitting and wrenches it down, like an RPD in wrench mode, then lets SSair rebuild the pipenets unless told not to
/datum/unit_test/atmos_small_fixes/proc/build(dx, dy, pipe_type, dir = SOUTH, init_dir = ALL_CARDINALS, color = ATMOS_COLOR_OMNI, rebuild = TRUE)
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
/datum/unit_test/atmos_small_fixes/proc/settle()
	while(length(SSair.rebuild_queue) || length(SSair.expansion_queue))
		SSair.process_rebuilds()

/// Adds some nitrogen to a gas mixture
/datum/unit_test/atmos_small_fixes/proc/add_nitrogen(datum/gas_mixture/mix, moles)
	mix.adjust_gas(/datum/gas/nitrogen, moles)
	mix.set_temperature(T20C)

/// Component fittings can't be welded into sliced pipe
/datum/unit_test/atmos_small_fixes/component_fitting_not_weldable

/datum/unit_test/atmos_small_fixes/component_fitting_not_weldable/Run()
	var/obj/item/pipe/vent_fitting = make_fitting(spot(1, 0), /obj/machinery/atmospherics/components/unary/vent_pump)
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	var/mob/living/carbon/human/engineer = make_engineer(welder)
	welder.attack_self(engineer)
	TEST_ASSERT(welder.welding, "Failed to light the welder")

	welder.melee_attack_chain(engineer, vent_fitting)

	TEST_ASSERT(!QDELETED(vent_fitting), "The vent fitting was welded apart")
	TEST_ASSERT_NULL(locate(/obj/item/sliced_pipe) in spot(1, 0), "Welding a vent fitting made sliced pipe")

/// Unwrenching a component with gas inside takes time, even in a vacuum
/datum/unit_test/atmos_small_fixes/component_unwrench_delay_in_vacuum

/datum/unit_test/atmos_small_fixes/component_unwrench_delay_in_vacuum/Run()
	var/obj/machinery/atmospherics/components/binary/pump/pump = build(1, 0, /obj/machinery/atmospherics/components/binary/pump, EAST)
	add_nitrogen(pump.return_analyzable_air()[1], 10)
	var/turf/open/pump_turf = spot(1, 0)
	pump_turf.return_air().remove_ratio(1)

	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	// Test dummies normally finish do_afters instantly, this one takes a little time
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent/slow)
	engineer.put_in_hands(wrench, forced = TRUE)
	var/start_time = world.time
	wrench.melee_attack_chain(engineer, pump)
	TEST_ASSERT(QDELETED(pump), "Failed to unwrench the pump")
	TEST_ASSERT(world.time > start_time, "A pump with gas inside was unwrenched instantly in a vacuum")

/// Pipes drawn onto a layer adaptor float on the adaptor's own layer
/datum/unit_test/atmos_small_fixes/layer_adaptor_overlay_layer

/datum/unit_test/atmos_small_fixes/layer_adaptor_overlay_layer/Run()
	var/obj/machinery/atmospherics/pipe/layer_manifold/adaptor = build(1, 1, /obj/machinery/atmospherics/pipe/layer_manifold, NORTH)
	build(1, 2, /obj/machinery/atmospherics/pipe/smart)

	var/found = FALSE
	for(var/mutable_appearance/overlay as anything in adaptor.overlays)
		if(overlay.icon != 'icons/obj/pipes_n_cables/layer_manifold_underlays.dmi')
			continue
		found = TRUE
		TEST_ASSERT(overlay.layer <= FLOAT_LAYER, "The connected pipe is drawn on the layer adaptor at absolute layer [overlay.layer] instead of floating on the adaptor's layer")
	TEST_ASSERT(found, "The layer adaptor did not draw the connected pipe")

/// Every pipe paint color is drawn on its own layer, so overlapping pipes of different colors sort consistently
/datum/unit_test/atmos_small_fixes/pipe_colors_layer_apart

/datum/unit_test/atmos_small_fixes/pipe_colors_layer_apart/Run()
	var/list/layer_by_color = list()
	var/index = 0
	for(var/color_name in GLOB.pipe_paint_colors)
		var/obj/machinery/atmospherics/pipe/smart/pipe = build((index % 3) * 2, round(index / 3), /obj/machinery/atmospherics/pipe/smart, color = GLOB.pipe_paint_colors[color_name])
		index++
		var/same_layer_color
		for(var/other_color in layer_by_color)
			if(layer_by_color[other_color] == pipe.layer)
				same_layer_color = other_color
				break
		if(same_layer_color)
			TEST_FAIL("[color_name] pipes are drawn on the same layer as [same_layer_color] pipes")
			continue
		layer_by_color[color_name] = pipe.layer

/// An RCD in wallframe mode installs the circuit in a firelock frame.
/datum/unit_test/atmos_small_fixes/rcd_firelock_frame

/datum/unit_test/atmos_small_fixes/rcd_firelock_frame/Run()
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/construction/rcd/rcd = allocate(/obj/item/construction/rcd/combat/admin)
	engineer.put_in_hands(rcd, forced = TRUE)
	rcd.mode = RCD_WALLFRAME
	var/obj/structure/firelock_frame/frame = allocate(/obj/structure/firelock_frame, get_step(run_loc_floor_bottom_left, EAST))

	// What the RCD does when used on the frame, minus the build delay.
	var/list/rcd_results = frame.rcd_vals(engineer, rcd)
	TEST_ASSERT(rcd_results, "An upgraded RCD can't be used on an empty firelock frame")
	rcd_results[RCD_DESIGN_MODE] = rcd.mode
	frame.rcd_act(engineer, rcd, rcd_results)

	var/examine_text = jointext(frame.examine(engineer), "\n")
	TEST_ASSERT(!findtext(examine_text, "firelock electronics"), "The firelock frame still has no electronics after an RCD in wallframe mode was used on it")

/// Merging an excited group shown on the atmos debug display with one that isn't shown works.
/datum/unit_test/atmos_small_fixes/merge_displayed_excited_groups

/datum/unit_test/atmos_small_fixes/merge_displayed_excited_groups/Run()
	var/datum/excited_group/shown = new
	shown.add_turf(run_loc_floor_bottom_left)
	shown.add_turf(get_step(run_loc_floor_bottom_left, NORTH))
	// What the atmos control panel's "toggle_show_group" does.
	shown.should_display = TRUE
	shown.display_turfs()

	var/datum/excited_group/hidden = new
	hidden.add_turf(get_step(run_loc_floor_bottom_left, EAST))

	var/error
	try
		shown.merge_groups(hidden)
	catch(var/exception/caught)
		error = "[caught] ([caught.file]:[caught.line])"

	shown.garbage_collect()
	hidden.garbage_collect()

	TEST_ASSERT_NULL(error, "Merging a displayed excited group with a hidden one errored")
