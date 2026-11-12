extends GutTest
## Double-barrel sawed-off staged reload sequence (owner playtest 2026-11-09):
## pins the doubles ruling (docs/design/realistic-reload-design.md 4.2) on the
## REAL weapon composite: exactly one open beat before the insertions, both
## shells inside the insertion window, exactly one close after the second
## shell, no close replay when the composite already ran its own close.
## Also pins the 3.x left-hand truth (the sawed-off reload never mounts the
## gun on the offhand; the hand motion is the character clip) and the 3.x
## muzzle smoke resource values on both break-open guns.

const SAWED_SCENE := preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn")
const DOUBLE_BARREL_SCENE := preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn")
const LEE_SCENE := preload("res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn")
const KHYBER_SCENE := preload("res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn")
const SAWED_SMOKE_PATH := "res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/_smoke.tscn"
const DB_SMOKE_PATH := "res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/_smoke.tscn"
const HUMANOID_BASE_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"
const InventoryScript = preload("res://scenes/characters/inventory.gd")
const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")
const HAND_BONE := "DEF-forearm.R"
const SKELETON_PATH := "ModelRoot/rig_deform/Skeleton3D"


class ReloadOwnerStub extends Node:
	var state = null
	var inventory = null


func _make_harness(gun_scene : PackedScene, start_ammo : int, start_tiny : int) -> Dictionary:
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
	add_child_autofree(gun)
	gun.owner_character = owner_stub
	var ammo : Resource = gun.ammo_types[0]
	gun.current_ammo_type = ammo
	gun.current_ammo = start_ammo
	inv.tiny_items[ammo] = start_tiny
	gun.freeze = true
	return {"owner": owner_stub, "state": state, "inventory": inv, "gun": gun, "ammo": ammo}


func test_full_load_beats_open_both_shells_one_close() -> void:
	var h := _make_harness(SAWED_SCENE, 0, 2)
	var gun : Node = h.gun
	var anim_player : AnimationPlayer = gun.animation_player
	var close_start : float = gun.reload_close_start
	var landed_positions : Array[float] = []
	var close_crossings := 0
	var close_beat_starts := 0
	var last_pos := -1.0
	var last_landed := 0
	var was_pending := false
	gun.reload()
	while h.state.is_reloading:
		await get_tree().process_frame
		var playing_reload : bool = anim_player.current_animation == "reload" and anim_player.is_playing()
		var pos : float = anim_player.current_animation_position if playing_reload else last_pos
		if playing_reload and last_pos >= 0.0 and last_pos < close_start and pos >= close_start:
			close_crossings += 1
		if gun._staged_rounds_landed != last_landed:
			last_landed = gun._staged_rounds_landed
			landed_positions.append(anim_player.current_animation_position)
		if gun._close_beat_pending and not was_pending:
			close_beat_starts += 1
		was_pending = gun._close_beat_pending
		last_pos = pos
	assert_eq(gun.current_ammo, 2, "the full load lands both shells")
	assert_eq(landed_positions.size(), 2, "two staged insertions")
	for pos in landed_positions:
		assert_lt(pos, close_start + 0.05, "every shell lands inside the insertion window, before the authored close")
	assert_gt(close_start, 0.0, "precondition: the sawed-off is a tail-mode composite")
	assert_eq(close_crossings, 1, "the authored close segment plays exactly once")
	assert_eq(close_beat_starts, 1, "one close beat, after the second shell")
	assert_false(gun._close_beat_pending, "the close beat ended with the reload")


func test_tail_mode_cycle_math_spreads_the_window() -> void:
	var sawed := _mount(SAWED_SCENE)
	var clip_length : float = sawed.animation_player.get_animation("reload").length
	assert_gt(sawed.reload_close_start, 0.0, "precondition: tail-mode close")
	assert_lt(sawed.reload_close_start, clip_length, "precondition: the close sits inside the clip")
	assert_almost_eq(sawed._staged_reload_cycle_time(2, true), sawed.reload_close_start / 2.0, 0.0001, \
			"the two shells spread across the insertion window")
	assert_almost_eq(sawed._staged_reload_cycle_time(1, true), 3.0, 0.0001, \
			"the single-shell full load keeps the non-left-hand ceiling")
	assert_almost_eq(sawed._staged_reload_cycle_time(2, false), clip_length / 2.0, 0.0001, \
			"the partial-chain rhythm is the authored per-insertion spacing, unchanged")
	var khyber := _mount(KHYBER_SCENE)
	assert_almost_eq(khyber._staged_reload_cycle_time(1, true), khyber.reload_close_start, 0.0001, \
			"the khyber single round lands at its authored close start")


