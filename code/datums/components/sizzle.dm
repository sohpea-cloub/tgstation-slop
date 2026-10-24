/datum/component/sizzle
	dupe_mode = COMPONENT_DUPE_UNIQUE_PASSARGS

	///The sizzling appearance to put on top of the food item
	var/mutable_appearance/sizzling
	///The amount of time the food item has been sizzling for
	var/grilled_time = 0

/datum/component/sizzle/Initialize(grilled_time)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

	var/atom/food = parent
	var/icon/grill_marks = icon(food.icon, food.icon_state)
	grill_marks.Blend("#fff", ICON_ADD) //fills the icon_state with white (except where it's transparent)
	//adds grill marks and the remaining white areas become transparent. The marks are tiled, since icons larger than the marks (i.e. wide fish) would be left white
	var/icon/marks = icon('icons/obj/machines/kitchen.dmi', "grillmarks")
	var/marks_width = marks.Width()
	var/marks_height = marks.Height()
	for(var/offset_x in 0 to grill_marks.Width() - 1 step marks_width)
		for(var/offset_y in 0 to grill_marks.Height() - 1 step marks_height)
			grill_marks.Blend(marks, ICON_MULTIPLY, offset_x + 1, offset_y + 1)
	sizzling = new(grill_marks)
	food.add_overlay(sizzling)

	src.grilled_time = grilled_time

/datum/component/sizzle/InheritComponent(datum/component/C, i_am_original, grilled_time)
	var/atom/food = parent
	sizzling.alpha += 5
	food.cut_overlay(sizzling)
	food.add_overlay(sizzling)
	src.grilled_time = grilled_time

///Returns how long the food item has been sizzling for
/datum/component/sizzle/proc/time_elapsed()
	return src.grilled_time
