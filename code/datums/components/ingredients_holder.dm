/**
 * # Custom Atom Component
 *
 * When added to an atom, item ingredients can be put into that.
 * The sprite is updated and reagents and custom materials are transferred.
 *
 * If the component is added to something that is processed, creating new objects (being cut, for example),
 * the replacement type needs to also have the component. The ingredients will be copied over. Reagents are not
 * copied over since other components already take care of that.
 */
/datum/component/ingredients_holder
	can_transfer = TRUE
	///Type path of replacement atom.
	var/replacement
	///Type of fill, can be [CUSTOM_INGREDIENT_ICON_NOCHANGE] for example.
	var/fill_type
	///Number of max ingredients.
	var/max_ingredients
	///Overlay used for certain fill types, always shows up on top.
	var/mutable_appearance/top_overlay
	///Type of ingredients to accept, [CUSTOM_INGREDIENT_TYPE_EDIBLE] for example.
	var/ingredient_type
	/// Adds screentips for all items that call on this proc, defaults to "Add"
	var/screentip_verb
	/// If set, using an item of this type on a holder that already has ingredients closes it up (a sandwich getting its top slice), turning it into [closed_type].
	var/closing_type
	/// The type of atom the holder becomes once closed with [closing_type].
	var/closed_type
	/// If TRUE, items that aren't valid ingredients are ignored silently instead of showing "doesn't go on that!" (for holders that are other things first, like a stack of rods).
	var/quiet_rejection

	/// Stores the names of the ingredients used on the holder, to pass down if processed into new instances.
	var/list/ingredient_names
	///List of colors to be used for fillings, to pass down if processed into new instances.
	var/list/filling_colors
	/// The custom name attached to the original name of the holder, to pass down if processed into new instances.
	var/custom_name

/datum/component/ingredients_holder/Initialize(
		atom/replacement,
		fill_type,
		ingredient_type = CUSTOM_INGREDIENT_TYPE_EDIBLE,
		max_ingredients = MAX_ATOM_OVERLAYS - 3, // The cap is >= MAX_ATOM_OVERLAYS so we reserve 2 for top /bottom of item + 1 to stay under cap
		datum/component/ingredients_holder/processed_holder, //when processing a holder, the results receive their own comps, but need the ingredient names and filling passed down
		screentip_verb = "Add",
		closing_type,
		closed_type,
		quiet_rejection = FALSE,
)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	var/atom/atom_parent = parent
	// assume replacement is OK
	if (!atom_parent.reagents && !replacement)
		return COMPONENT_INCOMPATIBLE


	src.replacement = replacement
	src.fill_type = fill_type
	src.max_ingredients = max_ingredients
	src.ingredient_type = ingredient_type
	src.screentip_verb = screentip_verb
	src.closing_type = closing_type
	src.closed_type = closed_type
	src.quiet_rejection = quiet_rejection

	if(!processed_holder || !length(processed_holder.ingredient_names))
		return

	ingredient_names = processed_holder.ingredient_names
	custom_name = processed_holder.custom_name
	atom_parent.name = "[custom_adjective()] [custom_name] [atom_parent.name]"
	for(var/fillcol in processed_holder.filling_colors)
		apply_fill(fillcol)

/datum/component/ingredients_holder/Destroy(force)
	QDEL_NULL(top_overlay)
	return ..()

/datum/component/ingredients_holder/RegisterWithParent()
	var/atom/atom_parent = parent
	atom_parent.flags_1 |= HAS_CONTEXTUAL_SCREENTIPS_1
	RegisterSignal(parent, COMSIG_ATOM_ATTACKBY, PROC_REF(customizable_attack))
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_ATOM_EXITED, PROC_REF(food_exited))
	RegisterSignal(parent, COMSIG_ATOM_PROCESSED, PROC_REF(on_processed))
	RegisterSignal(parent, COMSIG_PIZZA_SLICE_TAKEN, PROC_REF(on_slice_taken))
	RegisterSignal(parent, COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM, PROC_REF(on_requesting_context_from_item))
	ADD_TRAIT(parent, TRAIT_INGREDIENTS_HOLDER, INNATE_TRAIT)

/datum/component/ingredients_holder/UnregisterFromParent()
	UnregisterSignal(parent, list(
		COMSIG_ATOM_ATTACKBY,
		COMSIG_ATOM_EXAMINE,
		COMSIG_ATOM_EXITED,
		COMSIG_ATOM_PROCESSED,
		COMSIG_PIZZA_SLICE_TAKEN,
		COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM,
	))
	REMOVE_TRAIT(parent, TRAIT_INGREDIENTS_HOLDER, INNATE_TRAIT)

