///Tries to escape activity, has observers to cancel if needed
/datum/bt_node/subtree/escape_captivity
	behavior_tree_json = "code/datums/ai/basic_mobs/basic_subtrees/escape_captivity.bt.json"

/// Pacifist variant: never attacks objects, only resists.
/datum/bt_node/subtree/escape_captivity/pacifist
	behavior_tree_json = "code/datums/ai/basic_mobs/basic_subtrees/escape_captivity_pacifist.bt.json"

/// Dopey variant: doesn't try to get out of containers (crates, lockers) or off of buckles, so they can be boxed or sat in a chair. Still resists grabs and restraints.
/datum/bt_node/subtree/escape_captivity/pacifist/dopey
	behavior_tree_json = "code/datums/ai/basic_mobs/basic_subtrees/escape_captivity_dopey.bt.json"
