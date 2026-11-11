extends GutTest
## Shell insertion visuals on reload (Phase 3, code-driven): each staged
## ReloadTimer cycle that lands a round triggers the insertion visual
## through the gun's per-gun shell effect node. The 3.x method-track beat
## (player_add_shell into the left hand's ShellSpawnPosition,
## add_shells_to_slot into the chamber markers, clear_all_slots at the end)
## now rides the landed-round code beat, which is approximate to the
## authored mid-clip moments by design (the staged quantum spreads the
## rounds across the composite). Only a press that opened the action
## inserts visuals; the ready-time convenience load stays silent. The
## visuals clear when the reload fully ends, natural completion and abort
## alike, so a mid-chain abort clears the pending and inserted visuals with
## the close beat.
## 3.x truth (origin/main method tracks and shell scripts): the webley
## fills 6 cylinder slots, both shotguns 2 breech slots, the khyber shows
## the hand shell only (no slot fill); Lee-Metford and Martini-Henry rifle
## never had shell effects.
##
## Harness: the test_shell_ejection pattern, extended with a real
## GunReloadShells holder (script + ShellSpawnPosition marker) on the owner
## stub, and recording doubles swapped onto gun_item._shell_effects.

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const HolderScript = preload("res://scenes/characters/player/player_gun_reload_shells.gd")
const WebleyScene = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
const DoubleBarrelScene = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn")
const SawedScene = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn")
const KhyberScene = preload("res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn")
const LeeScene = preload("res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn")
const WebleyRoundScene = preload("res://scenes/objects/pickable_items/tiny/ammo/webley/webley_round.tscn")
const AmmoResource = preload("res://resources/tiny_items/ammunition/455_webley.tres")
const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")

const WEBLEY_MARKERS_PARENT := "Webley/Webley_Arm/Skeleton3D/Webley2"
const MARKER_NAMES : Array[String] = ["BulletPosition", "BulletPosition2", "BulletPosition3", "BulletPosition4", "BulletPosition5", "BulletPosition6"]


class ReloadOwnerStub extends Node:
	var state = null
	var inventory = null


class InsertionEffectsDouble extends Node:
	var insert_calls : int = 0
	var clear_calls : int = 0

	func insert_landed_round() -> void:
		insert_calls += 1

	func clear_insertion_visuals() -> void:
		clear_calls += 1


func _make_harness(gun_scene : PackedScene, start_ammo : int, start_tiny : int, stage_amount : int, stub_clip_length : float = 0.6, capacity : int = 6) -> Dictionary:
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

	var gun = gun_scene.instantiate()
	gun.ammunition_capacity = capacity
	gun.reload_amount = stage_amount
	if stub_clip_length > 0.0:
		gun.reload_time = 0.25
	add_child_autofree(gun)
	gun.owner_character = owner_stub
	# The scene's own ammo type drives the staged chain: the tiny item key
	# and the chambered type must both be it.
	var ammo : Resource = gun.ammo_types[0]
	gun.current_ammo_type = ammo
	gun.current_ammo = start_ammo
	inv.tiny_items[ammo] = start_tiny
	if stub_clip_length > 0.0:
		_own_reload_library(gun, stub_clip_length)
	gun.freeze = true
	return {"owner": owner_stub, "state": state, "inventory": inv, "gun": gun, "ammo": ammo}


func _own_reload_library(gun : Node, stub_clip_length : float) -> void:
	# The scene's sub_resource AnimationLibrary is shared across instantiate()
	# calls, so the stub goes into a private per-instance copy.
	var anim_player : AnimationPlayer = gun.animation_player
	var shared : AnimationLibrary = anim_player.get_animation_library("")
	var private_lib := AnimationLibrary.new()
	for anim_name in shared.get_animation_list():
		if anim_name != "reload":
			private_lib.add_animation(anim_name, shared.get_animation(anim_name))
	var stub_anim := Animation.new()
	stub_anim.length = stub_clip_length
	private_lib.add_animation("reload", stub_anim)
	anim_player.remove_animation_library("")
	anim_player.add_animation_library("", private_lib)


## Attaches a real holder to the owner stub: the GunReloadShells node with
## the ported script and its ShellSpawnPosition marker, the way the base
## scene wires them.
func _attach_holder(owner_stub : Node) -> Node:
	var holder : Node = Node.new()
	holder.name = "GunReloadShells"
	holder.set_script(HolderScript)
	owner_stub.add_child(holder)
	var marker : Marker3D = Marker3D.new()
	marker.name = "ShellSpawnPosition"
	marker.unique_name_in_owner = true
	holder.add_child(marker)
	marker.owner = holder
	return holder