/datum/component/ingredients_holder/PostTransfer(datum/new_parent)
	if(!isatom(new_parent))
		return COMPONENT_INCOMPATIBLE
	var/atom/atom_parent = new_parent
	if (!atom_parent.reagents)
		return COMPONENT_INCOMPATIBLE

///Handles when the customizable food is examined.
/datum/component/ingredients_holder/proc/on_examine(atom/A, mob/user, list/examine_list)
	SIGNAL_HANDLER

	var/atom/atom_parent = parent

	examine_list += "It [LAZYLEN(ingredient_names) \
		? "contains [english_list(ingredient_names)] making a [custom_adjective()]-sized [initial(atom_parent.name)]" \
		: "does not contain any ingredients"]."

//// Proc that checks if an ingredient is valid or not, returning false if it isnt and true if it is.
/datum/component/ingredients_holder/proc/valid_ingredient(obj/ingredient)
	if (HAS_TRAIT(ingredient, TRAIT_INGREDIENTS_HOLDER))
		return FALSE
	if(HAS_TRAIT(ingredient, TRAIT_ODD_CUSTOMIZABLE_FOOD_INGREDIENT))
		return TRUE
	switch (ingredient_type)
		if (CUSTOM_INGREDIENT_TYPE_EDIBLE)
			return IS_EDIBLE(ingredient)
		if (CUSTOM_INGREDIENT_TYPE_DRYABLE)
			return HAS_TRAIT(ingredient, TRAIT_DRYABLE)
	return TRUE

///Handles when the customizable food is attacked by something.
/datum/component/ingredients_holder/proc/customizable_attack(datum/source, obj/ingredient, mob/attacker, silent = FALSE, force = FALSE)
	SIGNAL_HANDLER

	if (closing_type && LAZYLEN(ingredient_names) && istype(ingredient, closing_type) && can_close_with(ingredient))
		if (!attacker.transferItemToLoc(ingredient, parent))
			return
		close_holder(ingredient, attacker)
		return COMPONENT_NO_AFTERATTACK

	if (!valid_ingredient(ingredient))
		if (quiet_rejection)
			return
		if (ingredient.is_drainable()) // For stuff like adding flour from a flour sack into a bowl, we handle the transfer of the reagent elsewhere, but we shouldn't regard it beyond some user feedback.
			attacker.balloon_alert(attacker, "transferring...")
			return
		attacker.balloon_alert(attacker, "doesn't go on that!")
		return

	if (LAZYLEN(ingredient_names) >= max_ingredients)
		attacker.balloon_alert(attacker, "too full!")
		return COMPONENT_NO_AFTERATTACK

	var/atom/atom_parent = parent
	if (isstack(atom_parent))
		// Only one unit of a stack (a rod) becomes the custom food, the rest stay behind.
		var/obj/item/stack/stack_parent = atom_parent
		if (stack_parent.amount > 1)
			var/obj/item/stack/split = stack_parent.split_stack(1)
			if (!split)
				return
			// The new unit stays out of the world until it's a kebab, or it would merge right back into the stack.
			var/datum/component/ingredients_holder/split_holder = split.GetComponent(type)
			if (!split_holder || !attacker.transferItemToLoc(ingredient, split))
				stack_parent.add(1)
				qdel(split)
				return
			split_holder.add_ingredient(ingredient, stack_parent.drop_location())
			return COMPONENT_NO_AFTERATTACK

	if(!attacker.transferItemToLoc(ingredient, parent))
		return
	add_ingredient(ingredient)

/// Whether this item can be used as the top of a closed holder: it can't be a holder that holds ingredients of its own.
/datum/component/ingredients_holder/proc/can_close_with(obj/item/top)
	var/datum/component/ingredients_holder/other = top.GetComponent(type)
	return !other || !LAZYLEN(other.ingredient_names)

/// Turns the holder into [closed_type], keeping everything inside it, and adds [top] to it as the lid.
/datum/component/ingredients_holder/proc/close_holder(obj/item/top, mob/user)
	var/atom/old_parent = parent
	var/was_held = user.is_holding(old_parent)
	var/atom/finished = new closed_type(old_parent.drop_location())
	finished.TakeComponent(src)
	closing_type = null
	closed_type = null
	max_ingredients = 0
	handle_reagents(old_parent)
	handle_reagents(top)
	for(var/atom/movable/inside as anything in old_parent.contents.Copy())
		inside.forceMove(finished)
		if(isitem(inside))
			handle_materials(inside)
	var/obj/item/finished_item = finished
	if(istype(finished_item) && top.w_class > finished_item.w_class)
		finished_item.update_weight_class(top.w_class)
	finished.name = "[custom_adjective()] [custom_name] [initial(finished.name)]"
	SEND_SIGNAL(finished, COMSIG_ATOM_CUSTOMIZED, top)
	SEND_SIGNAL(top, COMSIG_ITEM_USED_AS_INGREDIENT, finished)
	qdel(old_parent)
	if(was_held && istype(finished_item))
		user.put_in_hands(finished_item)


