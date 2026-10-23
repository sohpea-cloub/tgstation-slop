/datum/unit_test/holder_loving

/datum/unit_test/holder_loving/Run()
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/backpack/duffelbag/bag = allocate(/obj/item/storage/backpack/duffelbag)
	var/obj/item/storage/backpack/duffelbag/testbag = allocate(/obj/item/storage/backpack/duffelbag)
	var/obj/item/wrench/tool = allocate(/obj/item/wrench)

	//put wrench in bag & equip bag on human
	tool.AddComponent(/datum/component/holderloving, bag)
	bag.atom_storage.attempt_insert(tool, person, messages = FALSE)
	person.equip_to_slot_if_possible(bag, ITEM_SLOT_BACK)

	//Test 1: Should be able to move wrench from bag to hand
	person.putItemFromInventoryInHandIfPossible(tool, 1)
	TEST_ASSERT_EQUAL(person.get_item_for_held_index(1), tool, "Holder loving component blocked equiping wrench from storage into hand!")

	//Test 2: Should be able to swap the item between hands
	person.swap_hand(2, silent = TRUE)
	tool.attempt_pickup(person)
	TEST_ASSERT_EQUAL(person.get_item_for_held_index(2), tool, "Holder loving component blocked swapping the wrench into the other hand!")

	//Test 3: Upon dropping the item onto the ground it should move back into the bag
	person.dropItemToGround(tool, silent = TRUE)
	TEST_ASSERT_NOTNULL(locate(/obj/item/wrench) in bag, "Holder loving component did not move the wrench back into storage upon dropping!")

	//Test 4: Should not be able to move the wrench into any other atom besides its holder
	TEST_ASSERT(!person.transferItemToLoc(tool, testbag), "Holder loving component failed to block moving the wrench into another atom that isn't the holder!")

	//Test 5: Should fail at the signal checks
	TEST_ASSERT(!person.temporarilyRemoveItemFromInventory(tool, newloc = testbag), "Holder loving component failed to block temporarily removing wrench and moving it into another atom that isn't the holder!")

	//Test 6: Moving the wrench anywhere else directly (storage to storage, wrapping it in a parcel...) should send it back into the bag
	testbag.atom_storage.attempt_insert(tool, person, messages = FALSE)
	TEST_ASSERT_EQUAL(tool.loc, bag, "Holder loving component let the wrench be moved from its holder straight into another storage!")

	//Test 7: Same after removing it from the hand without a new location (temporarilyRemoveItemFromInventory, then forceMove)
	person.putItemFromInventoryInHandIfPossible(tool, 1)
	person.temporarilyRemoveItemFromInventory(tool)
	tool.forceMove(testbag)
	TEST_ASSERT_EQUAL(tool.loc, bag, "Holder loving component let the wrench be force moved into another atom after it was removed from the hand!")
