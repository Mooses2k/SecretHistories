extends GutTest

## Pins the Gamepad settings tab contract (#268 follow-up): the joypad slot
## of a mapped action is editable from its gamepad row, captures accept
## joypad buttons and axis tilts in canonical form (device -1, full +/-1.0
## travel), the two-slot rule and conflict clearing apply per device class,
## the row's Defaults button restores project joypad bindings, gamepad
## rebinds survive a reboot through the keybinding dict, and keyboard
## capture is unaffected.

const CROUCH := "player|crouch"
const CROUCH_ROW := "gamepad|player|crouch"
const THROW := "playerhand|mainhand_throw"
const THROW_ROW := "gamepad|playerhand|mainhand_throw"
const GAMEPAD_GROUP := "Gamepad Key Settings"

var crouch_events : Array = []
var throw_events : Array = []
var holder : Node
var editor : Node
var panel : Control


func before_each() -> void:
	crouch_events = InputMap.action_get_events(CROUCH).duplicate()
	throw_events = InputMap.action_get_events(THROW).duplicate()


func after_each() -> void:
	_restore_events(CROUCH, crouch_events)
	_restore_events(THROW, throw_events)


func _restore_events(action : String, events : Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		var restored := event as InputEvent
		if restored:
			InputMap.action_add_event(action, restored)
	KeybindingManager.save_keys()


func _pad_button(button_index : int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = -1
	return event


func _pad_motion(axis : int, axis_value : float, device : int = 0) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	event.device = device
	return event


func _key_event(keycode : Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func _joypad_ids(action : String) -> PackedStringArray:
	var ids := PackedStringArray()
	for event in KeyInputSettings._gamepad_events(action):
		ids.append(KeyInputSettings._event_binding_id(event))
	return ids


func _keyboard_ids(action : String) -> PackedStringArray:
	var ids := PackedStringArray()
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			ids.append(KeyInputSettings._event_binding_id(key))
	return ids


func _joypad_event_count() -> int:
	var count := 0
	for _action in InputMap.get_actions():
		var action := String(_action)
		if action.begins_with("ui_"):
			continue
		count += KeyInputSettings._gamepad_events(action).size()
	return count


func test_gamepad_rows_register_only_for_actions_with_joypad_defaults() -> void:
	assert_true(Settings.has_setting(CROUCH_ROW), "crouch has a gamepad row")
	assert_eq(Settings.get_setting_group(CROUCH_ROW), GAMEPAD_GROUP)
	assert_eq(str(Settings.get_setting_meta(CROUCH_ROW, "display_name")), "Crouch")
	assert_eq(str(Settings.get_setting_meta(CROUCH_ROW, "key_category")),
			"Footwork and Movement")
	assert_false(Settings.has_setting("gamepad|kick"),
			"unbound escape-hatch actions stay off the gamepad tab")
	assert_false(Settings.has_setting("gamepad|esc_menu"),
			"esc_menu is not a mapped row, so it stays off the gamepad tab")


func test_joypad_button_capture_edits_only_the_joypad_slot() -> void:
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_DPAD_LEFT))
	assert_eq(_joypad_ids(CROUCH).size(), 2, "the capture appends to the joypad slot")
	assert_true(_joypad_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_pad_button(JOY_BUTTON_DPAD_LEFT))), "D-pad Left joined crouch")
	assert_true(_joypad_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_pad_button(JOY_BUTTON_LEFT_STICK))), "the L3 default stayed")
	assert_true(_keyboard_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_key_event(KEY_CTRL))), "Ctrl survived the gamepad capture")
	assert_true(_keyboard_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_key_event(KEY_C))), "C survived the gamepad capture")
	var labels: PackedStringArray = Settings.get_setting(CROUCH_ROW)
	assert_true(labels.has("Gamepad L3") and labels.has("Gamepad D-pad Left"),
			"the row shows both joypad bindings")


func test_joypad_axis_capture_normalizes_axis_sign_and_device() -> void:
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_motion(JOY_AXIS_LEFT_X, 0.75, 3))
	var found := false
	for event in KeyInputSettings._gamepad_events(CROUCH):
		var motion := event as InputEventJoypadMotion
		if motion and motion.axis == JOY_AXIS_LEFT_X:
			found = true
			assert_eq(motion.axis_value, 1.0, "the tilt collapsed to full travel")
			assert_eq(motion.device, -1, "the capture binds every pad")
	assert_true(found, "the axis capture landed on crouch")
	var labels: PackedStringArray = Settings.get_setting(CROUCH_ROW)
	assert_true(labels.has("Left Stick X+"), "the axis label carries its sign")


