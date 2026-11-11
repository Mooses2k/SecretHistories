extends GutTest
## Pins the restored 3.x landing camera stress (origin/main character.gd:435-438):
## the same landing that plays the land sound kicked the camera with
## add_stress(0.25). The 3.x qualifying landing was is_on_floor() while the
## jump flag was still true (is_jumping, set at character.gd:489, cleared on
## the first grounded frame at :447): no fall-distance threshold, no velocity
## threshold, and not crouch-gated (the old stress < 0.1 cap was already
## removed in 3.x itself, kept only as the line 435 comment). Walk-steps and
## grounded settles never set the flag, so they never fired it.

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const HUMANOID_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"

# The player scene's interact controller reads GameManager.game.ui_root every
# frame; without a Game stub the physics waits spam ui_root errors (same
# harness setup as test_kick_feedback_747).
var _saved_game : Game
var _game : Game
var _ui : GameUI
var _hud : HUD


func before_each() -> void:
	_saved_game = GameManager.game
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


func after_each() -> void:
	GameManager.game = _saved_game
	_game.free()
	_ui.free()
	_hud.free()


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 1.0, 8.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)


func _spawn_character(scene_path : String, spawn_height : float) -> HumanoidCharacter:
	var node : Node3D = (load(scene_path) as PackedScene).instantiate()
	node.position = Vector3(0.0, spawn_height, 0.0)
	add_child_autofree(node)
	return node as HumanoidCharacter


func _await_landing_stress(character : HumanoidCharacter, max_frames : int = 240) -> float:
	var camera : Node = character.get_node("ModelRoot/MainCamera")
	for i in max_frames:
		await get_tree().physics_frame
		var stress : float = camera.get("stress")
		if stress > 0.0:
			return stress
	return 0.0


func test_qualifying_landing_fires_the_camera_stress() -> void:
	_add_floor()
	var character := _spawn_character(PLAYER_SCENE, 1.2)
	var camera : Node = character.get_node("ModelRoot/MainCamera")
	assert_true(camera.has_method("add_stress"),
		"precondition: the player camera carries the stress driver")
	# The 3.x gate in dev4 terms: the jump flag set on jump, fired on the
	# first grounded frame after it.
	character._is_jumping = true

	var stress := await _await_landing_stress(character)

	assert_gt(stress, 0.0, "a landing that regains ground after a jump fires the camera stress")
	assert_almost_eq(stress, 0.25, 0.05, "the 3.x landing stress amount reaches the camera")
	assert_true(character.state.is_on_ground, "the stress arrived on an actual grounded landing")


func test_grounded_settle_and_walk_with_no_airtime_never_fire_the_stress() -> void:
	# The 3.x gate was the jump flag, so a grounded character with no jump
	# airtime never fired it: neither the ground-regain transition on settle
	# nor later grounded steps.
	_add_floor()
	var character := _spawn_character(PLAYER_SCENE, 0.05)
	for i in 60:
		await get_tree().physics_frame

	var camera : Node = character.get_node("ModelRoot/MainCamera")
	var stress : float = camera.get("stress")

	assert_true(character.state.is_on_ground, "the character actually settled on the ground")
	assert_eq(stress, 0.0, "no camera stress without jump airtime, even across the ground-regain transition")


func test_landing_without_a_camera_is_null_safe_and_still_lands_the_noise() -> void:
	# Cultists and every camera-less humanoid take the same landing branch:
	# the camera seam resolves null and skips. 3.x was effectively
	# player-only: player_controller.gd:285 was do_jump's only writer and
	# only the player rig carried FPSCamera.
	_add_floor()
	var character := _spawn_character(HUMANOID_SCENE, 1.2)
	assert_null(character.get_node_or_null("ModelRoot/MainCamera"),
		"precondition: the base rig has no camera")
	character._is_jumping = true

	for i in 240:
		await get_tree().physics_frame
		if character.noise_level > 0.0:
			break

	assert_almost_eq(character.noise_level, HumanoidCharacter.LANDING_NOISE, 0.0001,
		"the landing branch ran fully with no camera: land noise applied, no error")
