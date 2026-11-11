extends GutTest
## Character-side reload animation layer (Phase 2 of the reload port):
## the reload library lands on the humanoid AnimationPlayer, the tree
## carries one OneShot per gun named by the SPACE-FREE item_name (the 4.x
## BlendTree strips spaces from node names, loader-verified: "Webley
## revolver" becomes "Webleyrevolver"), and the CharacterReloadAnims
## coordinator runs the 3.x small-gun offhand unequip/re-equip
## choreography on completion and abort (issue #644 bullet 3).

const HUMANOID_BASE_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"
const WEBLEY_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn"
const DB_SHOTGUN_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn"
const LEE_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn"
const DARK_LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/belt_clip_dark_lantern/dark_lantern.tscn"

## 3.x player_anims.tscn character-side clip keys per gun item_name.
const EXPECTED_CLIPS := {
	"Webleyrevolver": "reload/webley_reload",
	"Sawed-offMartinipistol": "reload/kyber_pass_martini_reload",
	"Double-barrelshotgun": "reload/double_barrel_reload",
	"Sawed-offshotgun": "reload/sawed_off_shotgun_reload",
	"Lee-Metfordrifle": "reload/lee_metford_reload",
	"Martini-Henryrifle": "reload/martini_henry_reload",
}

const HAND_BONE := "DEF-forearm.R"
const SKELETON_PATH := "ModelRoot/rig_deform/Skeleton3D"

var _character : Node = null


func before_each() -> void:
	_character = (load(HUMANOID_BASE_SCENE) as PackedScene).instantiate()
	add_child_autofree(_character)
	await get_tree().process_frame
	await get_tree().process_frame


func _animation_player() -> AnimationPlayer:
	return _character.get_node("AnimationPlayer") as AnimationPlayer


func _tree() -> AnimationTree:
	return _character.get_node("CharacterAnimationTree") as AnimationTree


func _skeleton() -> Skeleton3D:
	return _character.get_node(SKELETON_PATH) as Skeleton3D


func _spawn_gun(scene_path : String) -> Node:
	var gun : Node = (load(scene_path) as PackedScene).instantiate()
	add_child_autofree(gun)
	await get_tree().process_frame
	# Freeze the dropped body after _ready (set_physics_dropped resets a
	# freeze applied before add_child; same harness rule as Phase 1), then
	# mark the gun EQUIPPED: the coordinator's restore guard only returns a
	# gun to the hand while it is still equipped, mirroring a held gun.
	var body := _find_rigid_body(gun)
	if body != null:
		body.freeze = true
	gun.item_state = GlobalConsts.ItemState.EQUIPPED
	return gun


func _find_rigid_body(node : Node) -> RigidBody3D:
	if node is RigidBody3D:
		return node
	for child in node.get_children():
		var found := _find_rigid_body(child)
		if found != null:
			return found
	return null


func _hand_pose() -> Transform3D:
	var skeleton := _skeleton()
	return skeleton.get_bone_global_pose(skeleton.find_bone(HAND_BONE))


func _hand_moved_from(baseline : Transform3D) -> float:
	return baseline.origin.distance_to(_hand_pose().origin)


## The Lee-Metford rifle skeleton still stores the Godot 4.6-era pose
## format; Godot 4.7 emits a load-time deprecation error for it (a
## pre-existing asset artifact, flagged to the owner for an editor re-save).
func _tolerate_lee_skeleton_pose_artifact() -> void:
	for e in gut.error_tracker.get_current_test_errors():
		if e.rationale.contains("old pose format"):
			e.handled = true


