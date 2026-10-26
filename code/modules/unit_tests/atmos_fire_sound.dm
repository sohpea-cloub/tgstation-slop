/datum/unit_test/atmos_fire_sound
	abstract_type = /datum/unit_test/atmos_fire_sound

/// A fire's sound keeps playing after the turf it started on is changed.
/datum/unit_test/atmos_fire_sound/fire_sound_survives_turf_change

/datum/unit_test/atmos_fire_sound/fire_sound_survives_turf_change/Run()
	var/list/turf/open/row = list()
	for(var/i in 0 to 4)
		row += locate(run_loc_floor_bottom_left.x + i, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)

	// The first three spots start the sound in the middle of them, on row[2].
	var/obj/effect/hotspot/first_spot
	for(var/i in 1 to 3)
		var/obj/effect/hotspot/spot = allocate(/obj/effect/hotspot, row[i])
		first_spot ||= spot
	var/datum/hot_group/fire = first_spot.our_hot_group
	TEST_ASSERT_NOTNULL(fire?.sound, "The fire did not start a sound")

	// The fire grows, and once its 5 second cooldown is up the sound moves to the new middle, row[3].
	allocate(/obj/effect/hotspot, row[4])
	allocate(/obj/effect/hotspot, row[5])
	fire.update_sound()

	var/turf/first_sound_turf = row[2]
	first_sound_turf.ChangeTurf(/turf/open/floor/plating)
	var/atom/sound_source = fire.sound.parent
	first_sound_turf.ChangeTurf(/turf/open/indestructible)
	restore_atmos()

	TEST_ASSERT_NOTNULL(sound_source, "The fire's sound lost its source when the turf it first played from changed")
