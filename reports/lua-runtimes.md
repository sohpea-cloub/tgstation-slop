# #lua-runtimes: runtimes in procs called from Lua are logged as an empty "uncaught runtime error:" and can lock the admin out

| | |
|---|---|
| Issues | No GitHub issue number. Found as a tooling problem: every Lua editor run seemed to log an empty `uncaught runtime error:`, and `SS13.wait` / `SS13.set_timeout` seemed never to fire. Verdict: the empty log line was **verified** (and fixed); "timers never fire" was **not reproduced**. |
| Status | Verified, fixed on the branch below (one commit) |
| Fix branch | https://github.com/sohpea-cloub/tgstation-slop/tree/fix/lua-runtimes |
| Tested on | tgstation master `87b93338`, 2026-10-23 |

## Summary

When a DM proc that a Lua script calls hits a runtime (a `CRASH()`, a null dereference, a bad proc name, ...), BYOND hands `/world/Error` a null exception instead of the real one. The runtime log gets an empty `uncaught runtime error: ` line, the Lua editor's log shows nothing, and the call just returns nil to the script. The same unwinding skips the clean-up in `WrapAdminProcCall`, which leaves `GLOB.AdminProcCaller` set and makes the admin's later admin verbs fail as "permission elevation" attempts for the rest of the round. The fix catches the exception in the Lua wrappers and rethrows it, so it is logged normally, and makes `WrapAdminProcCall` and `HandleUserlessProcCall` restore their state before rethrowing.

## The bug

Two things were reported from Lua editor use:

1. Running Lua logged lines like `uncaught runtime error: ` (with nothing after the colon) in `runtime.log`. Some scripts produced hundreds of them: one script that looped with `SS13.wait(0.1)` and called a proc that runtimed on each pass produced one empty line per 0.1 s iteration.
2. `SS13.wait` and `SS13.set_timeout` were said never to resume or fire.

What was really happening for (1): the Lua itself is not at fault. Any DM runtime inside a proc that dreamluau calls through byondapi loses its exception. That covers the wrappers in `code/modules/admin/verbs/lua/_wrappers.dm` (proc calls on datums and globals, variable get and set, `print`) and `/proc/_new` (used for `dm.new` / `SS13.new`). The message, file, line and stack are all lost, `SSlua.log_involved_runtime` never runs, and the Lua editor's log shows no runtime. The call returns nil and the script keeps going, so a script cannot tell that a call failed.

Running `return 1` alone logs nothing, so a plain Lua run does not produce the line. It appears only when a called proc runtimes.

The side effect on the admin: after a runtime inside an admin proc call, the admin's verbs stop working (see Cause, part 2).

## Reproduction

On master, in the lobby, as an admin:

1. Open the Lua editor (Open Lua Editor), create a state, and run `return 1`. Check the newest round's `runtime.log`: no `uncaught runtime error` line (0 matches). This shows Lua itself is not the trigger.
2. Run:
   ```lua
   dm.global_procs._stack_trace("hello from lua", "x.dm", 5)
   return 3
   ```
   (`stack_trace` is a macro in `code/__DEFINES/stack_trace.dm`, so a global proc named `stack_trace` does not exist; the real proc is `_stack_trace`, which does `CRASH(...)`.)
3. Result: the Lua editor's log shows only `finished` with return value 3. `runtime.log` gets one new line, `RUNTIME: uncaught runtime error: ` with nothing after it. Calling `dm.global_procs.stack_trace(...)` (no such proc) produced the same empty line.
4. To see what `/world/Error` receives, a temporary debug build of `/world/Error` was used that logged the argument. It reported that `E` was null (`null=1`, not text, not a number, not a datum), with `usr` set and a Lua stack present.
5. The same happened with `DMFAST_FIXES=none` set for the server, so the BYOND build's optional bug fixes do not explain it. The patched BYOND's other speed patches could not be switched off in this setup, so stock BYOND was not run; it is therefore not established whether stock BYOND behaves identically, although the DM-side fix below removes the symptom either way.
6. The `WrapAdminProcCall` lock-out was seen while testing a build in which the Lua wrappers already rethrew the exception (so the runtime unwound through `WrapAdminProcCall`). Reading `GLOB.AdminProcCaller` and `GLOB.AdminProcCallCount` back in Lua then gave the admin's ckey and `1`, and the next admin verb was refused with `PERMISSION ELEVATION: ... attempted to dynamically invoke admin verb '/datum/admin_verb/lua_editor'.` Open Lua Editor, and every other admin verb, stayed refused. On unmodified master the empty-log behavior comes first, and the lock-out was not separately exercised there; it follows from the code (see Cause) but was not directly observed on master.
7. A third trigger: a script that keeps running after its `usr` mob has lost its client (for example after possessing a different mob from the script). `WrapAdminProcCall` then hits `CRASH("WrapAdminProcCall with no ckey ...")` and that is lost in the same way.