func _equip_offhand_light() -> Node:
	# The light is placed by hand into the offhand root and the inventory's
	# current_offhand_equipment slot, mirroring a finished equip; the
	# re-equip AFTER the reload goes through the real equip_offhand_item()
	# path (its 0.5 s delay is the 3.x grace under test). Slot 10 (the
	# _ready hands_free slot) is written DIRECTLY: going through the
	# current_offhand_slot SETTER would arm a delayed equip_offhand_item()
	# that resumes 0.5 s later and undoes the reload's unequip mid-test.
	# The lantern's light_detection subtree is stripped: its cone
	# re-triangulates every frame and spams the benign engine warning
	# "Too few vertices per face" (and light-burns the holder), drowning
	# the error tracker the reload assertions rely on.
	var light : Node = (load(DARK_LANTERN_SCENE) as PackedScene).instantiate()
	autofree(light)
	light.is_in_belt = false
	var inv : Inventory = _character.get_node("Inventory")
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	inv.hotbar[10] = light
	inv.current_offhand_equipment = light
	_character.off_hand_root.add_child(light)
	for detection in _nodes_with_script_path(light, "light_detection"):
		detection.queue_free()
	await get_tree().create_timer(0.1).timeout
	return light


func _nodes_with_script_path(node : Node, needle : String) -> Array:
	var found := []
	for child in node.get_children():
		var script : GDScript = child.get_script()
		if script != null and script.resource_path.contains(needle):
			found.append(child)
		found.append_array(_nodes_with_script_path(child, needle))
	return found


func _tolerate_light_harness_artifacts() -> void:
	# Harness-only engine noise from the can_attach belt-clip lantern: its
	# light_detection cone re-triangulates on enter tree, and the
	# PRE-EXISTING equip_offhand_item re-add path add_childs a can_attach
	# item that unequip never unparented (3.x semantics: unequip only
	# clears the slot). Both predate the reload layer; flagged to the owner.
	for e in gut.error_tracker.get_current_test_errors():
		# GUT carries warnings in err.code and errors in err.rationale, so
		# match both fields.
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("Too few vertices per face") \
				or text.contains("already has a parent") \
				or text.contains("p_child->data.parent"):
			e.handled = true


func _start_reload(gun : Node) -> void:
	_character.play_reload_animation(gun)


func test_reload_library_has_the_six_3x_clips() -> void:
	var player := _animation_player()
	assert_true(player.has_animation_library("reload"))
	var clips := player.get_animation_library("reload").get_animation_list()
	var clip_names := []
	for clip in clips:
		clip_names.append(String(clip))
	clip_names.sort()
	assert_eq(clip_names, [
		"double_barrel_reload", "kyber_pass_martini_reload", "lee_metford_reload",
		"martini_henry_reload", "sawed_off_shotgun_reload", "webley_reload"])


func test_tree_carries_one_oneshot_per_gun_with_the_3x_clip_key() -> void:
	var blend_tree := _tree().tree_root as AnimationNodeBlendTree
	var node_connections : Array = blend_tree.node_connections
	# output feeds the last OneShot in the chain
	var output_source := ""
	var pairs := {}
	var i := 0
	while i < node_connections.size():
		var output_node := String(node_connections[i])
		var input_port : int = node_connections[i + 1]
		var input_node := String(node_connections[i + 2])
		if output_node == "output" and input_port == 0:
			output_source = input_node
		pairs[output_node + ":" + str(input_port)] = input_node
		i += 3
	assert_eq(output_source, "Martini-Henryrifle")
	for node_name in EXPECTED_CLIPS:
		assert_true(blend_tree.has_node(node_name), "missing OneShot " + node_name)
		var anim_node : String = pairs[node_name + ":1"]
		var animation := (blend_tree.get_node(anim_node) as AnimationNodeAnimation).animation
		assert_eq(String(animation), EXPECTED_CLIPS[node_name], "clip for " + node_name)
	# the chain starts at the melee_speed node (output previously fed melee_speed)
	assert_eq(pairs["Webleyrevolver:0"], "melee_speed")


func test_play_reload_animation_moves_the_hand_bone() -> void:
	var gun := await _spawn_gun(WEBLEY_SCENE)
	_tree().active = true
	await get_tree().process_frame
	var baseline := _hand_pose()
	_start_reload(gun)
	for i in 15:
		await get_tree().process_frame
	var delta := _hand_moved_from(baseline)
	assert_gt(delta, 0.001, "hand bone moved on the fired reload OneShot")


