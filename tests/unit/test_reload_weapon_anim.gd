extends GutTest
## Weapon-side reload animations (Phase 1 of the reload animation port).
## Every gun's own AnimationPlayer must resolve a REAL reload composite (no
## empty stubs: Lee-Metford and Martini-Henry rifle wire their per-gun
## -weapon.res data), the press starts it, no reload clip carries method
## tracks (shell ejection is code-driven at the press; a method track would
## double-eject), and an interrupt plays the close beat BEFORE the reload
## state clears (owner rule, research doc 6.1: the cylinder closes FIRST,
## then the swap/holster runs).
##
## Harness: the same stub-owner pattern as test_reload_stage_abort. The
## private library copy is only used where a stub cadence is needed; the
## real-clip tests run against the scene libraries as wired.

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const WebleyScene = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
const KhyberScene = preload("res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn")
const DoubleBarrelScene = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn")
const SawedOffScene = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn")
const LeeScene = preload("res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn")
const MartiniScene = preload("res://scenes/objects/pickable_items/equipment/ranged/martini_henry_rifle/martini_henry_rifle.tscn")
const AmmoResource = preload("res://resources/tiny_items/ammunition/455_webley.tres")
const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")

## item_name -> expected reload composite length (the 3.x weapon clip table)
const EXPECTED_LENGTHS := {
	"Webley revolver": 8.0667,
	"Sawed-off Martini pistol": 2.35,
	"Double-barrel shotgun": 4.5833,
	"Sawed-off shotgun": 4.5833,
	"Lee-Metford rifle": 11.4,
	"Martini-Henry rifle": 3.15,
}


class ReloadOwnerStub extends Node:
	var state = null
	var inventory = null


func _make_webley_harness(start_ammo : int, start_tiny : int, ready_loaded : bool = false) -> Dictionary:
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
	webley.ammunition_capacity = 6
	webley.reload_amount = 6
	webley.current_ammo_type = AmmoResource
	webley.current_ammo = start_ammo
	inv.tiny_items[AmmoResource] = start_tiny
	if ready_loaded:
		# Set up before add_child so _ready runs the convenience load.
		webley.owner_character = owner_stub
		add_child_autofree(webley)
	else:
		add_child_autofree(webley)
		webley.owner_character = owner_stub
	# Freeze AFTER add_child: _ready re-arms the dropped physics state
	# (set_physics_dropped resets freeze), and the harness gun floats in
	# space where pickable_item's world-integrity guard deletes anything
	# that free-falls below y -50, so the long-wait tests (the 8 s webley
	# composite) would lose their gun mid-await.
	webley.freeze = true
	return {"owner": owner_stub, "state": state, "inventory": inv, "webley": webley}


## The Lee-Metford rifle skeleton still stores the Godot 4.6-era pose
## format; Godot 4.7 emits a load-time deprecation error for it (a
## pre-existing asset artifact, flagged to the owner for an editor re-save,
## not a signal about this suite). Mark the tracked error handled so GUT
## does not fail the test on it.
func _tolerate_lee_skeleton_pose_artifact() -> void:
	for e in gut.error_tracker.get_current_test_errors():
		if e.rationale.contains("old pose format"):
			e.handled = true


func _weapon_player(gun : Node) -> AnimationPlayer:
	var players := gun.find_children("*", "AnimationPlayer", true, false)
	assert_gt(players.size(), 0)
	return players[0] as AnimationPlayer


func test_every_gun_resolves_a_real_reload_composite() -> void:
	var scenes := {
		"Webley revolver": WebleyScene,
		"Sawed-off Martini pistol": KhyberScene,
		"Double-barrel shotgun": DoubleBarrelScene,
		"Sawed-off shotgun": SawedOffScene,
		"Lee-Metford rifle": LeeScene,
		"Martini-Henry rifle": MartiniScene,
	}
	for item_name: String in scenes:
		var gun : Node = (scenes[item_name] as PackedScene).instantiate()
		autofree(gun)
		_tolerate_lee_skeleton_pose_artifact()
		var player := _weapon_player(gun)
		assert_true(player.has_animation("reload"), "%s must resolve its reload clip" % item_name)
		var anim := player.get_animation("reload") as Animation
		assert_almost_eq(anim.length, EXPECTED_LENGTHS[item_name], 0.01)
		assert_gt(anim.get_track_count(), 0)
		# No method tracks anywhere: shell ejection is code-driven at the
		# press, so a re-added expell_shells method track would double-eject.
		for t in anim.get_track_count():
			assert_ne(anim.track_get_type(t), Animation.TYPE_METHOD)