func _marker(gun : Node, index : int) -> Node:
	return gun.get_node(WEBLEY_MARKERS_PARENT + "/" + MARKER_NAMES[index])


func _slot_visual_count(gun : Node) -> int:
	var count := 0
	for index in 6:
		count += _marker(gun, index).get_child_count()
	return count


func test_webley_cadence_one_insert_per_landed_round() -> void:
	var h := _make_harness(WebleyScene, 0, 6, 6, 1.8)
	var gun : Node = h.gun
	var effects := InsertionEffectsDouble.new()
	autofree(effects)
	gun._shell_effects = effects

	gun.reload()
	assert_true(await wait_for_signal(gun.reload_stage_finished, 3.0), "the staged press completes")
	assert_eq(effects.insert_calls, 6, "the webley fires one insertion visual per landed round")
	assert_eq(effects.clear_calls, 1, "the completion clears the insertion visuals once")


func test_webley_slots_fill_one_per_landed_round_without_double_insert() -> void:
	var h := _make_harness(WebleyScene, 0, 6, 6, 1.8)
	var gun : Node = h.gun
	var effects : Node = gun._shell_effects
	assert_true(effects != null, "the webley scene wires its shell effect node")

	gun.reload()
	await wait_seconds(0.45)
	assert_eq(gun.current_ammo, 1, "round one landed")
	assert_eq(_slot_visual_count(gun), 1, "the first landed round filled exactly one cylinder slot")
	for index in 6:
		assert_eq(_marker(gun, index).get_child_count(), 1 if index == 0 else 0, "each landed round fills the next empty slot only")

	# The completion clear is pinned by test_natural_completion; here the
	# abort must also wipe the inserted visuals, and a re-press fills from
	# slot one again instead of stacking on the old visuals.
	gun.request_reload_abort()
	assert_true(await wait_for_signal(gun.reload_aborted, 3.0), "the abort completes after the close beat")
	assert_eq(_slot_visual_count(gun), 0, "the abort close beat cleared the inserted visuals")

	gun.reload()
	await wait_seconds(0.45)
	assert_eq(_slot_visual_count(gun), 1, "the re-press fills from slot one again, no double insert")
	gun.request_reload_abort()
	assert_true(await wait_for_signal(gun.reload_aborted, 3.0), "the second abort completes")


func test_webley_insertion_reaches_the_hand_holder_and_slots() -> void:
	var h := _make_harness(WebleyScene, 0, 6, 6, 1.8)
	var gun : Node = h.gun
	var holder := _attach_holder(h.owner)

	gun.reload()
	await wait_seconds(0.45)
	assert_eq(gun.current_ammo, 1, "round one landed")
	assert_true(holder.call("has_hand_shell") or holder.get_node("%ShellSpawnPosition").get_child_count() == 1, "the hand shell visual is showing")
	assert_eq(_slot_visual_count(gun), 1, "the first cylinder slot filled")
	var shell : Node3D = holder.get_node("%ShellSpawnPosition").get_child(0)
	var body := shell as RigidBody3D
	assert_true(body != null, "the hand shell spawns from the loose round scene")
	if body != null:
		assert_true(body.freeze, "the hand shell is pinned frozen, it must not fall off the hand")
		assert_eq(body.collision_layer, 0, "the inserted visual is not interactable")
	gun.request_reload_abort()
	assert_true(await wait_for_signal(gun.reload_aborted, 3.0), "the abort completes")


func test_webley_abort_clears_pending_and_inserted_visuals() -> void:
	var h := _make_harness(WebleyScene, 0, 6, 6, 1.8)
	var gun : Node = h.gun
	var holder := _attach_holder(h.owner)

	gun.reload()
	await wait_seconds(0.45)
	assert_eq(gun.current_ammo, 1, "round one landed before the abort")
	assert_eq(_slot_visual_count(gun), 1, "round one's slot visual stands")
	gun.request_reload_abort()
	assert_true(await wait_for_signal(gun.reload_aborted, 3.0), "the abort completes after the close beat")
	assert_eq(_slot_visual_count(gun), 0, "the abort cleared the inserted slot visual")
	var marker : Marker3D = holder.get_node("%ShellSpawnPosition")
	# queue_free is deferred: give the frame a beat before counting.
	await wait_seconds(0.1)
	assert_eq(marker.get_child_count(), 0, "the hand shell cleared with the close beat")


