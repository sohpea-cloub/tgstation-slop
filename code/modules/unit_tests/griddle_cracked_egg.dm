/// Checks that an egg cracked onto a griddle stays on the griddle when the griddle is moved
/datum/unit_test/griddle_cracked_egg

/datum/unit_test/griddle_cracked_egg/Run()
	var/obj/machinery/griddle/griddle = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, NORTH))
	var/obj/item/food/egg/egg = allocate(__IMPLIED_TYPE__, human.loc)

	egg.melee_attack_chain(human, griddle, list(RIGHT_CLICK = TRUE))
	var/obj/item/food/rawegg/cracked_egg = locate() in griddle.vis_contents
	TEST_ASSERT_NOTNULL(cracked_egg, "Cracking an egg onto a griddle didn't put a raw egg on it!")
	allocated += cracked_egg

	griddle.forceMove(get_step(run_loc_floor_bottom_left, EAST))
	TEST_ASSERT(get_turf(cracked_egg) == get_turf(griddle), "The cracked egg was left behind when the griddle was moved!")