func test_two_slot_limit_applies_to_joypad() -> void:
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_DPAD_LEFT))
	assert_eq(_joypad_ids(CROUCH).size(), 2, "precondition: two joypad bindings held")
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_GUIDE))
	assert_eq(_joypad_ids(CROUCH).size(), 1, "the third joypad capture cleared both slots")
	assert_true(_joypad_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_pad_button(JOY_BUTTON_GUIDE))), "the new binding is the only one left")
	assert_true(KeyInputSettings.get_last_conflict_notice().contains("two bindings"),
			"the notice explains the two-slot clear")
	assert_true(_keyboard_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_key_event(KEY_CTRL))) and _keyboard_ids(CROUCH).has(
			KeyInputSettings._event_binding_id(_key_event(KEY_C))),
			"the keyboard slot was untouched by the joypad replace")


func test_gamepad_conflict_clears_one_event_and_names_the_row() -> void:
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_Y))
	assert_eq(KeyInputSettings.get_last_conflict_notice(),
			"Gamepad Y was taken from Main Hand Throw / Drop")
	assert_true(_joypad_ids(THROW).is_empty(), "the Y default moved off mainhand throw")
	var throw_ids := PackedStringArray()
	for event in InputMap.action_get_events(THROW):
		throw_ids.append(KeyInputSettings._event_binding_id(event))
	assert_true(throw_ids.has(KeyInputSettings._event_binding_id(
			_mouse_event(MOUSE_BUTTON_MIDDLE))),
			"mainhand throw keeps its mouse binding")
	assert_true(_joypad_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_pad_button(JOY_BUTTON_Y))), "the conflicting capture landed on crouch")
	var throw_labels: PackedStringArray = Settings.get_setting(THROW_ROW)
	assert_true(throw_labels.is_empty(), "the cleared row's cache emptied")


func _mouse_event(button_index : MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event


func test_defaults_button_restores_project_gamepad_defaults() -> void:
	holder = Node.new()
	add_child_autofree(holder)
	panel = Panel.new()
	panel.name = "ChangeKeyPanel"
	panel.add_child(Label.new())
	holder.add_child(panel)
	var scene: PackedScene = load(
			"res://scenes/ui/settings_ui/settings_editors/gamepad_editor.tscn")
	editor = scene.instantiate()
	holder.add_child(editor)
	editor.attach_setting(CROUCH_ROW, Settings)
	assert_eq((editor.get_node("%Clear") as Button).text, "Defaults",
			"clearing a gamepad slot means restoring its defaults")

	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_DPAD_LEFT))
	assert_eq(_joypad_ids(CROUCH).size(), 2, "precondition: a custom capture is held")
	editor._on_Clear_pressed()
	assert_eq(_joypad_ids(CROUCH).size(), 1, "the custom capture is gone")
	assert_true(_joypad_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_pad_button(JOY_BUTTON_LEFT_STICK))), "the L3 default is back")
	assert_true(_keyboard_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_key_event(KEY_CTRL))), "the keyboard slot survived the defaults restore")


func test_capture_editor_binds_a_pad_button_and_ignores_keyboard() -> void:
	holder = Node.new()
	add_child_autofree(holder)
	panel = Panel.new()
	panel.name = "ChangeKeyPanel"
	var label := Label.new()
	label.name = "Label"
	panel.add_child(label)
	holder.add_child(panel)
	var scene: PackedScene = load(
			"res://scenes/ui/settings_ui/settings_editors/gamepad_editor.tscn")
	editor = scene.instantiate()
	holder.add_child(editor)
	editor.attach_setting(CROUCH_ROW, Settings)

	panel.visible = false
	editor._on_Change_pressed()
	assert_true(panel.visible, "precondition: capture panel armed")
	assert_eq((panel.get_node("Label") as Label).text,
			"Press a Pad Button or Move a Stick to Assign...",
			"the capture asks for a pad button or a stick tilt")

	var key := _key_event(KEY_P)
	key.pressed = true
	editor._input(key)
	assert_true(editor.is_waiting_input, "a keyboard press is ignored, not assigned")
	assert_eq(_joypad_ids(CROUCH).size(), 1, "no joypad binding happened")

	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_DPAD_LEFT
	press.device = 2
	press.pressed = true
	editor._input(press)
	assert_false(editor.is_waiting_input, "the pad press completed the capture")
	assert_true(_joypad_ids(CROUCH).has("jb13_-1"),
			"the capture is stored canonical: D-pad Left on all devices")
	assert_false(panel.visible, "a conflict-free binding hides the panel")
	assert_true(str(Settings.get_setting(CROUCH_ROW)).contains("Gamepad D-pad Left"),
			"the row text refreshed through keys_saved")