///Extract the filling color from the ingredient, than calls apply_fill()
/datum/component/ingredients_holder/proc/get_fill(obj/item/ingredient)
	// get average color
	var/icon/icon = new(ingredient.icon, ingredient.icon_state)
	if(ingredient.color)
		icon.Blend(ingredient.color, ICON_MULTIPLY)
	icon.Scale(1, 1)
	var/fillcol = copytext(icon.GetPixel(1, 1), 1, 8) // remove opacity
	LAZYADD(filling_colors, fillcol)
	apply_fill(fillcol)

///Add a filling overlay to the parent atom.
/datum/component/ingredients_holder/proc/apply_fill(fill_color)
	if(fill_type == CUSTOM_INGREDIENT_ICON_NOCHANGE)
		//don't bother doing the icon procs
		return
	var/atom/atom_parent = parent
	var/mutable_appearance/filling = mutable_appearance(atom_parent.icon, "[initial(atom_parent.icon_state)]_filling")
	filling.color = fill_color
	switch(fill_type)
		if(CUSTOM_INGREDIENT_ICON_SCATTER)
			filling.pixel_w = rand(-1,1)
			filling.pixel_z = rand(-1,1)
		if(CUSTOM_INGREDIENT_ICON_STACK)
			filling.pixel_w = rand(-1,1)
			// we're gonna abuse position layering to ensure overlays render right
			filling.pixel_y = -LAZYLEN(ingredient_names)
			filling.pixel_z = 3 * LAZYLEN(ingredient_names) - 1
		if(CUSTOM_INGREDIENT_ICON_STACKPLUSTOP)
			filling.pixel_w = rand(-1,1)
			// similar here
			filling.pixel_y = -LAZYLEN(ingredient_names)
			filling.pixel_z = 3 * LAZYLEN(ingredient_names) - 1
			if (top_overlay) // delete old top if exists
				atom_parent.cut_overlay(top_overlay)
			top_overlay = mutable_appearance(atom_parent.icon, "[atom_parent.icon_state]_top")
			top_overlay.pixel_y = -LAZYLEN(ingredient_names) - 1
			top_overlay.pixel_z = 3 * LAZYLEN(ingredient_names) + 4
			atom_parent.add_overlay(filling)
			atom_parent.add_overlay(top_overlay)
			return
		if(CUSTOM_INGREDIENT_ICON_FILL)
			if (top_overlay)
				filling.color = mix_color(filling.color)
				atom_parent.cut_overlay(top_overlay)
			top_overlay = filling
		if(CUSTOM_INGREDIENT_ICON_LINE)
			filling.pixel_w = filling.pixel_z = rand(-8,3)
	atom_parent.add_overlay(filling)


///Takes the reagents from an ingredient.
/datum/component/ingredients_holder/proc/handle_reagents(obj/item/ingredient)
	var/atom/atom_parent = parent
	if (atom_parent.reagents && ingredient.reagents)
		atom_parent.reagents.maximum_volume += ingredient.reagents.maximum_volume // If we don't do this custom food starts voiding reagents past a certain point.
		ingredient.reagents.trans_to(atom_parent, ingredient.reagents.total_volume)
	return


///Adds a new ingredient and updates the parent's name.
/datum/component/ingredients_holder/proc/add_ingredient(obj/item/ingredient, atom/replacement_location)
	var/atom/atom_parent = parent

	if (replacement)
		var/atom/replacement_parent = new replacement(replacement_location || atom_parent.drop_location())
		ingredient.forceMove(replacement_parent)
		replacement = null
		replacement_parent.TakeComponent(src)
		handle_reagents(parent)
		qdel(atom_parent)
		atom_parent = parent

	handle_reagents(ingredient)

	LAZYADD(ingredient_names, "\a [ingredient.name]")
	if(isitem(atom_parent))
		var/obj/item/item_parent = atom_parent
		if(ingredient.w_class > item_parent.w_class)
			item_parent.update_weight_class(ingredient.w_class)
	if(!custom_name)
		set_custom_name(ingredient)
	atom_parent.name = "[custom_adjective()] [custom_name] [initial(atom_parent.name)]"
	SEND_SIGNAL(atom_parent, COMSIG_ATOM_CUSTOMIZED, ingredient)
	SEND_SIGNAL(ingredient, COMSIG_ITEM_USED_AS_INGREDIENT, atom_parent)

	get_fill(ingredient)
	handle_materials(ingredient)

	if(ingredient.loc != atom_parent)
		ingredient.forceMove(atom_parent)