func test_natural_completion_clears_all_slots_and_the_hand() -> void:
	var h := _make_harness(WebleyScene, 0, 6, 6, 1.8)
	var gun : Node = h.gun
	var holder := _attach_holder(h.owner)

	gun.reload()
	assert_true(await wait_for_signal(gun.reload_stage_finished, 3.0), "the staged press completes")
	assert_eq(_slot_visual_count(gun), 0, "the completion emptied every slot visual")
	var marker : Marker3D = holder.get_node("%ShellSpawnPosition")
	await wait_seconds(0.1)
	assert_eq(marker.get_child_count(), 0, "the hand shell cleared at the end")


func test_shotgun_cadence_two_insertions_two_slots() -> void:
	for gun_scene in [DoubleBarrelScene, SawedScene]:
		var h := _make_harness(gun_scene, 0, 2, 2, 0.6, 2)
		var gun : Node = h.gun
		var effects := InsertionEffectsDouble.new()
		autofree(effects)
		gun._shell_effects = effects
		gun.reload()
		assert_true(await wait_for_signal(gun.reload_stage_finished, 3.0), "the shotgun press completes")
		assert_eq(effects.insert_calls, 2, "the shotgun fires one insertion per landed shell")
		assert_eq(effects.clear_calls, 1, "the completion clears once")


func test_khyber_hand_only_insertion_no_slot_fill() -> void:
	var h := _make_harness(KhyberScene, 0, 1, 1, 0.6, 1)
	var gun : Node = h.gun
	var holder := _attach_holder(h.owner)
	var effects : Node = gun._shell_effects
	assert_true(effects != null, "the khyber scene wires its shell effect node")
	assert_false(effects.has_method("add_shells_to_slot"), "the khyber 3.x track never filled a slot")

	gun.reload()
	assert_true(await wait_for_signal(gun.reload_stage_finished, 3.0), "the single-round press completes")
	var marker : Marker3D = holder.get_node("%ShellSpawnPosition")
	await wait_seconds(0.1)
	assert_eq(marker.get_child_count(), 0, "the completion cleared the hand shell")
	assert_eq(gun.current_ammo, 1, "the round landed")


func test_convenience_load_does_not_insert_visuals() -> void:
	# The ready-time convenience load (reload(false)) is not a press: the
	# chambers never opened, no visuals.
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
	var gun = WebleyScene.instantiate()
	gun.ammunition_capacity = 6
	gun.reload_amount = 6
	gun.owner_character = owner_stub
	gun.current_ammo_type = AmmoResource
	gun.current_ammo = 0
	inv.tiny_items[AmmoResource] = 6
	add_child_autofree(gun)
	gun.freeze = true
	var effects := InsertionEffectsDouble.new()
	autofree(effects)
	gun._shell_effects = effects

	await wait_seconds(1.6)
	assert_eq(gun.current_ammo, 1, "the convenience load landed a round")
	assert_eq(effects.insert_calls, 0, "the convenience load inserted no visuals for the landed round")
	# The convenience load has no composite, so the abort finalizes at once
	# and emits reload_aborted synchronously: check the state, no await.
	gun.request_reload_abort()
	assert_false(state.is_reloading, "the convenience load abort clears the reload state at once")


func test_guns_without_shell_wiring_reload_silently() -> void:
	# Lee-Metford (the 3.x state: no shell effects node, no method track) must
	# land its single round with no insertion call and no crash.
	var h := _make_harness(LeeScene, 0, 6, 1, -1.0, 10)
	var gun : Node = h.gun
	assert_eq(gun._shell_effects, null, "the Lee-Metford carries no shell effect node")
	gun.reload()
	assert_true(await wait_for_signal(gun.reload_stage_finished, 5.0), "the Lee's clamped single-round press completes")
	assert_eq(gun.current_ammo, 1, "the round landed without insertion visuals")
	_tolerate_lee_skeleton_pose_artifact()


## The Lee-Metford rifle skeleton still stores the Godot 4.6-era pose
## format; Godot 4.7 emits a load-time deprecation error for it (a
## pre-existing asset artifact, flagged to the owner for an editor re-save,
## not a signal about this suite). Same tolerance as the weapon-anim suite.
func _tolerate_lee_skeleton_pose_artifact() -> void:
	for e in gut.error_tracker.get_current_test_errors():
		if e.rationale.contains("old pose format") or e.rationale.contains("has been deprecated"):
			e.handled = true
