extends GutTest
## Reload interruption and the staged reload quantum. A mainhand slot switch
## during a gun reload requests an abort on the gun
## (gun_item.request_reload_abort), which preempts the in-flight staged
## reload at once. A staged reload lands one round per ReloadTimer cycle,
## each debited as it lands (owner ruling: one press loads the webley
## cylinder one round at a time up to 6), so the abort stops the remaining
## rounds: the rounds already inserted stand, the rest stay in the
## inventory, and the character reload state clears so a parked slot switch
## can run. The unload (hold R) path keeps the inventory hard lock.
##
## Quantum (owner decision): one press lasts about as long as the authored
## reload animation; the staged rounds spread across the clip. The per-cycle
## time is the weapon reload clip length divided by the rounds THIS press
## stages, clamped to 0.3 to 3.0 s, cached at press time; without a
## resolvable reload clip the press falls back to reload_time per cycle.
##
## Harness: real webley scene (its timers/sounds come from _gun_item.tscn)
## with a stub owner carrying a real HumanoidCharacterState and a real
## Inventory, the same pattern as test_bomb_cleanup. reload_time stays at
## 0.25 (the composite/fallback value). The reload clip is stubbed through a
## PRIVATE copy of the default AnimationLibrary (the scene's sub_resource
## library is shared across instantiate() calls, so it must never be
## mutated); pass stub_clip_length < 0 to test against the real 8.067 s
## clip, or 0.0 to omit the clip and exercise the reload_time fallback.

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const WebleyScene = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
const AmmoResource = preload("res://resources/tiny_items/ammunition/455_webley.tres")
const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")
const Revolver1 = preload("res://resources/sounds/reloading/revolver/revolver1.wav")
const Revolver2 = preload("res://resources/sounds/reloading/revolver/revolver2.wav")
const Revolver6 = preload("res://resources/sounds/reloading/revolver/revolver6.wav")


class ReloadOwnerStub extends Node:
	var state = null
	var inventory = null


func _make_harness(start_ammo : int, start_tiny : int, stage_amount : int = 2, stub_clip_length : float = 0.6) -> Dictionary:
	var owner_stub : ReloadOwnerStub = ReloadOwnerStub.new()
	add_child_autofree(owner_stub)
	var params : Node = ParametersScript.new()
	params.name = "Parameters"
	var input_node : Node = InputScript.new()
	input_node.name = "Input"
	var state : Node = StateScript.new()
	state.name = "State"
	owner_stub.add_child(params)
	owner_stub.add_child(input_node)
	owner_stub.add_child(state)
	state.owner = owner_stub
	owner_stub.state = state

	var inv = add_child_autofree(InventoryScript.new())
	owner_stub.inventory = inv

	var webley = WebleyScene.instantiate()
	add_child_autofree(webley)
	# Freeze AFTER add_child: _ready re-arms the dropped physics state
	# (set_physics_dropped resets freeze), and the close-beat awaits added up
	# can cross the 3.2 s free-fall delete window inside one test.
	webley.freeze = true
	webley.owner_character = owner_stub
	webley.ammunition_capacity = 6
	webley.reload_amount = stage_amount
	webley.reload_time = 0.25
	if stub_clip_length >= 0.0:
		_own_reload_library(webley, stub_clip_length)
	webley.current_ammo_type = AmmoResource
	webley.current_ammo = start_ammo
	inv.tiny_items[AmmoResource] = start_tiny
	return {"owner": owner_stub, "state": state, "inventory": inv, "webley": webley}


func _own_reload_library(webley : Node, stub_clip_length : float) -> void:
	var anim_player : AnimationPlayer = webley.animation_player
	var shared : AnimationLibrary = anim_player.get_animation_library("")
	var private_lib := AnimationLibrary.new()
	for anim_name in shared.get_animation_list():
		if stub_clip_length == 0.0 and anim_name == "reload":
			continue
		private_lib.add_animation(anim_name, shared.get_animation(anim_name))
	if stub_clip_length > 0.0:
		private_lib.remove_animation("reload")
		var stub_anim := Animation.new()
		stub_anim.length = stub_clip_length
		private_lib.add_animation("reload", stub_anim)
	anim_player.remove_animation_library("")
	anim_player.add_animation_library("", private_lib)


