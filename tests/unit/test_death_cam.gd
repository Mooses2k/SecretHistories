# Pins the issue 414 death cam: on the player's DEAD physical state the FPS
# camera mounts to a head-bone BoneAttachment3D and rides the ragdoll down,
# the ragdoll engages, dead mouse motion drives a tiny damped head look, and
# the camera ray clamp keeps the view inside walls. The fade/stencil and the
# ESC path are pinned in test_death_screen.gd; the death ring is pinned in
# test_tinnitus_overlay.gd.
extends GutTest

const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const HEAD_BONE_NAME := "DEF-spine.006"
const LOOK_MAX := 0.3

var _ui : GameUI
var _world : Node3D
var _game : Game
var _saved_game : Game
var _saved_is_player_dead : bool
var _saved_paused : bool


func before_each() -> void:
	_saved_game = GameManager.game
	_saved_is_player_dead = GameManager.is_player_dead
	_saved_paused = get_tree().paused
	# Hotbar slots inside the real game_ui scene read GameManager.game in
	# _ready; a bare Game stub whose player is null makes them await
	# player_spawned quietly instead of erroring.
	_game = Game.new()
	GameManager.game = _game
	_ui = UI_SCENE.instantiate()
	add_child_autofree(_ui)
	_game.ui_root = _ui


func after_each() -> void:
	GameManager.game = _saved_game
	GameManager.is_player_dead = _saved_is_player_dead
	get_tree().paused = _saved_paused
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _spawn_player(at : Vector3) -> Node3D:
	_world = Node3D.new()
	add_child_autofree(_world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.5, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = at
	_world.add_child(player)
	_game.player = player
	await _physics_frames(5)
	return player


func _kill(player : Node3D) -> void:
	var hurtbox : Hurtbox = player.find_children("*", "Hurtbox", true, false)[0]
	hurtbox.damage(1000, GlobalConsts.AttackTypes.BLUDGEONING)


func test_death_mounts_the_camera_to_the_head_bone() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	assert_true(camera.get_parent().name == "ModelRoot", "sanity: the camera rides ModelRoot while alive")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(3)
	var mount : BoneAttachment3D = player.get_node_or_null(
		"ModelRoot/rig_deform/Skeleton3D/DeathCamMount") as BoneAttachment3D
	assert_not_null(mount, "the death cam mount exists on the skeleton")
	assert_eq(mount.bone_name, HEAD_BONE_NAME, "the mount rides the head-most spine bone")
	var pivot : Node3D = mount.get_node("DeathCamLook") as Node3D
	assert_not_null(pivot, "the look pivot hangs under the bone mount")
	assert_true(camera.get_parent() == pivot,
		"the FPS camera is parented under the head bone mount at death")
	assert_not_null(player.get_node_or_null("DeathCam"), "the death cam node lives on the player")


func test_death_engages_the_ragdoll() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var humanoid := player as HumanoidCharacter
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(3)
	assert_eq(humanoid.state.physical_state, HumanoidCharacterState.PhysicalState.DEAD)
	assert_true(humanoid.state.is_ragdolled(), "the ragdoll state engages on death")
	assert_true(humanoid.freeze, "the rigid body is frozen so only the bones simulate")
	assert_true(humanoid.character_collision.disabled, "the standing collider is out of the way")


func test_the_camera_falls_with_the_body() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(2)
	var camera_start_y : float = camera.global_position.y
	await _physics_frames(40)
	assert_lt(camera.global_position.y, camera_start_y - 0.2,
		"the camera rides the ragdoll down to the ground")
	var spine_y : float = (player.get_node(
		"ModelRoot/rig_deform/Skeleton3D/CharacterRagdoll/Physical Bone DEF-spine")
		as Node3D).global_position.y
	assert_lt(spine_y, 1.0, "the corpse has fallen near the floor")


func test_dead_mouse_motion_gives_a_tiny_damped_head_look() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(3)
	var death_cam : Node = player.get_node("DeathCam")
	death_cam.call("apply_death_look", Vector2(10_000.0, 0.0))
	await _physics_frames(3)
	var pivot : Node3D = player.get_node(
		"ModelRoot/rig_deform/Skeleton3D/DeathCamMount/DeathCamLook") as Node3D
	var yaw : float = pivot.rotation.y
	assert_true(yaw < -0.005, "the head look moved toward the mouse direction")
	assert_true(yaw >= -LOOK_MAX - 0.001, "the head look stays inside its tiny range")
	death_cam.call("apply_death_look", Vector2(-10_000.0, 0.0))
	await _physics_frames(3)
	assert_true(pivot.rotation.y > yaw, "the look damps back toward the new target")


func test_the_camera_stays_inside_walls() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(3)
	var death_cam : Node = player.get_node("DeathCam")
	var mount : Node3D = player.get_node(
		"ModelRoot/rig_deform/Skeleton3D/DeathCamMount")
	var camera : Camera3D = mount.get_node("DeathCamLook").get_child(0) as Camera3D
	# A wall one metre from the head mount, along the mount-to-camera ray.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(4.0, 4.0, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	var direction : Vector3 = (camera.global_position - mount.global_position).normalized()
	_world.add_child(wall)
	wall.global_position = mount.global_position + direction
	await _physics_frames(2)
	# Push the camera past the wall and run the clamp by hand.
	camera.global_position = mount.global_position + direction * 3.0
	death_cam.call("_clamp_camera_into_walls")
	var clamped : Vector3 = camera.global_position
	var behind_wall : float = (clamped - mount.global_position).dot(direction)
	assert_lt(behind_wall, 1.1, "the clamp pulls the camera back in front of the wall")