func test_lee_and_martini_stubs_are_replaced_by_real_data() -> void:
	var lee : Node = LeeScene.instantiate()
	autofree(lee)
	_tolerate_lee_skeleton_pose_artifact()
	var lee_player := _weapon_player(lee)
	var lee_anim := lee_player.get_animation("reload") as Animation
	assert_eq(lee_anim.get_track_count(), 5)
	var has_root_track := false
	for t in lee_anim.get_track_count():
		if String(lee_anim.track_get_path(t)).begins_with("SK_LeeMetford"):
			has_root_track = true
	assert_true(has_root_track, "the Lee composite must carry its gun-root motion track")

	var martini : Node = MartiniScene.instantiate()
	autofree(martini)
	var martini_player := _weapon_player(martini)
	var martini_anim := martini_player.get_animation("reload") as Animation
	assert_eq(martini_anim.get_track_count(), 6)


func test_close_beat_wiring_per_gun() -> void:
	var webley : Node = WebleyScene.instantiate()
	autofree(webley)
	assert_eq(webley.reload_close_clip, &"close_cyl_weapon", "webley uses the dedicated close clip")
	assert_eq(webley.reload_close_start, 0.0)
	var webley_player := _weapon_player(webley)
	assert_almost_eq(webley_player.get_animation("close_cyl_weapon").length, 1.0833, 0.01)

	var lee : Node = LeeScene.instantiate()
	autofree(lee)
	assert_eq(lee.reload_close_clip, &"close_bolt_weapon", "lee uses the dedicated close clip")

	var martini : Node = MartiniScene.instantiate()
	autofree(martini)
	assert_eq(martini.reload_close_clip, &"lever_close_weapon", "martini rifle uses the dedicated close clip")

	# Tail-mode guns: the close segment is the composite's final stretch.
	var khyber : Node = KhyberScene.instantiate()
	autofree(khyber)
	assert_eq(khyber.reload_close_clip, &"", "khyber has no dedicated close clip")
	assert_almost_eq(khyber.reload_close_start, 1.6667, 0.001)

	var db : Node = DoubleBarrelScene.instantiate()
	autofree(db)
	assert_almost_eq(db.reload_close_start, 3.3, 0.001)

	var sawed : Node = SawedOffScene.instantiate()
	autofree(sawed)
	assert_almost_eq(sawed.reload_close_start, 3.3, 0.001)


func test_press_starts_the_weapon_composite() -> void:
	var h := _make_webley_harness(2, 10)
	var webley : Node = h.webley
	var player := _weapon_player(webley)

	webley.reload()
	assert_true(player.is_playing(), "the press must start the weapon composite")
	assert_eq(player.current_animation, "reload")
	var start_position : float = player.current_animation_position
	await wait_seconds(0.2)
	assert_gt(player.current_animation_position, start_position)

	webley.request_reload_abort()
	await wait_for_signal(webley.reload_aborted, 3.0)


func test_abort_plays_the_close_beat_before_the_state_clears() -> void:
	var h := _make_webley_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state
	var player := _weapon_player(webley)
	watch_signals(webley)

	webley.reload()
	await wait_seconds(0.4)
	assert_true(state.is_reloading, "precondition: the reload is in flight")

	webley.request_reload_abort()
	# Owner rule (research doc 6.1): the close beat runs FIRST; the reload
	# state stays set through it so the inventory lock, the shooting gate and
	# the parked slot switch all wait for the close.
	assert_true(state.is_reloading, "the abort must not clear the state while the close beat plays")
	assert_eq(player.current_animation, "close_cyl_weapon", "the abort must play the close beat clip")
	assert_true(player.is_playing(), "the close beat must be playing")

	assert_true(await wait_for_signal(webley.reload_aborted, 3.0), "the abort completes after the close beat")
	assert_false(state.is_reloading, "the state clears only after the close beat")
	assert_null(state.reloading_item, "the reloading item clears only after the close beat")
	assert_eq(webley.current_ammo, 2, "the abort must not land the queued rounds")
	assert_eq(h.inventory.tiny_items[AmmoResource], 10, "the queued rounds stay in the inventory")


func test_convenience_load_abort_clears_at_once_without_a_close_beat() -> void:
	# The ready-time load (reload(false)) never starts the composite: its
	# abort has no action to close and must not delay the swap.
	var h := _make_webley_harness(2, 10, true)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	assert_true(state.is_reloading, "precondition: the ready-time load staged the weapon")
	var player := _weapon_player(webley)
	assert_false(player.is_playing(), "the convenience load must not animate")

	webley.request_reload_abort()
	assert_false(state.is_reloading, "an abort without a composite clears the state at once")
	assert_signal_emitted(webley, "reload_aborted")