///Rebuilds the custom materials the holder is composed of based on the materials of each ingredient
/datum/component/ingredients_holder/proc/handle_materials(obj/item/ingredient, remove = FALSE)
	if(!ingredient.custom_materials)
		return
	var/atom/atom_parent = parent
	var/list/new_materials = atom_parent.custom_materials?.Copy() || list()
	for(var/mat in ingredient.custom_materials)
		new_materials[mat] += ingredient.custom_materials[mat] * (remove ? -1 : 1)
	atom_parent.set_custom_materials(new_materials)

///Gives an adjective to describe the size of the custom food.
/datum/component/ingredients_holder/proc/custom_adjective()
	switch(LAZYLEN(ingredient_names))
		if (0 to 2)
			return "small"
		if (3 to 5)
			return "standard"
		if (6 to 8)
			return "big"
		if (8 to 11)
			return "ridiculous"
		if (12 to INFINITY)
			return "monstrous"


///Gives the type of custom food (based on what the first ingredient was).
/datum/component/ingredients_holder/proc/set_custom_name(obj/item/ingredient)
	if (istype(ingredient, /obj/item/food/meat))
		var/obj/item/food/meat/meat = ingredient
		if (meat.subjectname)
			custom_name = meat.subjectname
			return
		if (meat.subjectjob)
			custom_name = meat.subjectjob
			return
	custom_name = ingredient.name

///Returns the color of the input mixed with the top_overlay's color.
/datum/component/ingredients_holder/proc/mix_color(color)
	if(length(filling_colors) == 1 || !top_overlay)
		return color
	var/list/rgbcolor = list(0,0,0,0)
	var/customcolor = GetColors(color)
	var/ingcolor = GetColors(top_overlay.color)
	rgbcolor[1] = (customcolor[1]+ingcolor[1])/2
	rgbcolor[2] = (customcolor[2]+ingcolor[2])/2
	rgbcolor[3] = (customcolor[3]+ingcolor[3])/2
	rgbcolor[4] = (customcolor[4]+ingcolor[4])/2
	return rgb(rgbcolor[1], rgbcolor[2], rgbcolor[3], rgbcolor[4])


///Copies over the parent's fillings and name of ingredients to the processing results (such as slices when the parent is cut).
/datum/component/ingredients_holder/proc/on_processed(datum/source, mob/living/user, obj/item/ingredient, list/atom/results)
	SIGNAL_HANDLER

	// Reagents are not transferred since that should be handled elsewhere
	// while custom materials are already transferred evenly between results by atom/proc/StartProcessingAtom()
	for (var/atom/result as anything in results)
		result.AddComponent(/datum/component/ingredients_holder, null, fill_type, ingredient_type = ingredient_type, max_ingredients = max_ingredients, processed_holder = src)

/// Pizzas have unique slicing interaction so we need to do this
/datum/component/ingredients_holder/proc/on_slice_taken(datum/source, mob/living/user, obj/item/slice)
	SIGNAL_HANDLER
	slice.AddComponent(/datum/component/ingredients_holder, null, fill_type, ingredient_type = ingredient_type, max_ingredients = max_ingredients, processed_holder = src)

/**
 * Adds context sensitivy directly to the customizable reagent holder file for screentips
 * Arguments:
 * * source - refers to item that will display its screentip
 * * context - refers to, in this case, an item that can be customized with other reagents or ingrideints
 * * held_item - refers to the item in your hand, which is hopefully an ingredient
 * * user - refers to user who will see the screentip when the proper context and tool are there
 */
/datum/component/ingredients_holder/proc/on_requesting_context_from_item(datum/source, list/context, obj/item/held_item, mob/user)
	SIGNAL_HANDLER

	// only accept valid ingredients
	if (isnull(held_item) || !valid_ingredient(held_item))
		return NONE

	context[SCREENTIP_CONTEXT_LMB] = "[screentip_verb] [held_item]"

	return CONTEXTUAL_SCREENTIP_SET

/// Clear refs if our food "goes away" somehow
/datum/component/ingredients_holder/proc/food_exited(datum/source, atom/movable/gone)
	SIGNAL_HANDLER
	LAZYREMOVE(ingredient_names, "\a [gone.name]")
	handle_materials(gone, remove = TRUE)
