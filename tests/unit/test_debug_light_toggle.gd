# Pins the L-key screen filter cycle: the input action exists bound to L,
# the player scene carries the camera SpotLight, and tapping L cycles the
# 3.x filter order whose last stop (DEBUG_LIGHT) turns the light on and
# whose wrap to NONE turns it off again.
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const LIGHT_ACTION := "misc|change_screen_filter"

var _world : Node3D
var _player : Node3D
var _game : Game
var _saved_game : Game


func before_each() -> void:
	# The player's interact_controller reads GameManager.game.ui_root every
	# tick; a bare Game stub with a plain Control keeps that read off Nil.
	_saved_game = GameManager.game
	_game = Game.new()
	GameManager.game = _game
	# The real game_ui scene: its HUD is what interact_controller looks at.
	var ui : GameUI = UI_SCENE.instantiate()
	add_child_autofree(ui)
	_game.ui_root = ui


func after_each() -> void:
	GameManager.game = _saved_game
	if Input.is_action_pressed(LIGHT_ACTION):
		Input.action_release(LIGHT_ACTION)
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _tap_action(action : String) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)
	await _physics_frames(2)


func _spawn_player() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(_player)
	await _physics_frames(2)


func _light(action_owner : Node) -> SpotLight3D:
	return action_owner.get_node("../ModelRoot/MainCamera/DebugLight") as SpotLight3D


func test_action_exists_and_defaults_to_L() -> void:
	assert_true(InputMap.has_action(LIGHT_ACTION), "the change_screen_filter action exists")
	var events := InputMap.action_get_events(LIGHT_ACTION)
	var has_l := false
	for event in events:
		var key := event as InputEventKey
		if key != null and key.keycode == KEY_L:
			has_l = true
	assert_true(has_l, "the action is bound to the L key")


func test_player_scene_carries_a_camera_debug_light() -> void:
	await _spawn_player()
	var controller := _player.get_node("PlayerController")
	var light := _light(controller)
	assert_not_null(light, "the player scene has a camera DebugLight")
	assert_false(light.visible, "the debug light starts off")


func test_L_taps_reach_the_debug_light_stop_and_wrap_off() -> void:
	# 3.x parity: the light is the LAST stop of the L screen-filter cycle
	# (5 shader stops before it), so tap 6 turns the light on and tap 7
	# wraps to NONE and turns it off.
	await _spawn_player()
	var light := _light(_player.get_node("PlayerController"))
	for i in 5:
		await _tap_action(LIGHT_ACTION)
		await _physics_frames(1)
	assert_false(light.visible, "the light stays off through the five shader stops")
	await _tap_action(LIGHT_ACTION)
	await _physics_frames(1)
	assert_true(light.visible, "the sixth tap, DEBUG_LIGHT, turns the light on")
	await _tap_action(LIGHT_ACTION)
	await _physics_frames(1)
	assert_false(light.visible, "the seventh tap wraps to NONE and turns the light off")