func test_left_hand_cadence_unclamps_only_left_hand_guns() -> void:
	# Phase 4 owner ruling: the 3.0 s ceiling clamp was a stopgap from the
	# animation-less era. Left-hand guns (Lee-Metford, Martini-Henry rifle)
	# run the authored composite at full length per staged round; the 0.3 s
	# floor still guards a mis-authored clip. Every other gun keeps the
	# ceiling.
	var lee : Node = LeeScene.instantiate()
	add_child_autofree(lee)
	_tolerate_lee_skeleton_pose_artifact()
	assert_almost_eq(lee._staged_reload_cycle_time(1), 11.4, 0.01, "Lee runs its full composite")
	var martini : Node = MartiniScene.instantiate()
	add_child_autofree(martini)
	assert_almost_eq(martini._staged_reload_cycle_time(1), 3.15, 0.01, "Martini rifle runs its full composite")
	# The same gun with the flag off stays ceiling-clamped.
	lee.reload_needs_left_hand = false
	assert_almost_eq(lee._staged_reload_cycle_time(1), 3.0, 0.01, "non-left-hand guns keep the ceiling clamp")


func test_left_hand_press_runs_the_full_authored_composite() -> void:
	# The Lee-Metford press is UNCLAMPED since Phase 4: the single round
	# lands at the END of the authored 11.4 s composite, so there is no
	# separate close beat on natural completion (3.x parity: one press was
	# clip-0.3 = 11.1 s of authored reload). The bolt close lives inside the
	# composite's final stretch.
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

	var lee = LeeScene.instantiate()
	add_child_autofree(lee)
	# Freeze after add_child (see the harness freeze note): the press waits
	# 11.4 s, far past the free-fall delete window.
	lee.freeze = true
	lee.owner_character = owner_stub
	var ammo_type = load("res://resources/tiny_items/ammunition/303_british.tres")
	lee.current_ammo_type = ammo_type
	lee.current_ammo = 0
	inv.tiny_items[ammo_type] = 5
	watch_signals(lee)
	var player := _weapon_player(lee)

	lee.reload()
	await wait_seconds(5.0)
	assert_true(state.is_reloading, "the press holds the state through the unclamped composite")
	assert_eq(lee.current_ammo, 0, "no round lands before the composite ends")
	assert_eq(player.current_animation, "reload", "the composite runs uncut")
	assert_true(await wait_for_signal(lee.reload_stage_finished, 9.0), "the press finishes at the composite end")
	assert_eq(lee.current_ammo, 1, "the round landed at the unclamped quantum")
	assert_false(state.is_reloading, "the state clears right after the composite tail")


func test_left_hand_abort_still_plays_the_bolt_close_beat() -> void:
	# The unclamp changes only the NATURAL completion: an interrupt still
	# cuts to the dedicated close clip and holds the state through it.
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

	var lee = LeeScene.instantiate()
	add_child_autofree(lee)
	lee.freeze = true
	lee.owner_character = owner_stub
	var ammo_type = load("res://resources/tiny_items/ammunition/303_british.tres")
	lee.current_ammo_type = ammo_type
	lee.current_ammo = 0
	inv.tiny_items[ammo_type] = 5
	watch_signals(lee)
	var player := _weapon_player(lee)

	lee.reload()
	await wait_seconds(1.0)
	lee.request_reload_abort()
	assert_eq(player.current_animation, "close_bolt_weapon", "the abort cuts to the bolt close beat")
	assert_true(await wait_for_signal(lee.reload_aborted, 4.0), "the abort completes after the close beat")
	assert_false(state.is_reloading, "the state clears only after the close beat")


func test_unclamped_quantum_spreads_rounds_across_the_composite() -> void:
	# Sync note (approximate by owner decision): the unclamped quantum is
	# exactly clip length / staged rounds, so the press spans the composite;
	# the authored insertion beats do not align frame-perfectly with the
	# landings and must not be forced to.
	var h := _make_webley_harness(0, 6)
	var webley : Node = h.webley
	var cycle : float = webley._staged_reload_cycle_time(6)
	assert_almost_eq(cycle * 6.0, 8.0667, 0.01)
	webley.reload()
	var player := _weapon_player(webley)
	assert_true(player.is_playing(), "the full-cylinder press plays the composite")
	await wait_for_signal(webley.reload_stage_finished, 12.0)
	assert_eq(webley.current_ammo, 6, "the full cylinder loaded")