func test_abort_preempts_the_in_flight_stage() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	assert_true(state.is_reloading, "reload() must start a stage")
	assert_eq(state.reloading_item, webley, "reload() must register the reloading item on the state")

	# The slot switch request arrives while the stage is in flight. The abort
	# plays the close beat FIRST (owner rule, research doc 6.1: the cylinder
	# closes before the swap runs) and only clears the state when the beat
	# ends, which is what reload_aborted reports.
	webley.request_reload_abort()
	assert_true(await wait_for_signal(webley.reload_aborted, 3.0), "the abort completes after the close beat")

	assert_false(state.is_reloading, "the abort clears is_reloading once the close beat ends")
	assert_null(state.reloading_item, "the abort clears reloading_item once the close beat ends")
	assert_eq(webley.current_ammo, 2, "the rounds loaded before the stage must stand")
	assert_eq(h.inventory.tiny_items[AmmoResource], 10, "the queued rounds must not be consumed")

	# The preempted timer must stay dead: no late load, no late boundary.
	await wait_seconds(0.5)
	assert_eq(webley.current_ammo, 2, "the preempted stage must not load rounds later")
	assert_eq(h.inventory.tiny_items[AmmoResource], 10, "the preempted stage must not consume ammo later")
	assert_false(state.is_reloading, "the preempted stage must not restore the reload state")
	assert_signal_not_emitted(webley, "reload_stage_finished")


func test_abort_with_no_stage_in_flight_is_a_no_op() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.request_reload_abort()
	assert_false(state.is_reloading, "an abort with no reload must not touch the state")
	assert_null(state.reloading_item, "an abort with no reload must not register anything")
	assert_signal_not_emitted(webley, "reload_stage_finished")


func test_reload_after_abort_loads_only_the_remaining_rounds() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state

	webley.reload()
	webley.request_reload_abort()
	assert_eq(webley.current_ammo, 2, "the aborted stage must leave the loaded rounds standing")
	# The close beat plays before the state clears; a re-press inside the
	# beat window is refused, so wait out the beat first.
	assert_true(await wait_for_signal(webley.reload_aborted, 3.0), "the abort completes after the close beat")

	# Re-initiating later loads stage-sized steps from the standing count.
	webley.reload()
	assert_true(await wait_for_signal(webley.reload_stage_finished, 4.0), "the follow-up stage must finish")
	assert_eq(webley.current_ammo, 4, "the follow-up stage loads the next stage amount")
	assert_eq(h.inventory.tiny_items[AmmoResource], 8, "the follow-up stage consumes exactly its rounds")

	webley.reload()
	assert_true(await wait_for_signal(webley.reload_stage_finished, 4.0), "the last stage must finish")
	assert_eq(webley.current_ammo, 6, "the last stage tops the weapon up to capacity")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the follow-up stages consume exactly their rounds")

	# A full weapon refuses further reloads.
	webley.reload()
	assert_false(state.is_reloading, "a full weapon must not enter a reload stage")
	assert_eq(webley.current_ammo, 6, "a full weapon must not gain rounds")


