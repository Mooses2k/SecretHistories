# Head bob port tests (M5): the 3.x head bob restored on the dev4 camera
# seam. Pinned here: the bob runs on a moving grounded player with the 3.x
# math (one cycle per second, amplitude 0.5 / 1000 per speed unit,
# origin/main fps_control_mode.gd:204-216), the standing reset (no bob
# while not moving, the 3.x velocity == 0 branch), no bob while dead (the
# death cam owns the camera), no bob while head_bob_enabled is false, and
# the position-only seam: the bob writes only camera position.y and never
# touches the roll axis, so the runtime-mounted camera stress shake keeps
# owning rotation.z (3.x itself commented the rotation half out for motion
# sickness, origin/main fps_control_mode.gd:213-216).
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const SETTLE_FRAMES : int = 60

var _world : Node3D
var _game : Game
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _saved_dead : bool


func before_each() -> void:
	# Headless stub set that keeps the real per-frame handlers error-free
	# (interact_controller needs ui_root.hud_root). Same pattern as the ADS
	# tests.
	_saved_game = GameManager.game
	_world = Node3D.new()
	add_child_autofree(_world)
	_game = Game.new()
	_ui = GameUI.new()
	_hud = HUD.new()
	var indicators : Array[TextureRect] = [
		TextureRect.new(), TextureRect.new(), TextureRect.new(),
	]
	_hud.indicators = indicators
	_hud.add_child(indicators[0])
	_hud.add_child(indicators[1])
	_hud.add_child(indicators[2])
	_ui.hud_root = _hud
	_game.ui_root = _ui
	GameManager.game = _game
	_saved_dead = GameManager.is_player_dead
	GameManager.is_player_dead = false


func after_each() -> void:
	GameManager.is_player_dead = _saved_dead
	GameManager.game = _saved_game
	Input.action_release(&"movement|move_up")
	# Free the stub set the ADS tests free: the world content is released
	# by add_child_autofree, these three never enter the tree.
	_hud.free()
	_ui.free()
	_game.free()


func _spawn_player() -> HumanoidCharacter:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.5, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	var player : HumanoidCharacter = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	await _frames(5)
	return player


func _frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame
	_mark_preexisting_asset_noise_handled()


func _mark_preexisting_asset_noise_handled() -> void:
	for err in get_errors():
		if not err.handled and (
			err.contains_text("invalid UID")
			or err.contains_text("Skeleton uses old pose format")
			or err.contains_text("Mesh uses old surface format")
			# Another bridge lane's client can eval into this headless
			# instance while it holds port 9090; that parse error is the
			# eval channel, not this suite.
			or err.contains_text("Identifier \"GameState\"")
		):
			err.handled = true


func _controller(player : HumanoidCharacter) -> PlayerController:
	return player.get_node("PlayerController") as PlayerController


func test_moving_player_bobs_with_the_3x_math() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	Input.action_press(&"movement|move_up")
	await _frames(SETTLE_FRAMES)
	assert_gt(pc._bob_time, 0.9, "the bob clock advanced about one second over 60 frames: the 3.x one-cycle-per-second rate")
	var speed : float = pc._planar_speed()
	assert_gt(speed, 0.5, "sanity: the player is actually moving on the ground")
	# The offset accumulates one sine sample per frame, so its running-sum
	# bound is the discrete integral factor: with frames at the headless 60
	# fps clock the sum of sin samples is bounded by (frames per second) /
	# PI times the per-sample amplitude.
	var bound := speed * PlayerController.BOB_AMPLITUDE * 60.0 / PI * 1.05
	assert_lt(absf(pc._bob_offset), bound, "the offset stays inside the 3.x accumulated sine bound")
	assert_ne(pc._bob_offset, 0.0, "the bob offset is live on a moving grounded player")
	assert_eq(PlayerController.BOB_AMPLITUDE, 0.5 / 1000.0, "the 3.x amplitude constant (fps_control_mode.gd:210)")


func test_standing_player_has_no_bob() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	await _frames(SETTLE_FRAMES)
	assert_eq(pc._bob_offset, 0.0, "a standing player carries no bob offset, the 3.x velocity == 0 reset")
	assert_eq(pc._bob_time, 0.0, "the bob clock does not advance while standing")


func test_dead_player_has_no_bob() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	GameManager.is_player_dead = true
	Input.action_press(&"movement|move_up")
	await _frames(10)
	assert_eq(pc._bob_offset, 0.0, "a dead player carries no bob offset: the death cam owns the camera")
	assert_eq(pc._bob_time, 0.0, "the bob clock stays frozen while dead")


func test_bob_disabled_by_the_3x_gate_export() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	pc.head_bob_enabled = false
	Input.action_press(&"movement|move_up")
	await _frames(10)
	assert_eq(pc._bob_offset, 0.0, "head_bob_enabled false suppresses the bob, per the 3.x gate")


func test_bob_is_position_only_and_does_not_fight_the_stress_roll() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	Input.action_press(&"movement|move_up")
	await _frames(10)
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	assert_eq(camera.rotation.z, 0.0, "bobbing frames leave the roll axis at rest while stress is zero")
	# The stress shake (runtime-mounted camera_stress_shake.gd) owns
	# rotation.z; the bob must keep offsetting position while the roll runs.
	# Note: the GUT headless context does not tick the runtime-mounted
	# camera script's _process (verified fresh: stress stayed 0.5 across
	# frames with the script mounted), so the roll is driven by one manual
	# tick of the same _process the live game runs.
	camera.add_stress(0.5)
	camera._process(1.0 / 60.0)
	assert_ne(camera.rotation.z, 0.0, "the stress shake still drives the roll while the bob runs")
	assert_ne(pc._bob_offset, 0.0, "the bob offset is live while the stress roll runs")
	# And the two live on different channels: position vs rotation.
	var before_pos := camera.position.y
	await _frames(2)
	assert_ne(camera.position.y, before_pos, "the bob keeps writing position.y beside the roll")