## A bare instantiation has no @onready animation_player: mount the gun under
## the test tree first, the way every runtime press would.
func _mount(scene : PackedScene) -> Node:
	var gun : Node = scene.instantiate()
	add_child_autofree(gun)
	return gun


func test_composite_finished_means_no_close_replay() -> void:
	var h := _make_harness(SAWED_SCENE, 0, 2)
	var gun : Node = h.gun
	var anim_player : AnimationPlayer = gun.animation_player
	var reload_length : float = anim_player.get_animation("reload").length
	gun._reload_composite_started = true
	anim_player.play("reload")
	anim_player.seek(2.0, true)
	var mid_clip : float = gun._close_beat_time(anim_player)
	assert_almost_eq(mid_clip, reload_length - gun.reload_close_start, 0.05, \
			"mid-clip a natural completion still cuts to the close segment")
	anim_player.seek(reload_length - 0.02, true)
	await wait_seconds(0.3)
	assert_false(anim_player.is_playing(), "the composite ran to its end")
	assert_almost_eq(gun._close_beat_time(anim_player), 0.0, 0.0001, \
			"a finished composite has already played its close: no replay, no second close")


func test_left_hand_guns_keep_the_unclamped_full_load() -> void:
	var lee := _mount(LEE_SCENE)
	# The Lee skeleton still stores the Godot 4.6-era pose format; Godot 4.7
	# emits a load-time deprecation error for it (a pre-existing asset
	# artifact, tolerated the same way test_reload_character_anim does).
	for e in gut.error_tracker.get_current_test_errors():
		if String(e.code).contains("deprecat") or String(e.rationale).contains("deprecat"):
			e.handled = true
	var clip_length : float = lee.animation_player.get_animation("reload").length
	assert_true(lee.reload_needs_left_hand, "precondition: the Lee is a left-hand gun")
	assert_almost_eq(lee._staged_reload_cycle_time(10, true), clip_length / 10.0, 0.0001, \
			"the left-hand full load stays unclamped across the whole clip")


func test_sawed_reload_needs_left_hand_stays_3x_false() -> void:
	# 3.x truth (origin/main player_anims.gd reload_weapons): no gun ever
	# reparents to the left hand; the hand motion is the character-side clip,
	# so the sawed-off keeps the export false and stays on the main hand.
	var gun := SAWED_SCENE.instantiate()
	autofree(gun)
	assert_false(gun.reload_needs_left_hand, "the sawed-off is not a left-hand mount gun")


func test_sawed_character_clip_moves_the_hand_and_stays_mainhand() -> void:
	var character : Node = (load(HUMANOID_BASE_SCENE) as PackedScene).instantiate()
	add_child_autofree(character)
	await get_tree().process_frame
	await get_tree().process_frame
	var gun := await _spawn_gun(SAWED_SCENE, character)
	var tree : AnimationTree = character.get_node("CharacterAnimationTree")
	tree.active = true
	await get_tree().process_frame
	var skeleton : Skeleton3D = character.get_node(SKELETON_PATH)
	var baseline : Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone(HAND_BONE))
	character.play_reload_animation(gun)
	for i in 15:
		await get_tree().process_frame
	var moved : float = baseline.origin.distance_to(
			skeleton.get_bone_global_pose(skeleton.find_bone(HAND_BONE)).origin)
	assert_gt(moved, 0.001, "the character clip carries the reload hand motion")
	assert_eq(gun.get_parent(), character.main_hand_root, \
			"the sawed-off stays on the main hand during its reload (3.x truth, no offhand mount)")
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), character.main_hand_root, "the reload end leaves the gun on the main hand")


