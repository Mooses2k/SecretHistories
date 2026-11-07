extends GutTest

## Pins the Shift overload composition settings (wiki Interface 5.2.1,
## issue #606). The presets configure which behaviors the Shift family
## composes; the gates live at the HumanoidCharacter seam, and only the
## CONTEXTUAL source (kick() with no argument, dodge(), state.sprinting) is
## gated. The separately bound kick key always fires.

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _saved_preset : int = 0
var _saved_kick : bool = true
var _saved_dodge : bool = true
var _saved_sprint : bool = true
# Same headless stub set as test_separate_bindable_triggers_606: keeps the
# spawned player's per-frame handlers error-free.
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
	_saved_preset = KeyInputSettings.get_overload_preset()
	_saved_kick = KeyInputSettings.shift_kick_enabled()
	_saved_dodge = KeyInputSettings.shift_dodge_enabled()
	_saved_sprint = KeyInputSettings.shift_sprint_enabled()


func after_each() -> void:
	Settings.set_setting(KeyInputSettings.SETTING_OVERLOAD_PRESET, _saved_preset)
	Settings.set_setting(KeyInputSettings.SETTING_SHIFT_KICK, _saved_kick)
	Settings.set_setting(KeyInputSettings.SETTING_SHIFT_DODGE, _saved_dodge)
	Settings.set_setting(KeyInputSettings.SETTING_SHIFT_SPRINT, _saved_sprint)
	GameManager.game = _saved_game
	_game.free()
	_ui.free()
	_hud.free()


func test_overload_rows_registered_in_the_footwork_family() -> void:
	var names: Array = Settings.get_settings_list()
	var sprint_index: int = names.find("player|sprint")
	var preset_index: int = names.find(KeyInputSettings.SETTING_OVERLOAD_PRESET)
	var kick_index: int = names.find(KeyInputSettings.SETTING_SHIFT_KICK)
	var dodge_index: int = names.find(KeyInputSettings.SETTING_SHIFT_DODGE)
	var sprint_mode_index: int = names.find(KeyInputSettings.SETTING_SHIFT_SPRINT)
	for index in [preset_index, kick_index, dodge_index, sprint_mode_index]:
		assert_true(index != -1, "overload row registered")
		assert_true(index > sprint_index, "overload row renders after the Shift row")
	assert_eq(Settings.get_setting_group(KeyInputSettings.SETTING_OVERLOAD_PRESET),
			"Input Key Settings")


func test_default_preset_composes_sprint_kick_and_dodge() -> void:
	assert_eq(KeyInputSettings.get_overload_preset(), 0, "default preset is the full bundle")
	assert_true(KeyInputSettings.shift_kick_enabled(), "kick on by default")
	assert_true(KeyInputSettings.shift_dodge_enabled(), "dodge on by default")
	assert_true(KeyInputSettings.shift_sprint_enabled(), "sprint on by default")


func test_preset_bundles_write_the_per_behavior_bools() -> void:
	KeyInputSettings.set_overload_preset(3)
	assert_true(KeyInputSettings.shift_kick_enabled(), "Kick bundle keeps kick")
	assert_false(KeyInputSettings.shift_dodge_enabled(), "Kick bundle drops dodge")
	assert_false(KeyInputSettings.shift_sprint_enabled(), "Kick bundle drops sprint")

	KeyInputSettings.set_overload_preset(2)
	assert_true(KeyInputSettings.shift_dodge_enabled(), "Sprint / dodge keeps dodge")
	assert_false(KeyInputSettings.shift_sprint_enabled(), "Sprint / dodge drops sprint")
	assert_true(KeyInputSettings.shift_kick_enabled(), "Sprint / dodge keeps kick")

	KeyInputSettings.set_overload_preset(0)
	assert_true(KeyInputSettings.shift_sprint_enabled(), "full bundle restores sprint")
	assert_true(KeyInputSettings.shift_dodge_enabled(), "full bundle restores dodge")


func _spawn_player() -> Node3D:
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	add_child(player)
	return player


func _kick_stamina_delta(character : HumanoidCharacter, from_action : bool) -> float:
	var state := character.state
	state.stamina = 100.0
	state.time_since_kick = 10.0
	character.kick(from_action)
	return 100.0 - state.stamina


func test_contextual_kick_gate_blocks_only_the_contextual_source() -> void:
	var player : Node3D = _spawn_player()
	var character := player as HumanoidCharacter
	KeyInputSettings.set_shift_kick(false)
	assert_almost_eq(_kick_stamina_delta(character, false), 0.0, 0.0001,
			"the contextual Shift-tap kick is gated off")
	assert_almost_eq(_kick_stamina_delta(character, true), 50.0, 0.0001,
			"the separately bound kick key always fires")

	KeyInputSettings.set_shift_kick(true)
	assert_almost_eq(_kick_stamina_delta(character, false), 50.0, 0.0001,
			"the contextual kick returns when the setting is on")


func test_dodge_gate_blocks_the_contextual_dodge() -> void:
	var player : Node3D = _spawn_player()
	var character := player as HumanoidCharacter
	var state := character.state
	KeyInputSettings.set_shift_dodge(false)
	state.stamina = 100.0
	state.time_since_dodge = 10.0
	character.input.movement_vector = Vector3(1.0, 0.0, 0.0)
	character.dodge()
	assert_almost_eq(state.stamina, 100.0, 0.0001, "no dodge cost when gated off")

	KeyInputSettings.set_shift_dodge(true)
	state.time_since_dodge = 10.0
	character.dodge()
	assert_almost_eq(100.0 - state.stamina, character.parameters.dodge_stamina_cost, 0.0001,
			"the dodge fires when the setting is on")


func test_sprint_gate_stops_the_sprint_state() -> void:
	var player : Node3D = _spawn_player()
	var character := player as HumanoidCharacter
	var state := character.state
	character.input.sprint = true
	character.input.movement_vector = Vector3(0.0, 0.0, -1.0)
	state.stamina = 100.0

	KeyInputSettings.set_shift_sprint(false)
	character._physics_process(0.016)
	assert_false(state.sprinting, "no sprint when the Shift-overload sprint is off")

	KeyInputSettings.set_shift_sprint(true)
	character._physics_process(0.016)
	assert_true(state.sprinting, "sprint when the setting is on")