func test_subthreshold_tilt_does_not_capture_and_escape_cancels() -> void:
	holder = Node.new()
	add_child_autofree(holder)
	panel = Panel.new()
	panel.name = "ChangeKeyPanel"
	var label := Label.new()
	label.name = "Label"
	panel.add_child(label)
	holder.add_child(panel)
	var scene: PackedScene = load(
			"res://scenes/ui/settings_ui/settings_editors/gamepad_editor.tscn")
	editor = scene.instantiate()
	holder.add_child(editor)
	editor.attach_setting(CROUCH_ROW, Settings)

	panel.visible = false
	editor._on_Change_pressed()
	editor._input(_pad_motion(JOY_AXIS_LEFT_Y, 0.3))
	assert_true(editor.is_waiting_input, "a small tilt keeps capture armed")

	var escape := _key_event(KEY_ESCAPE)
	escape.pressed = true
	editor._input(escape)
	assert_false(editor.is_waiting_input, "Escape cancels the capture")
	assert_false(panel.visible, "the panel hides on cancel")

	panel.visible = false
	editor._on_Change_pressed()
	editor._input(_pad_motion(JOY_AXIS_LEFT_X, -0.8))
	assert_false(editor.is_waiting_input, "a strong tilt completes the capture")
	var found := false
	for event in KeyInputSettings._gamepad_events(CROUCH):
		var motion := event as InputEventJoypadMotion
		if motion and motion.axis == JOY_AXIS_LEFT_X:
			found = true
			assert_eq(motion.axis_value, -1.0, "the tilt stored its direction")
	assert_true(found, "the axis capture landed on crouch")
	var labels: PackedStringArray = Settings.get_setting(CROUCH_ROW)
	assert_true(labels.has("Left Stick X-"), "the negative tilt shows its sign")


func test_reset_rebuilds_gamepad_defaults_and_refreshes_rows() -> void:
	KeyInputSettings.apply_binding(CROUCH, _key_event(KEY_K))
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_DPAD_LEFT))
	assert_eq(InputMap.action_get_events(CROUCH).size(), 3,
			"precondition: keyboard rebind plus two joypad bindings")
	KeyInputSettings.reset_actions()
	assert_eq(InputMap.action_get_events(CROUCH).size(), 3,
			"reset restores the full crouch default set")
	assert_true(_keyboard_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_key_event(KEY_CTRL))) and _keyboard_ids(CROUCH).has(
			KeyInputSettings._event_binding_id(_key_event(KEY_C))),
			"Ctrl and C are back from project.godot")
	assert_eq(_joypad_ids(CROUCH), PackedStringArray(
			[KeyInputSettings._event_binding_id(_pad_button(JOY_BUTTON_LEFT_STICK))]),
			"the joypad slot is back to the L3 default alone")
	assert_eq(Settings.get_setting(CROUCH_ROW), PackedStringArray(["Gamepad L3"]),
			"the gamepad row cache refreshed with the reset")
	assert_eq(_joypad_event_count(), 18, "reset keeps every project joypad default")


