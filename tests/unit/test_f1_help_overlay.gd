# Pins the F1 help overlay (3.x scenes/characters/player/player_hit.gd on
# origin/main): F1 toggles the keybind defaults list and the live debug
# readout, and F1 stays a protected key no user binding can take.
extends GutTest

const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")

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
