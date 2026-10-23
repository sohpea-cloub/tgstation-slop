#ifndef DISABLE_DREAMLUAU
/**
 * The procs below are the only way lua code calls into DM: dreamluau calls them through byondapi.
 * A runtime that escapes a proc called through byondapi reaches /world/Error with a null exception,
 * so it is logged as an empty "uncaught runtime error: " with no message, file, line or stack,
 * and never reaches the lua state's log. Catching it in DM keeps the exception datum: rethrown, it
 * is handled like any other runtime (runtime log, View Runtimes, and the lua editor's log).
 */
#define LUA_WRAPPER_TRY try
#define LUA_WRAPPER_CATCH catch(var/exception/lua_wrapper_exception) { throw lua_wrapper_exception }

/proc/wrap_lua_new(type, list/arguments)
	SHOULD_NOT_SLEEP(TRUE)
	LUA_WRAPPER_TRY
		return _new(type, arguments)
	LUA_WRAPPER_CATCH

/proc/wrap_lua_get_var(datum/thing, var_name)
	SHOULD_NOT_SLEEP(TRUE)
	LUA_WRAPPER_TRY
		if(thing == world)
			return world.vars[var_name]
		if(ref(thing) == "\[0xe000001\]") //This weird fucking thing is like global.vars, but it's not a list and vars is not a valid index for it and I really don't fucking know.
			return global.vars[var_name]
		if(thing.can_vv_get(var_name))
			return thing.vars[var_name]
	LUA_WRAPPER_CATCH

/proc/wrap_lua_set_var(datum/thing_to_set, var_name, value)
	SHOULD_NOT_SLEEP(TRUE)
	LUA_WRAPPER_TRY
		thing_to_set.vv_edit_var(var_name, value)
	LUA_WRAPPER_CATCH

/proc/wrap_lua_datum_proc_call(datum/thing_to_call, proc_name, list/arguments)
	SHOULD_NOT_SLEEP(TRUE)
	if(!usr)
		usr = GLOB.lua_usr
	var/ret
	LUA_WRAPPER_TRY
		if(usr)
			ret = WrapAdminProcCall(thing_to_call, proc_name, arguments)
		else
			ret = HandleUserlessProcCall("lua", thing_to_call, proc_name, arguments)
	LUA_WRAPPER_CATCH
	return ret

/proc/wrap_lua_global_proc_call(proc_name, list/arguments)
	SHOULD_NOT_SLEEP(TRUE)
	if(!usr)
		usr = GLOB.lua_usr
	var/ret
	LUA_WRAPPER_TRY
		if(usr)
			ret = WrapAdminProcCall(GLOBAL_PROC, proc_name, arguments)
		else
			ret = HandleUserlessProcCall("lua", GLOBAL_PROC, proc_name, arguments)
	LUA_WRAPPER_CATCH
	return ret

/proc/wrap_lua_print(state_id, list/arguments)
	SHOULD_NOT_SLEEP(TRUE)
	LUA_WRAPPER_TRY
		var/datum/lua_state/target_state
		for(var/datum/lua_state/state as anything in SSlua.states)
			if(state.internal_id == state_id)
				target_state = state
				break
		if(!target_state)
			return
		var/print_message = jointext(arguments, "\t")
		var/result = list("status" = "print", "message" = print_message)
		INVOKE_ASYNC(target_state, TYPE_PROC_REF(/datum/lua_state, log_result), result, TRUE)
		log_lua("[target_state]: [print_message]")
	LUA_WRAPPER_CATCH

#undef LUA_WRAPPER_TRY
#undef LUA_WRAPPER_CATCH
#endif