func test_small_gun_completion_re_equips_the_offhand_light() -> void:
	var light := await _equip_offhand_light()
	var inv : Inventory = _character.get_node("Inventory")
	assert_not_null(inv.current_offhand_equipment, "light equipped before the reload")
	var gun := await _spawn_gun(WEBLEY_SCENE)
	_start_reload(gun)
	await get_tree().process_frame
	assert_null(inv.current_offhand_equipment, "light unequipped during the small-gun reload")
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(inv.current_offhand_equipment, light, "same light re-equipped after completion")


func test_small_gun_abort_re_equips_the_offhand_light() -> void:
	var light := await _equip_offhand_light()
	var inv : Inventory = _character.get_node("Inventory")
	var gun := await _spawn_gun(WEBLEY_SCENE)
	_start_reload(gun)
	await get_tree().process_frame
	assert_null(inv.current_offhand_equipment, "light unequipped during the small-gun reload")
	gun.emit_signal("reload_aborted")
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(inv.current_offhand_equipment, light, "same light re-equipped after the abort")


func test_medium_gun_leaves_the_offhand_alone() -> void:
	var _light := await _equip_offhand_light()
	var inv : Inventory = _character.get_node("Inventory")
	var gun := await _spawn_gun(DB_SHOTGUN_SCENE)
	_start_reload(gun)
	await get_tree().create_timer(0.3).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(inv.current_offhand_equipment, _light, "medium reload must not touch the offhand")


func test_a_tracked_reload_refuses_a_second_start() -> void:
	var light := await _equip_offhand_light()
	var inv : Inventory = _character.get_node("Inventory")
	var webley := await _spawn_gun(WEBLEY_SCENE)
	var db := await _spawn_gun(DB_SHOTGUN_SCENE)
	_start_reload(webley)
	await get_tree().process_frame
	assert_null(inv.current_offhand_equipment, "webley reload tracked")
	_start_reload(db)
	db.emit_signal("reload_stage_finished", 0)
	await get_tree().create_timer(0.4).timeout
	assert_null(inv.current_offhand_equipment, "the second gun's signal must not end the tracked reload")
	webley.emit_signal("reload_stage_finished", 0)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(inv.current_offhand_equipment, light, "only the tracked gun's completion ends the reload")


func test_completion_cuts_a_still_running_clip() -> void:
	var gun := await _spawn_gun(DB_SHOTGUN_SCENE)
	_tree().active = true
	await get_tree().process_frame
	var baseline := _hand_pose()
	_start_reload(gun)
	for i in 10:
		await get_tree().process_frame
	assert_gt(_hand_moved_from(baseline), 0.001, "clip playing before completion")
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().create_timer(0.4).timeout
	# The base pose drifts with the idle cycle (probe-measured ~0.14 over
	# this window), so a tight return-to-baseline bound is meaningless; the
	# held clip pose sits >= 0.25 off base, a released one stays under 0.2.
	assert_lt(_hand_moved_from(baseline), 0.2, "ABORT releases the clip pose once the reload ends")


## ---- Phase 4: left-hand reparenting for the Lee-Metford/Martini-Henry ----


func test_left_hand_gun_mounts_on_the_offhand_and_returns_on_completion() -> void:
	# G2: the composite's clips key the gun pose relative to the left hand,
	# so the gun mounts on the offhand mount for the reload and reparents
	# back to MainHandRoot (global transform kept, hold pose re-applied).
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	assert_true(gun.reload_needs_left_hand, "precondition: the Lee is a left-hand gun")
	_start_reload(gun)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.off_hand_root, "the gun mounts on the offhand for the reload")
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.main_hand_root, "the gun returns to the main hand on completion")
	assert_eq(gun.transform, gun.get_hold_transform(), "the main-hand hold pose is re-applied")


func test_left_hand_abort_returns_the_mount() -> void:
	# G3: the abort arrives after the gun's close beat; the mount restores
	# on the abort path exactly like on completion.
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	_start_reload(gun)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.off_hand_root, "precondition: the gun is mounted")
	gun.emit_signal("reload_aborted")
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.main_hand_root, "the gun returns to the main hand on abort")


