/*
All shuttleRotate procs go here

If ever any of these procs are useful for non-shuttles, rename it to proc/rotate and move it to be a generic atom proc
*/

/************************************Base proc************************************/

/atom/proc/shuttleRotate(rotation, params=ROTATE_DIR|ROTATE_SMOOTH|ROTATE_OFFSET)
	if(params & ROTATE_DIR)
		//rotate our direction
		setDir(angle2dir(rotation+dir2angle(dir)))

	//resmooth if need be.
	if(params & ROTATE_SMOOTH && smoothing_flags & USES_SMOOTHING)
		QUEUE_SMOOTH(src)

	//rotate the pixel offsets too.
	if((pixel_x || pixel_y) && (params & ROTATE_OFFSET))
		if(rotation < 0)
			rotation += 360
		for(var/turntimes=rotation/90;turntimes>0;turntimes--)
			var/oldPX = pixel_x
			var/oldPY = pixel_y
			pixel_x = oldPY
			pixel_y = (oldPX*(-1))

/************************************Base /atom/movable proc************************************/

/atom/movable/shuttleRotate(rotation, params)
	// Multi-tile atoms are anchored at their bottom left corner (their loc), and their bounds/icon extend from there.
	// Moving the loc to the rotated tile is not enough: the whole footprint must be rotated around that tile too.
	var/rotate_bounds = (params & ROTATE_OFFSET) && (bound_width != ICON_SIZE_X || bound_height != ICON_SIZE_Y)
	if(rotate_bounds)
		params &= ~ROTATE_OFFSET // we do it ourselves, the base proc would rotate the offsets as if the atom was one tile big
	. = ..()
	if(!rotate_bounds)
		return

	var/turns = round(SIMPLIFY_DEGREES(rotation) / 90) % 4
	if(!turns)
		return

	// Assume the icon covers the same area as the bounds unless it's a bigger/smaller file (the BSA, the big engines).
	var/icon_width = bound_width
	var/icon_height = bound_height
	if(icon)
		var/list/icon_dimensions = get_icon_dimensions(icon)
		icon_width = icon_dimensions["width"] || icon_width
		icon_height = icon_dimensions["height"] || icon_height

	// A rectangle (x, y, w, h) in pixels, relative to the loc tile, turned clockwise around the center of that tile.
	var/old_bound_x = bound_x
	var/old_bound_y = bound_y
	var/old_bound_width = bound_width
	var/old_bound_height = bound_height
	var/old_pixel_x = pixel_x
	var/old_pixel_y = pixel_y
	var/new_bound_x
	var/new_bound_y
	var/new_pixel_x
	var/new_pixel_y
	switch(turns)
		if(1)
			new_bound_x = old_bound_y
			new_bound_y = ICON_SIZE_Y - old_bound_x - old_bound_width
			new_pixel_x = old_pixel_y
			new_pixel_y = ICON_SIZE_Y - old_pixel_x - icon_width
		if(2)
			new_bound_x = ICON_SIZE_X - old_bound_x - old_bound_width
			new_bound_y = ICON_SIZE_Y - old_bound_y - old_bound_height
			new_pixel_x = ICON_SIZE_X - old_pixel_x - icon_width
			new_pixel_y = ICON_SIZE_Y - old_pixel_y - icon_height
		if(3)
			new_bound_x = ICON_SIZE_X - old_bound_y - old_bound_height
			new_bound_y = old_bound_x
			new_pixel_x = ICON_SIZE_X - old_pixel_y - icon_height
			new_pixel_y = old_pixel_x
	if(turns != 2)
		bound_width = old_bound_height
		bound_height = old_bound_width
	bound_x = new_bound_x
	bound_y = new_bound_y
	pixel_x = new_pixel_x
	pixel_y = new_pixel_y

/************************************Turf rotate procs************************************/

/turf/closed/mineral/shuttleRotate(rotation, params)
	params &= ~ROTATE_OFFSET
	return ..()

/************************************Mob rotate procs************************************/

//override to avoid rotating pixel_xy on mobs
/mob/shuttleRotate(rotation, params)
	params = NONE
	. = ..()
	if(!buckled)
		setDir(angle2dir(rotation+dir2angle(dir)))

/mob/dead/observer/shuttleRotate(rotation, params)
	. = ..()
	update_appearance()

/************************************Structure rotate procs************************************/

//Fixes dpdir on shuttle rotation
/obj/structure/disposalpipe/shuttleRotate(rotation, params)
	. = ..()
	var/new_dpdir = 0
	for(var/D in GLOB.cardinals)
		if(dpdir & D)
			new_dpdir = new_dpdir | angle2dir(rotation+dir2angle(D))
	dpdir = new_dpdir

/obj/structure/table/wood/shuttle_bar/shuttleRotate(rotation, params)
	. = ..()
	boot_dir = angle2dir(rotation + dir2angle(boot_dir))

/obj/structure/alien/weeds/shuttleRotate(rotation, params)
	params &= ~ROTATE_OFFSET
	return ..()

/************************************Machine rotate procs************************************/

/obj/machinery/atmospherics/shuttleRotate(rotation, params)
	var/list/real_node_connect = get_node_connects()
	for(var/i in 1 to device_type)
		var/node_dir = real_node_connect[i]
		if(isnull(node_dir))
			continue

		real_node_connect[i] = turn(node_dir, -rotation)

	. = ..()
	set_init_directions()
	var/list/supposed_node_connect = get_node_connects()
	var/list/nodes_copy = nodes.Copy()

	for(var/i in 1 to device_type)
		var/node_dir = real_node_connect[i]
		if(isnull(node_dir))
			continue

		var/new_pos = supposed_node_connect.Find(node_dir)
		nodes[new_pos] = nodes_copy[i]

//prevents shuttles attempting to rotate this since it messes up sprites
/obj/machinery/gateway/shuttleRotate(rotation, params)
	params = NONE
	return ..()

/obj/machinery/door/airlock/shuttleRotate(rotation, params)
	. = ..()
	if(cyclelinkeddir && (params & ROTATE_DIR))
		cyclelinkeddir = angle2dir(rotation+dir2angle(cyclelinkeddir))
		// If we update the linked airlock here, the partner airlock might
		// not be present yet, so don't do that. Just assume we're still
		// partnered with the same airlock as before.

/obj/machinery/porta_turret/shuttleRotate(rotation, params)
	. = ..()
	if(wall_turret_direction && (params & ROTATE_DIR))
		wall_turret_direction = turn(wall_turret_direction,rotation)

/obj/machinery/power/apc/shuttleRotate(rotation, params)
	if(params & ROTATE_DIR) // APCs handle pixel offset rotation in setDir,
		//rotate our direction
		setDir(angle2dir(rotation+dir2angle(dir)))