func test_webley_single_stage_reload_aborts_before_any_round_lands() -> void:
	# A full-cylinder-sized stage config (stage_amount 6 == capacity): the
	# interrupt must preempt that stage, otherwise the whole reload runs to
	# completion. Generic stage-amount pin; the shipped webley loads one round
	# per gate (next test).
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	assert_true(state.is_reloading, "the single-stage reload must start")
	await wait_seconds(0.1)
	webley.request_reload_abort()
	assert_true(await wait_for_signal(webley.reload_aborted, 3.0), "the single-stage abort completes after the close beat")

	assert_false(state.is_reloading, "the single-stage abort clears is_reloading after the close beat")
	assert_null(state.reloading_item, "the single-stage abort clears reloading_item after the close beat")
	assert_eq(webley.current_ammo, 0, "no queued round may land after the abort")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the full cylinder's worth of ammo must stay in the inventory")

	# A fresh reload without an interrupt loads the whole cylinder.
	webley.reload()
	assert_true(await wait_for_signal(webley.reload_stage_finished, 4.0), "the uninterrupted single-stage reload must finish")
	assert_eq(webley.current_ammo, 6, "an uninterrupted single-stage reload fills the weapon")
	# The inventory erases a tiny item key at zero, so read via the accessor.
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 0, "the uninterrupted reload consumes all 6 rounds")


func test_shipped_webley_one_press_loads_the_cylinder_one_round_at_a_time() -> void:
	# Owner ruling, verbatim: "The webley used to reload correctly 1 at a time
	# up to 6 with ONE press." One press stages the whole cylinder; the rounds
	# land ONE per cycle at the clip-derived quantum (0.6 s stub clip / 6
	# rounds, floored to 0.3 s), each with its per-chamber sound, until the
	# cylinder is full. Pins the staged chain: after the first cycle exactly
	# one round has landed (no jump to 6), and the press alone finishes the
	# full reload.
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)
	assert_eq(webley.reload_amount, 6, "the shipped webley stages the full cylinder")

	webley.reload()
	assert_almost_eq(webley._staged_cycle_time, 0.3, 0.0001, "the press caches the clamped clip-derived quantum")
	assert_true(state.is_reloading, "the press starts the staged reload")
	await wait_seconds(0.35)
	assert_eq(webley.current_ammo, 1, "the first cycle lands exactly one round (no jump to 6)")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 5, "exactly one round is debited per cycle")
	assert_true(state.is_reloading, "the staged reload continues without further presses")

	await wait_seconds(0.3)
	assert_eq(webley.current_ammo, 2, "the second cycle lands the next round on its own")

	assert_true(await wait_for_signal(webley.reload_stage_finished, 4.0), "the one press must finish the full cylinder")
	assert_eq(webley.current_ammo, 6, "the one press finishes the full cylinder")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 0, "all six rounds were consumed by the one press")
	assert_false(state.is_reloading, "the staged reload clears when the cylinder is full")

	# A full weapon refuses further reloads.
	webley.reload()
	assert_false(state.is_reloading, "a full weapon must not enter a reload stage")


func test_quantum_is_the_clip_length_split_across_the_staged_rounds() -> void:
	# Owner decision: per-round interval = weapon reload clip length / staged
	# round count for THIS press. Stub clip 2.4 s staged over 6 rounds gives a
	# constant 0.4 s cadence and a full press at about the clip length, NOT
	# six times it.
	var h := _make_harness(0, 6, 6, 2.4)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	assert_almost_eq(webley._staged_cycle_time, 0.4, 0.0001, "the quantum is the stub clip divided by the staged rounds")

	await wait_seconds(0.3)
	assert_eq(webley.current_ammo, 0, "nothing lands before the first full cycle")
	await wait_seconds(0.2)
	assert_eq(webley.current_ammo, 1, "the first round lands at one quantum")
	await wait_seconds(0.4)
	assert_eq(webley.current_ammo, 2, "the cadence stays constant at one quantum per round")
	await wait_seconds(0.4)
	assert_eq(webley.current_ammo, 3, "the cadence stays constant at one quantum per round")

	assert_true(await wait_for_signal(webley.reload_stage_finished, 4.0), "the press must finish near the clip length, not 6x it")
	assert_eq(webley.current_ammo, 6, "the whole cylinder landed from the one press")
	assert_false(state.is_reloading, "the stage cleared when the batch drained")


