# Pipe networks and construction

## PIPE-1: RPD reprogram mode runtimes and leaves one-sided connections (high, verified)

- **Fixed in:** [`atmos/rpd`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/rpd)
- **Location:** `code/game/objects/items/rcd/RPD.dm:385-401`
- **What's wrong:** when reprogramming adds a new allowed direction, the code first calls `node.disconnect(target_smart_pipe)` on every connected node.
  - The generic `disconnect()` (`atmosmachinery.dm:408-410`) calls `destroy_network()` on the smart pipe.
  - `/datum/pipeline/Destroy()` then sets every member's `parent` to null and clears the `parents[]` entries.
  - The re-add loop then calls `connected_device.add_member(target_smart_pipe)`:
    - A pipe node runs `parent.add_member()` on a null `parent`.
    - A component node gets null back from `return_pipenet()` and CRASHes.
    - If the new-direction node comes first, `merge(null)` runtimes.
> **Narrower than first written.** A test showed both runtimes (`merge(null)` → "Cannot read null.air", then "Cannot execute null.add member()"). A runtime only aborts the proc it happens in, so the RPD's re-add loop carries on. After the rebuild, gas reached the new neighbour and was conserved. The one-sided connection described below did not show up in that test. The later "destroy the pipe, index 0" effect is untested.

- **Effect:**
  - Reprogramming a connected smart pipe runtimes every time.
  - The loop aborts before the other nodes run `atmos_init()`, so the new neighbour M never adds the pipe to its nodes. The connection is one-sided:
    - Gas can be stranded or duplicated when the rebuild expands through M.
    - Destroying the reprogrammed pipe later hits `nodes[nodes.Find(reference)]` with index 0.
    - Destroying M is a hard delete.

## PIPE-2: `replace_pipenet` only updates the first matching port (medium, verified)

- **Fixed in:** [`atmos/pipenet-bookkeeping`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pipenet-bookkeeping)
- **Location:** `code/modules/atmospherics/machinery/components/components_base.dm:226-227`
- **What's wrong:** `parents[parents.Find(Old)] = New` replaces only the first match. A component with both ports in the same pipeline has `parents = [P1, P1]`.
- **Effect:**
  - A pump inside a closed pipe loop that is then connected to another network: `P2.merge(P1)` fixes only `parents[1]`, and `parents[2]` still points at the deleted P1. That is a hard delete of the pipeline datum.
  - Unwrenching the pump then merges port 2's gas into the dead `P1.air`, so that gas is lost.
  - The gas loss is confirmed by a test (10 mol in the pump's port became 0). A debug log showed `parents[2]` pointing at a qdeleted pipeline.
  - The pump's `Destroy` did not trip the `nullify_pipenet` CRASH, because the dead pipeline is already fully qdeleted.

## PIPE-3: A shuttle move permanently nulls a component's port gas mix (medium, confirmed)

- **Fixed in:** [`atmos/pipenet-bookkeeping`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pipenet-bookkeeping)
- **Location:** `components_base.dm:143-147`, called from `code/modules/shuttle/mobile_port/shuttle_move_callbacks.dm:282`
- **What's wrong:** `nullify_node(i)` does `airs[i] = null`. That is only safe during Destroy, but `lateShuttleMove` also calls it on live components whose node is no longer adjacent. Only `Initialize` ever creates `airs[i]`.
- **Effect:** for a component at the shuttle edge that was joined to a station pipe:
  - Its gas is deleted.
  - The rebuild stack_traces "null machinery gasmix".
  - `process_atmos`, the analyzer and unwrenching runtime from then on.

## PIPE-4: The RPD unwrench upgrade never continues to delete or rebuild (low, confirmed)

- **Fixed in:** [`atmos/rpd`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/rpd)
- **Location:** `code/game/objects/items/rcd/RPD.dm:318-320`
- **What's wrong:** `attack_target = attack_target.wrench_act(user, src)`, then `if(!isatom(attack_target)) return ITEM_INTERACT_FAILURE`. `wrench_act` returns `ITEM_INTERACT_*` numbers, never the dropped pipe item.
- **Effect:** with the wrench upgrade, destroy mode only unwrenches, and build mode never builds over the old pipe.

## PIPE-5: The pipe fitting welder check uses `istype` on a type path (low, verified)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes)
- **Location:** `code/game/machinery/pipe/construction.dm:316`
- **What's wrong:** `istype(pipe_type, /obj/machinery/atmospherics/components)` is always false for a path. It should be `ispath`.
- **Effect:** component fittings (vents, pumps, filters...) can be welded into a sliced pipe, which wastes their materials.

## PIPE-6: Unwrenching skips the delay for any component in vacuum (low, confirmed)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes)
- **Location:** `code/modules/atmospherics/machinery/atmosmachinery.dm:429, 448-449`
- **What's wrong:** components don't override `return_air()`, so `int_air` is the turf's air. The pipe-only `empty_pipe` check then applies to every component.
- **Effect:** in space, a pump full of gas unwrenches instantly, with no "You begin to unfasten" warning.

## PIPE-7: Layer adaptor overlays always get absolute layer 1 (low, visual, verified)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes)
- **Location:** `code/modules/atmospherics/machinery/pipes/layermanifold.dm:81`
- **What's wrong:** `FLOAT_LAYER - HAS_TRAIT(...) ? 1 : 0.01` evaluates as `(FLOAT_LAYER - x) ? 1 : 0.01`, which is always 1. This came in with #97643.

## PIPE-8: Merging into a pipeline that is mid-rebuild (medium, plausible)

- **Fixed in:** [`atmos/pipenet-bookkeeping`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/pipenet-bookkeeping)
- **Location:** `code/modules/atmospherics/machinery/datum_pipeline.dm:151-188`
- **What's wrong:** `add_member` calls `merge(adjacent_pipe.parent)` without checking for null or `building`.
- **Effect:**
  - Building next to a pipe the rebuild hasn't reached yet runs `merge(null)`.
  - Building next to a pipe it has reached merges the half-built pipeline and drops its expansion border.
  - Either way, gas can be stranded or duplicated.

## PIPE-9: Minor (low)

- **Fixed in:** [`atmos/small-fixes`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/small-fixes) (pink pipes) and [`atmos/ventcrawl`](https://github.com/sohpea-cloub/tgstation-slop/compare/master...atmos/ventcrawl) (multi-z ventcrawl)
- `pipe_colors_ordered` has no `COLOR_LIGHT_PINK`, so pink pipes sort the same as omni. Cosmetic.
- A ventcrawler in a pipe directly below a multi-z adapter on the same layer can move up into it without being connected, because `connection_check` skips the direction check for multi-z targets.

## Checked, nothing solid

`reconcile_air`, `temporarily_store_air`, `build_pipeline`, `expand_pipeline`, smart pipe `set_volume`, heat exchange math, the smart pipe bitmask code, the color adapter, the bridge pipe, mapping helpers, multi-z node linking and `nullify_pipenet`.