Logs from other test runs on the same day showed the same empty lines whenever a script called game procs that runtimed (for example one script that manipulated chameleon gun ammo casings produced one).

## Cause

Part 1, the lost exception. `/world/Error` begins:

```dm
/world/Error(exception/E, datum/e_src)
	GLOB.total_runtimes++
	if(!istype(E)) //Something threw an unusual exception
		log_world("uncaught runtime error: [E]")
		return ..()
```

(`code/modules/error_handler/error_handler.dm:7-12`). When a runtime is raised inside a proc entered from byondapi and no DM `try`/`catch` is above it, BYOND passes `null` to `world/Error`. `istype(null)` is false, so the empty line is logged and the function returns before any of the Lua-aware logging (`SSlua.log_involved_runtime`, line 140 of `code/controllers/subsystem/lua.dm`) can run. In that byondapi-entered stack the runtime only kills the crashing proc; its DM callers continue, which is why `WrapAdminProcCall` still decremented its counter afterwards in the test.

The Lua wrappers were registered in `code/controllers/subsystem/lua.dm:26-31` and defined in `code/modules/admin/verbs/lua/_wrappers.dm`, none of which had a `try`/`catch`. `/proc/_new` (`code/modules/admin/verbs/SDQL2/SDQL_2_wrappers.dm:107`) was registered directly as the `new` wrapper.

Part 2, the admin lock-out. In `WrapAdminProcCall` (`code/modules/admin/callproc/callproc.dm:182`):

```dm
	if(!is_remote_handler)
		GLOB.AdminProcCaller = user_identifier //if this runtimes, too bad for you
		++GLOB.AdminProcCallCount
		. = world.WrapAdminProcCall(target, procname, arguments)
		GLOB.AdminProcCallCount--
		if(GLOB.AdminProcCallCount == 0)
			GLOB.AdminProcCaller = null
```

(lines 207-213). If the called proc's runtime unwinds through this frame (which it does as soon as something above it catches and rethrows, or in ordinary DM), the decrement and the reset are skipped. `AdminProcCaller` then stays set to the admin's ckey and `AdminProcCallCount` stays at 1, so `IsAdminAdvancedProcCall()` (line 230) is true for that admin from then on. The next admin verb goes through `dynamic_invoke_verb` in `code/controllers/subsystem/admin_verbs.dm:99-101`, which refuses it as a permission elevation attempt. `HandleUserlessProcCall` (`callproc.dm:66-76`) has the same shape: a runtime skips `usr = lastusr` and `handler.remove_caller(user)`.

## Fix

One commit, "Fix lua-runtimes: runtimes in procs called from Lua are logged empty and can lock the admin out", touching three files:

- `code/modules/admin/verbs/lua/_wrappers.dm`: every Lua wrapper (get var, set var, datum proc call, global proc call, print) now runs its body inside `try ... catch(var/exception/...)` and rethrows the caught exception (two local macros, `LUA_WRAPPER_TRY` and `LUA_WRAPPER_CATCH`, keep this short and are `#undef`ed at the end of the file). Rethrown, the exception reaches `/world/Error` as a real exception, so the full runtime appears in `runtime.log` and View Runtimes, and a `status: runtime` entry with file, line, message and DM and Lua stacks appears in the Lua editor's log. A new `/proc/wrap_lua_new` wraps `_new` the same way.
- `code/controllers/subsystem/lua.dm`: the `new` wrapper is now `/proc/wrap_lua_new` instead of `/proc/_new`.
- `code/modules/admin/callproc/callproc.dm`: `WrapAdminProcCall` catches an exception from the called proc, restores `AdminProcCallCount` and `AdminProcCaller`, and then rethrows. `HandleUserlessProcCall` restores `usr` and the handler's caller list before rethrowing. The catch in `WrapAdminProcCall` is inline rather than a new global proc, so no new callable global proc is exposed to admins. The old comment "if this runtimes, too bad for you" was removed.