func test_gamepad_rebind_survives_reboot_and_legacy_dicts_gain_defaults() -> void:
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_DPAD_LEFT))
	KeybindingManager.save_keys()
	var saved_text: String = FileAccess.get_file_as_string(KeybindingManager.file_name)
	var saved: Variant = str_to_var(saved_text)
	assert_true(saved is Dictionary, "precondition: saved dict parses")
	var saved_dict: Dictionary = saved
	var crouch_row: Array = saved_dict[CROUCH]
	assert_true(crouch_row.has("joyb(13,-1)"), "the D-pad Left capture serializes")
	assert_true(crouch_row.has("joyb(7,-1)"), "the L3 default serializes")

	var merged := _reboot_from(saved_dict)
	assert_false(merged, "rows carrying joypad strings own their joypad state")
	var dleft_count := 0
	for id in _joypad_ids(CROUCH):
		if id == "jb13_-1":
			dleft_count += 1
	assert_eq(dleft_count, 1, "the gamepad rebind survives the reboot, exactly once")
	assert_true(_keyboard_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_key_event(KEY_CTRL))), "the keyboard slot survived the reboot")
	assert_true(_live_matches_project_defaults([CROUCH]),
			"every other action rebooted back onto the project defaults")

	var legacy: Dictionary = {}
	for action_key in saved_dict.keys():
		var strings: Array = []
		for event_str in saved_dict[action_key]:
			var text := str(event_str)
			if not (text.begins_with("joyb") or text.begins_with("joym")):
				strings.append(text)
		legacy[action_key] = strings
	var legacy_merged := _reboot_from(legacy)
	assert_true(legacy_merged, "a legacy keyboard-only dict gains the joypad defaults")
	assert_eq(_joypad_event_count(), 18, "the 18 project joypad defaults are back")
	assert_true(_joypad_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_pad_button(JOY_BUTTON_LEFT_STICK))), "the legacy reboot restored L3")


func _reboot_from(saved_dict : Dictionary) -> bool:
	for _action in InputMap.get_actions():
		var action := String(_action)
		if action.begins_with("ui_"):
			continue
		InputMap.action_erase_events(action)
	KeybindingManager.setup_keys(saved_dict)
	var merged := KeybindingManager._merge_missing_joypad_defaults()
	KeybindingManager._reconcile_default_events()
	return merged


func _live_matches_project_defaults(skip_actions : Array) -> bool:
	var ok := true
	for _action in InputMap.get_actions():
		var action_name := String(_action)
		if action_name.begins_with("ui_") or action_name in skip_actions:
			continue
		if not ProjectSettings.has_setting("input/" + action_name):
			continue
		var config: Variant = ProjectSettings.get_setting("input/" + action_name)
		var default_events: Array = []
		if config is Dictionary and config.get("events") is Array:
			default_events = config.get("events")
		var live := InputMap.action_get_events(action_name)
		if live.size() != default_events.size():
			ok = false
			continue
		for default_event in default_events:
			var event := default_event as InputEvent
			if event and not InputMap.action_has_event(action_name, event):
				ok = false
	return ok


func test_keyboard_capture_is_unaffected_by_gamepad_capture() -> void:
	var keyboard_before := _keyboard_ids(CROUCH)
	KeyInputSettings.apply_gamepad_binding(CROUCH, _pad_button(JOY_BUTTON_DPAD_LEFT))
	assert_eq(_keyboard_ids(CROUCH), keyboard_before,
			"a gamepad capture leaves the keyboard ids alone")
	KeyInputSettings.apply_binding(CROUCH, _key_event(KEY_K))
	# Crouch held two keyboard defaults, so the keyboard capture replaced
	# both with K; both joypad bindings stay.
	assert_eq(_keyboard_ids(CROUCH).size(), 1, "the keyboard rebind replaced both")
	assert_true(_keyboard_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_key_event(KEY_K))), "K is the keyboard binding now")
	assert_eq(_joypad_ids(CROUCH).size(), 2,
			"the keyboard rebind left the joypad slot untouched")
	assert_true(_joypad_ids(CROUCH).has(KeyInputSettings._event_binding_id(
			_pad_button(JOY_BUTTON_DPAD_LEFT))), "the gamepad capture survived")


func test_keyboard_rows_never_show_joypad_labels() -> void:
	var keyboard_labels: PackedStringArray = Settings.get_setting(CROUCH)
	for label in keyboard_labels:
		assert_false(str(label).contains("Gamepad"), "no gamepad label on the keyboard row: %s" % str(label))
		assert_false(str(label).contains("Stick"), "no stick label on the keyboard row: %s" % str(label))
		assert_false(str(label).contains("Trigger"), "no trigger label on the keyboard row: %s" % str(label))
	var gamepad_labels: PackedStringArray = Settings.get_setting(CROUCH_ROW)
	assert_true(gamepad_labels.size() > 0, "precondition: the gamepad row shows bindings")
	for label in gamepad_labels:
		assert_false(str(label).contains("Ctrl"), "no keyboard label on the gamepad row: %s" % str(label))
		assert_true(str(label).begins_with("Gamepad") or str(label).contains("Stick")
				or str(label).contains("Trigger"),
				"the gamepad row shows joypad labels only: %s" % str(label))