func test_quantum_clamps_to_the_sanity_window_and_falls_back_without_a_clip() -> void:
	# Two loading methods (owner ruling), sanity window update. FULL LOAD
	# ceiling: a 24 s clip staged over 6 rounds (supply covers the magazine)
	# would be 4 s per cycle; the clamp holds the full-load spread at 3.0 s.
	# PARTIAL rhythm: a partial supply chains at the authored per-insertion
	# beat (clip/capacity) with no ceiling above the floor. Floor: a 0.6 s
	# clip staged over 6 rounds would be 0.1 s per cycle; the clamp holds it
	# at 0.3 s. Fallback: no resolvable reload clip keeps reload_time as the
	# per-cycle quantum.
	var ceiling := _make_harness(0, 6, 6, 24.0)
	ceiling.webley.reload()
	assert_almost_eq(ceiling.webley._staged_cycle_time, 3.0, 0.0001, "the full-load spread is capped at the ceiling")
	await wait_seconds(0.5)
	assert_eq(ceiling.webley.current_ammo, 0, "the first round waits out the clamped cycle")
	ceiling.webley.request_reload_abort()

	var partial_rhythm := _make_harness(0, 6, 2, 24.0)
	partial_rhythm.webley.reload()
	assert_almost_eq(partial_rhythm.webley._staged_cycle_time, 4.0, 0.0001, "a partial chain runs the authored insertion rhythm, floor only")
	partial_rhythm.webley.request_reload_abort()

	var floor_case := _make_harness(0, 6, 6, 0.6)
	floor_case.webley.reload()
	assert_almost_eq(floor_case.webley._staged_cycle_time, 0.3, 0.0001, "the derived quantum is floored")
	floor_case.webley.request_reload_abort()

	var fallback := _make_harness(0, 6, 6, 0.0)
	fallback.webley.reload()
	assert_almost_eq(fallback.webley._staged_cycle_time, 0.25, 0.0001, "without a reload clip the press falls back to reload_time")
	await wait_seconds(0.35)
	assert_eq(fallback.webley.current_ammo, 1, "the fallback cadence drives the staged chain too")
	fallback.webley.request_reload_abort()


func test_real_webley_clip_sets_the_full_cylinder_cadence() -> void:
	# The shipped scene: clip 8.067 s / 6 rounds = about 1.34 s per round, so
	# a six-round press completes in roughly the composite duration. Pins the
	# derived values against the real scene, no stub clip.
	var h := _make_harness(0, 6, 6, -1.0)
	var webley : Node = h.webley
	var anim_player : AnimationPlayer = webley.animation_player
	var expected_cycle : float = anim_player.get_animation("reload").length / 6.0
	assert_almost_eq(expected_cycle, 1.3444, 0.001, "sanity: the real webley clip divided by six")

	webley.reload()
	assert_almost_eq(webley._staged_cycle_time, expected_cycle, 0.001, "the quantum derives from the real scene clip")

	await wait_seconds(1.2)
	assert_eq(webley.current_ammo, 0, "nothing lands inside the first 1.34 s cycle")
	await wait_seconds(0.4)
	assert_eq(webley.current_ammo, 1, "the first round lands at about clip / 6")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 5, "the landed round was debited")

	# Clean up mid-chain: the landed round stands, the rest is cancelled.
	webley.request_reload_abort()
	assert_eq(webley.current_ammo, 1, "the landed round stands after the abort")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 5, "the unlanded rounds stay in the inventory")