No alternative was recorded as tried. The exception data is already gone by the time `/world/Error` runs, so the catch has to be in DM above the byondapi entry.

## Verification

Tested on a server built with the fix, in the lobby, through the Lua editor:

- `dm.global_procs._stack_trace("global crash", ...)`, followed by a deliberate call to `SSlua:log_involved_runtime(nil, nil, nil)`: `runtime.log` contains `runtime error: global crash` and `Cannot read null.file` (from the deliberate call, `code/controllers/subsystem/lua.dm:141`), each with a stack; the Lua editor's log has both as `status: runtime` entries; afterwards `GLOB.AdminProcCaller` read back as nil and the count as 0. No `uncaught` lines were written.
- After those runtimes, Open Lua Editor worked again (no `PERMISSION ELEVATION` message).
- A mob losing its client mid-script (the script moved the player to a new mouse, then called a proc): `WrapAdminProcCall with no ckey: ... _get_step` was now logged with file `callproc.dm:202` and a stack, in both `runtime.log` and the Lua log.
- A Lua loop of three `SS13.wait(0.1)` iterations, each calling a crashing proc: three proper runtime entries (stacks include the `resume` and the SSlua `fire`), the loop finished, `SSlua.state` read 2 (running) and `__Timer_timer_processing` read false. The rethrow does not escape into `SSlua.fire`.

Not checked:

- Whether stock (unpatched) BYOND produces the same null exception on master.
- The lock-out through Advanced ProcCall or SDQL `CALL` on unmodified master (likely reachable through any called proc that runtimes, but not tested).
- Server-wide behavior over a full round, and any `try`/`catch` cost on hot Lua paths.
- A later test of this branch by another run (a different, unrelated issue investigation) reported DreamDaemon crashing twice at the `resume` call in `code/modules/admin/verbs/lua/lua_state.dm` (around line 188) when `SS13.wait` was combined with Lua-triggered runtimes. That was not investigated here, so it is not known whether the catch-and-rethrow change is involved. This should be checked before merging.

## Notes

- **Timers (`SS13.wait`, `SS13.set_timeout`): not reproduced.** They fired in every test, before and after the fix: five `SS13.wait(1)` calls resumed at world.time 840, 851, 862, 873, 884; `set_timeout(0.1)` fired (its callback has a nil `usr`, which goes through `HandleUserlessProcCall`); and wait and set_timeout also worked right after the script's mob lost its client. The cause of the original report could not be found. Candidate mechanisms and how to check them in a stuck state:
  - `SSlua` is stuck: a runtime in `SSlua.fire()`'s own DM code (outside a Lua call) leaves the subsystem in `SS_SLEEPING` (see `ignite` in `code/controllers/subsystem.dm:139-152`; `master.dm` skips subsystems that are not idle), so timers and sleeps stop. Check `dm.global_vars.SSlua.state` (0 idle or 2 running are fine; 4 means stuck).
  - `__Timer_timer_processing` stuck true (`lua/timer.lua`) if `__Timer_timer_process` errors mid-loop. Check it from Lua.
  - Before this fix, a failed proc call returned nil silently, which can look like a timer "didn't fire" when its callback's call failed.
- Until a build has the fix: treat an empty `uncaught runtime error:` as "a proc my Lua called runtimed and returned nil"; check return values for nil and print around calls, or repeat the call with SDQL `CALL` / Advanced ProcCall, which do log the runtime. If admin verbs start failing with `PERMISSION ELEVATION` after a runtime in an admin proc call, the round is poisoned for that admin (`GLOB.AdminProcCaller` is protected and cannot be reset); a server restart clears it.
- After moving the script's client to another mob (possession, changing ckey), later proc calls from the same script fail with "no ckey", because `usr` is the old clientless mob. Do the move last, or do it from a `SS13.set_timeout` callback (which runs with `usr` nil).
- From Lua, `stack_trace` cannot be called (it is a macro); use `dm.global_procs._stack_trace(msg, file, line)`.
- Design point for maintainers: with the rethrow, a runtime in a Lua-called proc now goes through the normal runtime handling, so a script that triggers one every 0.1 s will log full runtimes instead of one blank line each time. Whether the usual runtime cooldown and silencing applies to these was not checked.