func test_left_hand_reload_clears_the_offhand_and_the_medium_rule_holds_it() -> void:
	# Premise flag (flagged to the parent, recorded in the doc): the
	# Lee-Metford is SIZE_MEDIUM, and equip_offhand_item's own guard answers
	# a medium mainhand gun by unequipping it. So the offhand clears for the
	# reload (the left hand is the mount) but does NOT return while the
	# medium gun stays mainhand; it returns as soon as the gun leaves.
	var light := await _equip_offhand_light()
	var inv : Inventory = _character.get_node("Inventory")
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	# Mirror a real equip: the medium gun IS the mainhand equipment (a real
	# press runs through equip_mainhand_item), which is what the medium rule
	# keys on.
	inv.current_mainhand_equipment = gun
	_start_reload(gun)
	await get_tree().process_frame
	assert_null(inv.current_offhand_equipment, "the offhand clears for the left-hand reload")
	assert_eq(gun.get_parent(), _character.off_hand_root, "the mount happens after the unequip (same press)")
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(gun.get_parent(), _character.main_hand_root, "the mount restores")
	assert_null(inv.current_offhand_equipment, "the offhand stays cleared while the medium gun is mainhand")
	assert_eq(inv.hotbar[10], light, "the light stays owned in its hotbar slot")


func test_offhand_returns_when_a_left_hand_gun_left_the_mainhand() -> void:
	# G4: a gun dropped/unequipped mid-reload is a world body; it must NOT
	# be dragged back into the hand. The offhand DOES return (the mainhand
	# is empty, so the medium rule cannot fire).
	var light := await _equip_offhand_light()
	var inv : Inventory = _character.get_node("Inventory")
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	_start_reload(gun)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.off_hand_root, "precondition: the gun is mounted")
	# Drop simulation: the gun leaves its hand mid-reload as a world body.
	gun.get_parent().remove_child(gun)
	gun.item_state = GlobalConsts.ItemState.DROPPED
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().process_frame
	assert_null(gun.get_parent(), "the dropped gun is not dragged back into the hand")
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(inv.current_offhand_equipment, light, "the offhand still returns once the gun left")


func test_ragdoll_mid_reload_still_restores_the_mount() -> void:
	# G5: ragdoll keeps items EQUIPPED, so the restore proceeds; the PalmL
	# BoneAttachment follows the physical bones. A death that drops items
	# instead falls under the dropped-gun guard.
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	_start_reload(gun)
	await get_tree().process_frame
	_character.state.physical_state = HumanoidCharacterState.PhysicalState.KNOCKED_OUT
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.main_hand_root, "the mount restores even while ragdolled")


func test_second_start_does_not_double_mount() -> void:
	# G1: first-press-wins; a second start must not mount a second gun nor
	# steal the tracking.
	var webley := await _spawn_gun(WEBLEY_SCENE)
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	_start_reload(gun)
	await get_tree().process_frame
	_start_reload(webley)
	await get_tree().process_frame
	assert_ne(webley.get_parent(), _character.off_hand_root, "the refused press must not mount")
	assert_eq(gun.get_parent(), _character.off_hand_root, "the first press stays tracked and mounted")
	webley.emit_signal("reload_stage_finished", 0)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.off_hand_root, "the second gun's signal must not end the tracked reload")
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.main_hand_root, "only the tracked gun's completion restores")


func test_scene_exit_travels_the_gun_with_the_character() -> void:
	# G6: on scene exit the whole subtree (mounted gun included) tears down
	# together; the coordinator's exit guard must never orphan the gun into
	# the world.
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	_start_reload(gun)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.off_hand_root, "precondition: the gun rides the character subtree")
	_character.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(gun), "the gun goes down with the character, never orphaned")


func test_mount_restore_runs_exactly_once_per_reload() -> void:
	# G7: the end guard is single-shot; a completion followed by a stray
	# abort signal must not process twice.
	var gun := await _spawn_gun(LEE_SCENE)
	_tolerate_lee_skeleton_pose_artifact()
	_start_reload(gun)
	await get_tree().process_frame
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.main_hand_root, "precondition: restored once")
	gun.emit_signal("reload_aborted")
	await get_tree().process_frame
	assert_eq(gun.get_parent(), _character.main_hand_root, "the stray signal must not process again")
	assert_eq(gun.transform, gun.get_hold_transform(), "the hold pose is untouched by the stray signal")
