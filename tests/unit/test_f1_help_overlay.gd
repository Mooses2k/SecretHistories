# Pins the F1 help overlay (3.x scenes/characters/player/player_hit.gd on
# origin/main): F1 toggles the keybind defaults list and the live debug
# readout, F1 stays a protected key no user binding can take, and the
# readout reports the player's light_level and noise_level live.
extends GutTest

const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")


class _StubPlayer extends Node3D:
	# Minimal stand-in for the humanoid properties the readout rows read.
	var light_level : float = 0.0
	var noise_level : float = 0.0


var _game : Game
var _saved_game : Game
var _ui : GameUI


func before_each() -> void:
	# The hotbar labels inside the real game_ui scene read GameManager.game
	# in _ready; a bare Game stub keeps those reads from hitting Nil.
	_saved_game = GameManager.game
	_game = Game.new()
	GameManager.game = _game
	_ui = UI_SCENE.instantiate()
	add_child_autofree(_ui)
	_game.ui_root = _ui


func after_each() -> void:
	GameManager.game = _saved_game
	if _game != null:
		_game.free()
		_game = null


func _f1_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_F1
	event.physical_keycode = KEY_F1
	event.pressed = true
	return event


func test_F1_toggles_the_help_overlay_twice() -> void:
	var overlay : Control = _ui.get_node("%HelpInfo")
	assert_false(overlay.visible, "the help overlay starts hidden")
	_ui._input(_f1_event())
	assert_true(overlay.visible, "F1 shows the help overlay")
	assert_false(String(overlay.get_node("KeybindDefaults").text).is_empty(),
			"the keybind list is filled")
	_ui._input(_f1_event())
	assert_false(overlay.visible, "a second F1 hides the help overlay")


func test_F1_is_a_protected_key() -> void:
	assert_true(KeyInputSettings.is_protected_key(_f1_event()),
			"F1 stays reserved: no user binding may take it")


func test_debug_readout_fills_when_visible() -> void:
	var overlay : Control = _ui.get_node("%HelpInfo")
	var debug_label : RichTextLabel = overlay.get_node("DebugInfo")
	_ui._input(_f1_event())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(String(debug_label.text).contains("Player durability"),
			"the visible overlay fills the debug readout")


func test_debug_readout_keeps_the_3x_row_set() -> void:
	# 3.x player_hit.gd rows: health, stamina, light_level, noise_level,
	# grounded, strata, position, FPS. Dev4 shows durability (the health
	# analog) and the stamina ratio; every row label must still be present.
	var overlay : Control = _ui.get_node("%HelpInfo")
	var debug_label : RichTextLabel = overlay.get_node("DebugInfo")
	var stub := _StubPlayer.new()
	add_child_autofree(stub)
	overlay.set_player(stub)
	_ui._input(_f1_event())
	await get_tree().process_frame
	await get_tree().process_frame
	var text := String(debug_label.text)
	for row : String in [
		"Player durability", "Player stamina", "Player light_level",
		"Player noise_level", "Player on ground", "Current strata",
		"Player position", "Current FPS",
	]:
		assert_true(text.contains(row), "the readout keeps the row " + row)


func test_light_level_row_reports_the_player_value() -> void:
	var overlay : Control = _ui.get_node("%HelpInfo")
	var debug_label : RichTextLabel = overlay.get_node("DebugInfo")
	var stub := _StubPlayer.new()
	stub.light_level = 0.42
	add_child_autofree(stub)
	overlay.set_player(stub)
	_ui._input(_f1_event())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(String(debug_label.text).contains("Player light_level = 0.42"),
			"the light_level row shows the player's live light_level")


func test_noise_level_row_updates_from_real_values() -> void:
	var overlay : Control = _ui.get_node("%HelpInfo")
	var debug_label : RichTextLabel = overlay.get_node("DebugInfo")
	var stub := _StubPlayer.new()
	stub.noise_level = 8.0
	add_child_autofree(stub)
	overlay.set_player(stub)
	_ui._input(_f1_event())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(String(debug_label.text).contains("Player noise_level = 8"),
			"the noise_level row shows the player's live noise_level")
	stub.noise_level = 5.0
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(String(debug_label.text).contains("Player noise_level = 5"),
			"the noise_level row tracks the changing value")


func test_missing_player_properties_fall_back_without_crashing() -> void:
	var overlay : Control = _ui.get_node("%HelpInfo")
	var debug_label : RichTextLabel = overlay.get_node("DebugInfo")
	overlay.set_player(null)
	_ui._input(_f1_event())
	await get_tree().process_frame
	await get_tree().process_frame
	var text := String(debug_label.text)
	assert_true(text.contains("Player light_level = 0"),
			"a missing player shows the dark default, not a crash")
	assert_true(text.contains("Player noise_level = 0"),
			"a missing player shows the silent default, not a crash")