func _spawn_gun(scene : PackedScene, character : Node = null) -> Node:
	var gun : Node = scene.instantiate()
	add_child_autofree(gun)
	await get_tree().process_frame
	var body := _find_rigid_body(gun)
	if body != null:
		body.freeze = true
	gun.item_state = GlobalConsts.ItemState.EQUIPPED
	if character != null:
		# A held gun rides the main-hand mount; a bare test-tree child would
		# answer the mount assertions with a false parent.
		gun.reparent(character.main_hand_root)
	return gun


func _find_rigid_body(node : Node) -> RigidBody3D:
	if node is RigidBody3D:
		return node
	for child in node.get_children():
		var found := _find_rigid_body(child)
		if found != null:
			return found
	return null


func test_hand_shell_and_chamber_slots_fill_per_landed_shell() -> void:
	var h := _make_harness(SAWED_SCENE, 0, 2)
	var gun : Node = h.gun
	var effects : Node = gun._shell_effects
	assert_true(effects != null, "the sawed-off wires its shell effect node")
	gun.reload()
	assert_true(await _wait_for_landed(gun, 1, 4.0), "the first shell lands")
	var slot_1 : Node = gun.get_node("%ShellPosition1")
	var slot_2 : Node = gun.get_node("%ShellPosition2")
	assert_eq(slot_1.get_child_count(), 1, "shell one fills the first breech slot")
	assert_eq(slot_2.get_child_count(), 0, "the second slot stays empty")
	assert_true(await _wait_for_landed(gun, 2, 4.0), "the second shell lands")
	assert_eq(slot_1.get_child_count(), 1, "no double insert into slot one")
	assert_eq(slot_2.get_child_count(), 1, "shell two fills the second breech slot")
	assert_true(await wait_for_signal(gun.reload_stage_finished, 5.0), "the staged press completes")
	await wait_seconds(0.1)
	assert_eq(slot_1.get_child_count(), 0, "the completion clears the slot visuals")
	assert_eq(slot_2.get_child_count(), 0, "the completion clears the slot visuals")


func _wait_for_landed(gun : Node, landed : int, timeout : float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while gun._staged_rounds_landed < landed and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return gun._staged_rounds_landed >= landed


func test_muzzle_smoke_resource_matches_the_3x_emission_values() -> void:
	for entry in [[SAWED_SCENE, SAWED_SMOKE_PATH], [DOUBLE_BARREL_SCENE, DB_SMOKE_PATH]]:
		var gun : Node = (entry[0] as PackedScene).instantiate()
		autofree(gun)
		var effects : Node = gun.get_node("Effects")
		var smoke_particles : PackedScene = effects.smoke_particles
		assert_eq(smoke_particles.resource_path, entry[1], "the muzzle smoke points at the 3.x smoke scene")
		var smoke := (smoke_particles as PackedScene).instantiate()
		autofree(smoke)
		var material : ParticleProcessMaterial = smoke.process_material
		# The 3.x ParticlesMaterial curves map onto the 4.x min/max windows:
		# initial_velocity 1.9 + randomness 0.49, angular_velocity 10.28 +
		# randomness 1.0, angle randomness 1.0, linear_accel -1.0.
		assert_almost_eq(material.initial_velocity_min, 1.9, 0.0001, "3.x initial velocity floor")
		assert_almost_eq(material.initial_velocity_max, 2.831, 0.0001, "3.x initial velocity randomness span")
		assert_almost_eq(material.angular_velocity_min, 10.28, 0.0001, "3.x angular velocity floor")
		assert_almost_eq(material.angular_velocity_max, 20.56, 0.0001, "3.x angular velocity randomness span")
		assert_almost_eq(material.angle_min, 0.0, 0.0001, "3.x angle floor")
		assert_almost_eq(material.angle_max, 360.0, 0.0001, "3.x angle randomness span")
		assert_almost_eq(material.linear_accel_min, -1.0, 0.0001, "3.x linear accel floor")
		assert_almost_eq(material.linear_accel_max, -1.0, 0.0001, "3.x linear accel ceiling")
