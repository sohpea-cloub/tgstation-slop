/// Checks that a basic mob stops running its attack branch when its target dies right after being picked.
/datum/unit_test/basic_mob_drops_dead_target

/datum/unit_test/basic_mob_drops_dead_target/Run()
	var/mob/living/basic/zombie/zombie = allocate(/mob/living/basic/zombie)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(zombie, EAST))
	var/datum/ai_controller/controller = zombie.ai_controller

	// Ai controlling processes expect a seconds_per_tick, supply a real-fake dt
	var/fake_dt = SSai_controllers.wait * 0.1
	controller.ai_traits |= RUN_WHILE_UNWATCHED
	controller.set_ai_status(AI_STATUS_ON)
	// The zombie has fought before, so its melee cooldown is set and has already run out
	controller.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time - 1)

	// Find the branch that only runs while the zombie has a target
	var/datum/bt_node/decorator/bb_key_set/attack_branch
	var/list/to_visit = controller.behavior_nodes.Copy()
	for(var/i = 1; i <= length(to_visit); i++)
		var/datum/bt_node/decorator/bb_key_set/node = to_visit[i]
		if(istype(node) && node.key == BB_CURRENT_TARGET)
			attack_branch = node
			break
		var/list/children = node.get_children()
		if(children)
			to_visit += children
	TEST_ASSERT_NOTNULL(attack_branch, "Couldn't find the zombie's attack branch.")

	// The zombie spots the victim, which dies before the zombie gets to attack
	controller.SelectBehaviors(fake_dt)
	controller.set_blackboard_key(BB_CURRENT_TARGET, victim)
	victim.death()

	for(var/i in 1 to 3)
		controller.SelectBehaviors(fake_dt)

	TEST_ASSERT_NULL(controller.blackboard[BB_CURRENT_TARGET], "Zombie kept a dead target.")
	TEST_ASSERT(!attack_branch.child_active, "Zombie is still running its attack branch with no target.")
