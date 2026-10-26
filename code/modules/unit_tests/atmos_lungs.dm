/datum/unit_test/atmos_lungs
	abstract_type = /datum/unit_test/atmos_lungs

/// Takes one breath of the given gas fractions at the given temperature, at one atmosphere, using the human's own lungs.
/datum/unit_test/atmos_lungs/proc/breathe(mob/living/carbon/human/breather, list/gas_fractions, temperature = T20C)
	var/datum/gas_mixture/mix = allocate(/datum/gas_mixture, 2500)
	mix.temperature = temperature
	for(var/gas_type in gas_fractions)
		mix.add_gas(gas_type)
		mix.moles[gas_type] = ONE_ATMOSPHERE * 2500 / (R_IDEAL_GAS_EQUATION * temperature) * gas_fractions[gas_type]
	var/datum/gas_mixture/breath = mix.remove(mix.total_moles() * BREATH_PERCENTAGE)
	var/obj/item/organ/lungs/lungs = breather.get_organ_slot(ORGAN_SLOT_LUNGS)
	lungs.check_breath(breath, breather)

/// Breathing very hot air burns.
/datum/unit_test/atmos_lungs/hot_breath_burns

/datum/unit_test/atmos_lungs/hot_breath_burns/Run()
	var/mob/living/carbon/human/breather = allocate(/mob/living/carbon/human/consistent)
	breathe(breather, list(/datum/gas/oxygen = O2STANDARD, /datum/gas/nitrogen = N2STANDARD), 1000)
	TEST_ASSERT(breather.get_fire_loss() > 0, "Breathing 1000 K air caused no burns")

/// Breathing very cold air burns.
/datum/unit_test/atmos_lungs/cold_breath_burns

/datum/unit_test/atmos_lungs/cold_breath_burns/Run()
	var/mob/living/carbon/human/breather = allocate(/mob/living/carbon/human/consistent)
	breathe(breather, list(/datum/gas/oxygen = O2STANDARD, /datum/gas/nitrogen = N2STANDARD), 50)
	TEST_ASSERT(breather.get_fire_loss() > 0, "Breathing 50 K air caused no frostburn")

/// Someone who keeps breathing helium keeps their squeaky voice.
/datum/unit_test/atmos_lungs/helium_voice
	/// The spans of the last message the listener heard
	var/list/heard_spans

/datum/unit_test/atmos_lungs/helium_voice/Run()
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
	listener.mock_client = new /datum/client_interface()
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))

	for(var/i in 1 to 3)
		breathe(speaker, list(/datum/gas/oxygen = 0.21, /datum/gas/helium = 0.79))
	speaker.say("Testing, testing.")

	TEST_ASSERT_NOTNULL(heard_spans, "The listener didn't hear the speaker")
	TEST_ASSERT(SPAN_SMALL_VOICE in heard_spans, "After three breaths of helium the speaker's voice wasn't small")

/// Records the spans of what the listener hears
/datum/unit_test/atmos_lungs/helium_voice/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	heard_spans = hearing_args[HEARING_SPANS]?.Copy()

/// Someone who keeps breathing a little healium ends up euphoric.
/datum/unit_test/atmos_lungs/healium_euphoria

/datum/unit_test/atmos_lungs/healium_euphoria/Run()
	var/mob/living/carbon/human/breather = allocate(/mob/living/carbon/human/consistent)
	// Euphoria kicks in with a 15% chance per breath, so take enough breaths that missing it is practically impossible.
	for(var/i in 1 to 100)
		breathe(breather, list(/datum/gas/oxygen = 0.21, /datum/gas/nitrogen = 0.78, /datum/gas/healium = 0.01))
	TEST_ASSERT_NOTNULL(breather.mob_mood.get_mood_event("chemical_euphoria"), "After 100 breaths of healium the breather had no euphoria mood")
