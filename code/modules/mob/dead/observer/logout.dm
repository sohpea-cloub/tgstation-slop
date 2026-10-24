/mob/dead/observer/Logout()
	if (client)
		client.images -= (GLOB.ghost_images_default+GLOB.ghost_images_simple)

	if(observetarget && ismob(observetarget))
		cleanup_observe()
	..()
	// The body's med HUD shows whether its player can be defibbed, which counts clients in the player list
	var/mob/living/former_body = mind?.current
	if(isliving(former_body))
		former_body.med_hud_set_status()
	// This is one of very few spawn()s left in our codebase
	// Yes it needs to be like this
	// No, you're not allowed to use spawn() yourself, unless you're making something that needs to work outside timers
	// Don't be a dumbass, I will always be watching
	spawn(0)
		if(src && !key) //we've transferred to another mob. This ghost should be deleted.
			qdel(src)
