extends GutTest

## Pins the left-hand mouse swap (wiki Interface 5.2: "Accessible, have
## left-hand mouse bind as well", issue #606). The setting exchanges the
## keyboard and mouse events between mainhand use (LMB) and interact (RMB)
## in the settings layer: reversible, idempotent on boot against an already
## swapped keybinding.dict, refusing when custom rebinds blur the roles, and
## re-applied by reset-to-defaults when enabled.

const MAINHAND := "playerhand|mainhand_use"
const INTERACT := "player|interact"

var _saved_left_hand : bool = false
var _saved_mainhand_events : Array = []
var _saved_interact_events : Array = []


func before_each() -> void:
	_saved_left_hand = KeyInputSettings.get_left_hand_mouse()
	_saved_mainhand_events = InputMap.action_get_events(MAINHAND).duplicate()
	_saved_interact_events = InputMap.action_get_events(INTERACT).duplicate()


func after_each() -> void:
	Settings.set_setting(KeyInputSettings.SETTING_LEFT_HAND, _saved_left_hand)
	_restore_events(MAINHAND, _saved_mainhand_events)
	_restore_events(INTERACT, _saved_interact_events)


func _restore_events(action : String, events : Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		var restored := event as InputEvent
		if restored:
			InputMap.action_add_event(action, restored)
	KeybindingManager.save_keys()


func _mouse_event(button_index : int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event


func _has_mouse(action : String, button_index : int) -> bool:
	for event in InputMap.action_get_events(action):
		var mouse := event as InputEventMouseButton
		if mouse and mouse.button_index == button_index:
			return true
	return false


func test_left_hand_row_registered_in_the_player_actions_family() -> void:
	assert_true(Settings.has_setting(KeyInputSettings.SETTING_LEFT_HAND),
			"row registered")
	assert_eq(Settings.get_setting_group(KeyInputSettings.SETTING_LEFT_HAND),
			"Input Key Settings")
	assert_eq(str(Settings.get_setting_meta(KeyInputSettings.SETTING_LEFT_HAND,
			"key_category")), "Player Actions")
	assert_false(bool(Settings.get_setting(KeyInputSettings.SETTING_LEFT_HAND)),
			"right-handed by default")


func test_left_hand_swap_exchanges_lmb_and_rmb_roles() -> void:
	assert_true(_has_mouse(MAINHAND, MOUSE_BUTTON_LEFT), "precondition: LMB on mainhand")
	assert_true(_has_mouse(INTERACT, MOUSE_BUTTON_RIGHT), "precondition: RMB on interact")

	assert_true(KeyInputSettings._apply_left_hand_swap(true), "the swap applies")
	assert_true(_has_mouse(INTERACT, MOUSE_BUTTON_LEFT), "LMB now drives interact")
	assert_true(_has_mouse(MAINHAND, MOUSE_BUTTON_RIGHT), "RMB now drives mainhand use")
	assert_false(_has_mouse(MAINHAND, MOUSE_BUTTON_LEFT), "LMB left mainhand")

	assert_false(KeyInputSettings._apply_left_hand_swap(true),
			"already swapped: a second enable is a no-op (boot idempotence)")

	assert_true(KeyInputSettings._apply_left_hand_swap(false), "the swap reverses")
	assert_true(_has_mouse(MAINHAND, MOUSE_BUTTON_LEFT), "LMB back on mainhand")
	assert_true(_has_mouse(INTERACT, MOUSE_BUTTON_RIGHT), "RMB back on interact")


func test_left_hand_setting_toggle_applies_the_swap() -> void:
	KeyInputSettings.set_left_hand_mouse(true)
	assert_true(_has_mouse(INTERACT, MOUSE_BUTTON_LEFT),
			"the setting change drives the swap through the changed handler")
	KeyInputSettings.set_left_hand_mouse(false)
	assert_true(_has_mouse(MAINHAND, MOUSE_BUTTON_LEFT),
			"disabling restores the right-handed roles")


func test_left_hand_swap_refuses_when_roles_are_blurred() -> void:
	# A user rebind that put LMB on both actions carries no unambiguous
	# roles to exchange: the swap must refuse instead of reshuffling.
	var mainhand_before: Array = InputMap.action_get_events(MAINHAND).duplicate()
	var interact_before: Array = InputMap.action_get_events(INTERACT).duplicate()
	KeyInputSettings._clear_bindable_events(MAINHAND)
	KeyInputSettings._clear_bindable_events(INTERACT)
	InputMap.action_add_event(MAINHAND, _mouse_event(MOUSE_BUTTON_LEFT))
	InputMap.action_add_event(INTERACT, _mouse_event(MOUSE_BUTTON_LEFT))
	assert_false(KeyInputSettings._apply_left_hand_swap(true),
			"refuse to swap ambiguous roles")
	_restore_events(MAINHAND, mainhand_before)
	_restore_events(INTERACT, interact_before)


func test_reset_leaves_left_hand_mouse_off() -> void:
	# Reset restores the right-handed project defaults and turns the
	# left-hand mouse flag off: after reset the map is right-handed.
	KeyInputSettings.set_left_hand_mouse(true)
	assert_true(_has_mouse(INTERACT, MOUSE_BUTTON_LEFT), "precondition: swapped")
	KeyInputSettings.reset_actions()
	assert_false(KeyInputSettings.get_left_hand_mouse(),
			"reset turns the left-hand flag off")
	assert_true(_has_mouse(MAINHAND, MOUSE_BUTTON_LEFT), "LMB back on mainhand")
	assert_true(_has_mouse(INTERACT, MOUSE_BUTTON_RIGHT), "RMB back on interact")
