extends GutTest

## Pins the first-start preference prompt state machine (wiki Interface 5.2,
## issue #606): crouch hold-vs-toggle and left-hand mouse choices are plain
## settings writes through the sanctioned flow, and the prompt is a one-time
## panel revealed by the brightness calibration confirm.

const PREFS_SCRIPT := "res://scenes/ui/first_start_preferences.gd"

var _saved_crouch_hold : bool
var _saved_left_hand : bool


func before_each() -> void:
	_saved_crouch_hold = GameSettings.crouch_hold_enabled
	_saved_left_hand = KeyInputSettings.get_left_hand_mouse()


func after_each() -> void:
	GameSettings.set_crouch_hold(_saved_crouch_hold)
	KeyInputSettings.set_left_hand_mouse(_saved_left_hand)


func _spawn_prefs() -> Control:
	var prefs: Control = (load(PREFS_SCRIPT) as GDScript).new()
	add_child(prefs)
	return prefs


func test_show_dialog_presets_the_choices_from_current_settings() -> void:
	var prefs := _spawn_prefs()
	assert_false(prefs.visible, "hidden until the flow reveals it")
	GameSettings.set_crouch_hold(true)
	prefs.show_dialog()
	assert_true(prefs.crouch_hold_chosen, "choice presets to the current crouch mode")
	assert_true(prefs.visible, "dialog visible once shown")


func test_confirm_writes_crouch_and_left_hand_settings() -> void:
	var prefs := _spawn_prefs()
	prefs.choose_crouch_hold(true)
	prefs.choose_left_hand(true)
	prefs.confirm_choices()
	assert_true(GameSettings.crouch_hold_enabled, "crouch hold choice persisted to the setting")
	assert_true(KeyInputSettings.get_left_hand_mouse(), "left-hand choice persisted to the setting")
	assert_true(prefs.confirmed, "the dialog reports itself confirmed")
	assert_false(prefs.visible, "the dialog closes on confirm")

	prefs.choose_crouch_hold(false)
	prefs.choose_left_hand(false)
	prefs.confirm_choices()
	assert_false(GameSettings.crouch_hold_enabled, "toggle choice persisted")
	assert_false(KeyInputSettings.get_left_hand_mouse(), "right-handed choice persisted")


func test_choices_stay_pending_until_confirm() -> void:
	var prefs := _spawn_prefs()
	prefs.show_dialog()
	prefs.choose_crouch_hold(true)
	prefs.choose_left_hand(true)
	assert_eq(GameSettings.crouch_hold_enabled, _saved_crouch_hold,
			"nothing applied before confirm")
	assert_false(KeyInputSettings.get_left_hand_mouse(),
			"nothing applied before confirm")
