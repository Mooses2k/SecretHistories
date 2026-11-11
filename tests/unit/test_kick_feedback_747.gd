extends GutTest

## Pins the 3.x kick feedback restored for issue #747: the movement lock
## while the kick window runs (origin/main player_controller.gd zeroed
## move_direction while the kick timer ran) and the camera stress call the
## frozen character.gd made on every kick (character.gd add_stress(0.25)),
## plus the landed kick-on-door damage entry.

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const DOOR_SCENE := "res://scenes/objects/large_objects/doors/base_kinematic_door.tscn"

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


func _spawn_player() -> HumanoidCharacter:
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	add_child(player)
	var character := player as HumanoidCharacter
	character.state.stamina = 100.0
	character.state.time_since_kick = 10.0
	return character


func test_kick_locks_the_movement_intent_for_the_window() -> void:
	var character := _spawn_player()
	character.input.movement_vector = Vector3(1.0, 0.0, 0.0)
	assert_eq(character.movement_intent(), character.input.movement_vector,
			"before a kick the intent passes through")

	character.kick(true)
	assert_eq(character.movement_intent(), Vector3.ZERO,
			"while the kick window runs the consumed intent is zero")
	assert_eq(character.input.movement_vector, Vector3(1.0, 0.0, 0.0),
			"the lock suppresses consumption, not the input itself")

	# Past the cooldown window (1.0 s, the 3.x KickTimer default) movement
	# resumes.
	character.state.time_since_kick = character.parameters.kick_cooldown + 0.1
	assert_eq(character.movement_intent(), character.input.movement_vector,
			"after the window the intent passes through again")


func test_kick_lock_stops_sprint_engagement() -> void:
	var character := _spawn_player()
	character.input.sprint = true
	character.input.movement_vector = Vector3(0.0, 0.0, -1.0)
	character.state.time_since_kick = 0.0
	character._physics_process(0.016)
	assert_false(character.state.sprinting,
			"no sprint engagement while the kick window runs")

	character.state.time_since_kick = character.parameters.kick_cooldown + 0.1
	character._physics_process(0.016)
	assert_true(character.state.sprinting,
			"sprint engages again after the window")


func test_kick_adds_camera_stress() -> void:
	var character := _spawn_player()
	var camera : Node = character.get_node("ModelRoot/MainCamera")
	assert_true(camera.has_method("add_stress"),
			"the player camera carries the stress shake driver")
	assert_almost_eq(camera.stress, 0.0, 0.0001, "no stress before a kick")

	character.kick(true)
	assert_almost_eq(camera.stress, 0.25, 0.0001,
			"the frozen character.gd kick stress value lands on the camera")

	# The cooldown blocks a second kick, so no second stress addition.
	character.state.time_since_kick = 0.0
	character.state.stamina = 100.0
	character.kick(true)
	assert_almost_eq(camera.stress, 0.25, 0.0001,
			"no double stress from the blocked second kick")


func test_kick_still_damages_a_door() -> void:
	var character : HumanoidCharacter
	# Settle the door first: adding it while the player still stands at the
	# origin ejects the overlapping player body before the kick.
	var door : BaseKinematicDoor = (load(DOOR_SCENE) as PackedScene).instantiate()
	add_child(door)
	door.global_position = Vector3(0.0, 0.0, -0.9)
	for i in 10:
		await get_tree().physics_frame

	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	add_child(player)
	character = player as HumanoidCharacter
	character.state.stamina = 100.0
	character.state.time_since_kick = 10.0
	character.global_position = Vector3(0.0, 1.0, 0.0)
	for i in 10:
		await get_tree().physics_frame

	var health_before := door.health
	character.kick(true)
	for i in 10:
		await get_tree().physics_frame
	assert_lt(door.health, health_before,
			"the landed kick-on-door damage entry still works")
