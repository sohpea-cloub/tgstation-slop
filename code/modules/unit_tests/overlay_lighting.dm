/// Tests that deleted overlay lights don't stay in the spatial grid when their range shrank before deletion
/datum/unit_test/overlay_lighting_grid_cells

/datum/unit_test/overlay_lighting_grid_cells/Run()
	// Find a spot where a range 4 light reaches more grid cells than a range 1 light
	var/turf/light_turf
	for(var/turf/candidate as anything in block(run_loc_floor_bottom_left.x - 8, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z, run_loc_floor_bottom_left.x + 8, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
		if(length(SSspatial_grid.get_cells_in_range(candidate, 4)) > length(SSspatial_grid.get_cells_in_range(candidate, 1)))
			light_turf = candidate
			break
	TEST_ASSERT_NOTNULL(light_turf, "Couldn't find a turf near a grid cell edge")

	// Range shrinks while the light is on
	var/obj/item/flashlight/flashlight = allocate(/obj/item/flashlight, light_turf)
	var/datum/component/overlay_lighting/lighting = flashlight.GetComponent(/datum/component/overlay_lighting)
	flashlight.set_light_range(4)
	flashlight.set_light_on(TRUE)
	flashlight.set_light_range(1)
	qdel(flashlight)
	for(var/datum/spatial_grid_cell/cell as anything in SSspatial_grid.get_cells_in_range(light_turf, 6))
		TEST_ASSERT(!(lighting in cell.dynamic_light_sources), "Overlay light that shrank while on was left in a spatial grid cell after being deleted")

	// Range shrinks while the light is off
	flashlight = allocate(/obj/item/flashlight, light_turf)
	lighting = flashlight.GetComponent(/datum/component/overlay_lighting)
	flashlight.set_light_range(4)
	flashlight.set_light_on(TRUE)
	flashlight.set_light_on(FALSE)
	flashlight.set_light_range(1)
	qdel(flashlight)
	for(var/datum/spatial_grid_cell/cell as anything in SSspatial_grid.get_cells_in_range(light_turf, 6))
		TEST_ASSERT(!(lighting in cell.dynamic_light_sources), "Overlay light that shrank while off was left in a spatial grid cell after being deleted")