func test_abort_mid_chain_keeps_landed_rounds_and_cancels_the_rest() -> void:
	# Aborting after rounds already landed: the landed rounds stand (they were
	# debited as they landed), the rest of the staged batch is cancelled, and
	# no double-debit happens.
	var h := _make_harness(0, 6, 6, 2.4)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	await wait_seconds(1.0)
	assert_eq(webley.current_ammo, 2, "two rounds landed before the abort")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 4, "the landed rounds were debited once")

	webley.request_reload_abort()
	assert_true(await wait_for_signal(webley.reload_aborted, 3.0), "the mid-chain abort completes after the close beat")
	assert_false(state.is_reloading, "the abort clears the reload state after the close beat")
	assert_null(state.reloading_item, "the abort clears the reloading item after the close beat")
	assert_eq(webley.current_ammo, 2, "the landed rounds stand")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 4, "nothing was debited twice")
	assert_signal_not_emitted(webley, "reload_stage_finished")

	await wait_seconds(1.0)
	assert_eq(webley.current_ammo, 2, "the cancelled rounds never land later")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 4, "the cancelled rounds stay in the inventory")


func test_per_chamber_sound_plays_once_per_landed_round() -> void:
	# The webley wires six per-chamber streams; each landed round plays the
	# next one on the Sounds/Chamber player. The composite Reload sound is
	# owned by the press, not the chain.
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var chamber : AudioStreamPlayer3D = webley.get_node("Sounds/Chamber")
	assert_true(chamber != null, "the shipped webley carries a Sounds/Chamber player")

	webley.reload()
	assert_true(await wait_until(func() -> bool: return webley.current_ammo == 1, 2.0), "the first round landed")
	assert_eq(chamber.stream, Revolver1, "round one plays the first chamber click")
	assert_true(chamber.playing, "the chamber player is playing the round one click")

	assert_true(await wait_until(func() -> bool: return webley.current_ammo == 2, 2.0), "the second round landed")
	assert_eq(chamber.stream, Revolver2, "round two plays the second chamber click")

	assert_true(await wait_for_signal(webley.reload_stage_finished, 4.0), "the staged chain finished")
	assert_eq(chamber.stream, Revolver6, "the last landed round played the sixth chamber click")
	assert_true(chamber.playing, "the chamber player is playing the final click")


func test_no_interrupt_reload_baseline_unchanged() -> void:
	# Stage 2 with the 0.6 s stub clip: quantum 0.3 s per round, the stage
	# completes at 0.6 s. Same semantics as before the quantum change, only
	# the cadence source moved from reload_time to the derived quantum.
	var h := _make_harness(0, 6)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	assert_true(await wait_for_signal(webley.reload_stage_finished, 4.0), "the stage must finish")
	assert_eq(webley.current_ammo, 2, "an uninterrupted stage loads reload_amount rounds")
	assert_false(state.is_reloading, "an uninterrupted stage clears is_reloading")
	assert_null(state.reloading_item, "an uninterrupted stage clears reloading_item")
	assert_eq(h.inventory.tiny_items[AmmoResource], 4, "tiny ammo must be consumed by the loaded amount")
	assert_signal_emitted_with_parameters(webley, "reload_stage_finished", [2])


func test_unload_keeps_the_inventory_lock_semantics() -> void:
	var h := _make_harness(6, 0)
	var webley : Node = h.webley
	var state : Node = h.state

	webley.unload()
	assert_true(state.is_reloading, "unload() must hold the character reload flag")
	assert_null(state.reloading_item, "unload() must NOT register a reloading_item: switching stays locked")

	# An abort must not touch an unload: the ReloadTimer is stopped during an
	# unload, and reloading_item being null keeps the switch hard-locked.
	webley.request_reload_abort()
	assert_true(state.is_reloading, "the abort must not clear an unload in flight")
	assert_eq(webley.current_ammo, 6, "the abort must not disturb the unload")

	# The unload boundary is the UnloadTimer timeout; it does not emit the
	# reload stage signal, so wait out the 0.25 s unload time instead.
	await wait_seconds(0.6)
	assert_eq(webley.current_ammo, 0, "the unload must empty the weapon at its boundary")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the unload must return the rounds to the inventory")
	assert_false(state.is_reloading, "the unload boundary must clear is_reloading")
