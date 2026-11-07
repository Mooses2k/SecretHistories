extends GutTest

## Unit tests for the declarative keybinding settings map (issues #307 and
## #606): row coverage, render metadata, mode adjacency, capture apply with
## explicit conflict clearing, and reset straight from project.godot.

const MAP_GROUP : String = "Input Key Settings"
const MODE_CROUCH : String = "Hold Crouch"
const MODE_ADS : String = "Hold ADS (Aim Down Sights)"


func test_every_mapped_action_exists_in_input_map() -> void:
	for category_entry in KeyInputSettings.BINDING_MAP:
		var entry: Dictionary = category_entry
		for row in entry["rows"]:
			var row_data: Dictionary = row
			if row_data.has("mode"):
				continue
			if row_data.has("setting"):
				continue
			var action: String = row_data["action"]
			assert_true(InputMap.has_action(action), "no invented actions: %s" % action)


func test_every_mapped_action_has_a_registered_row_with_clean_metadata() -> void:
	for category_entry in KeyInputSettings.BINDING_MAP:
		var entry: Dictionary = category_entry
		for row in entry["rows"]:
			var row_data: Dictionary = row
			if row_data.has("mode"):
				continue
			if row_data.has("setting"):
				continue
			var action: String = row_data["action"]
			if not InputMap.has_action(action):
				continue
			assert_true(Settings.has_setting(action), "row registered for %s" % action)
			assert_eq(Settings.get_setting_group(action), MAP_GROUP)
			var display_name: Variant = Settings.get_setting_meta(action, "display_name")
			assert_true(display_name is String and not str(display_name).is_empty(),
					"display name set for %s" % action)
			assert_false(str(display_name).contains("|"), "no prefix leak in %s" % action)
			assert_eq(str(Settings.get_setting_meta(action, "key_category")), str(entry["category"]))
			assert_true(Settings.get_setting(action) is PackedStringArray,
					"row value populated for %s" % action)


func test_mode_rows_regroup_into_the_key_group() -> void:
	for mode_name in [MODE_CROUCH, MODE_ADS]:
		assert_true(Settings.has_setting(mode_name), "%s registered" % mode_name)
		assert_eq(Settings.get_setting_group(mode_name), MAP_GROUP)
		assert_eq(Settings.get_setting_type(mode_name), SettingsClass.SettingType.BOOL)


func test_crouch_mode_renders_right_after_the_crouch_row() -> void:
	var names: Array = Settings.get_settings_list()
	var crouch_index: int = names.find("player|crouch")
	var mode_index: int = names.find(MODE_CROUCH)
	assert_true(crouch_index != -1 and mode_index == crouch_index + 1,
			"hold/toggle option adjacent to its binding family")


func test_saved_keybinding_dict_round_trips_the_mapped_actions() -> void:
	# An existing user keybinding.dict ({"action": ["key(W)", ...]}) loads and
	# applies before rows register: the snapshot must cover every mapped action.
	assert_true(KeybindingManager.keys_default.has("player|crouch"), "crouch in snapshot")
	for category_entry in KeyInputSettings.BINDING_MAP:
		var entry: Dictionary = category_entry
		for row in entry["rows"]:
			var row_data: Dictionary = row
			if row_data.has("mode"):
				continue
			if row_data.has("setting"):
				continue
			var action: String = row_data["action"]
			if not InputMap.has_action(action):
				continue
			# Unbound escape-hatch actions (kick, interact, ads, issue #606)
			# carry no default events, so a pre-existing user keybinding.dict
			# missing them leaves them correctly unbound: no snapshot needed.
			if KeyInputSettings._project_default_events(action).is_empty():
				continue
			assert_true(KeybindingManager.keys_default.has(action),
					"snapshot covers %s" % action)


func test_display_names_carry_no_binding_hints() -> void:
	# The left column is the role only (owner ruling): mouse button and
	# wheel names must not ride along inside the display name.
	for category_entry in KeyInputSettings.BINDING_MAP:
		var entry: Dictionary = category_entry
		for row in entry["rows"]:
			var row_data: Dictionary = row
			if not row_data.has("action"):
				continue
			var display_name: String = row_data.get("name", "")
			if display_name.is_empty():
				continue
			assert_false(display_name.contains("Mouse"), "no mouse hint in %s" % display_name)
			assert_false(display_name.contains("LMB"), "no LMB hint in %s" % display_name)
			assert_false(display_name.contains("RMB"), "no RMB hint in %s" % display_name)
			assert_false(display_name.contains("MMB"), "no MMB hint in %s" % display_name)
			assert_false(display_name.contains("Wheel"), "no wheel hint in %s" % display_name)


func _key_event(keycode : Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func test_apply_binding_accepts_mouse_buttons_and_appends_to_the_second_slot() -> void:
	var interact_before: Array = InputMap.action_get_events("player|interact").duplicate()
	var throw_before: Array = InputMap.action_get_events("playerhand|mainhand_throw").duplicate()
	assert_false(throw_before.is_empty(), "precondition: mainhand_throw bound")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_MIDDLE
	KeyInputSettings.apply_binding("player|interact", event)
	assert_eq(KeyInputSettings.get_last_conflict_notice(),
			"Mouse Middle Button was taken from Main Hand Throw / Drop")
	# Rebinds and conflict clears replace keyboard/mouse events only: the
	# mainhand throw joypad default (Y button) survives the MMB conflict.
	var throw_events: Array = InputMap.action_get_events("playerhand|mainhand_throw")
	assert_eq(throw_events.size(), 1)
	var throw_pad := throw_events[0] as InputEventJoypadButton
	assert_true(throw_pad != null and throw_pad.button_index == JOY_BUTTON_Y,
			"conflict clear keeps the joypad default")
	# Two bindings: the interact joypad default plus the appended MMB capture.
	assert_eq(InputMap.action_get_events("player|interact").size(), 3,
			"capture appends to the second slot next to RMB and the joypad default")
	_restore_events("player|interact", interact_before)
	_restore_events("playerhand|mainhand_throw", throw_before)


func test_two_held_bindings_make_the_next_capture_replace_both() -> void:
	var crouch_before: Array = InputMap.action_get_events("player|crouch").duplicate()
	KeyInputSettings.apply_binding("player|crouch", _key_event(KEY_K))
	var crouch_events: Array = InputMap.action_get_events("player|crouch")
	# Crouch held two keyboard defaults (Ctrl, C), so the capture cleared
	# both and stored K alone; the L3 joypad default stays because gamepad
	# bindings are not rebindable yet.
	assert_eq(crouch_events.size(), 2, "rebind replaces keyboard/mouse, keeps joypad")
	var has_k := false
	var has_l3 := false
	for crouch_event in crouch_events:
		var key := crouch_event as InputEventKey
		if key and key.keycode == KEY_K:
			has_k = true
		var pad := crouch_event as InputEventJoypadButton
		if pad and pad.button_index == JOY_BUTTON_LEFT_STICK:
			has_l3 = true
	assert_true(has_k and has_l3, "keyboard replaced by K, L3 kept")
	_restore_events("player|crouch", crouch_before)


func test_reset_restores_ctrl_crouch_and_clears_conflicting_user_bindings() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	KeyInputSettings.apply_binding("player|crouch", event)
	KeyInputSettings.apply_binding("player|reload", _key_event(KEY_H))
	KeyInputSettings.reset_actions()
	var crouch_events: Array = InputMap.action_get_events("player|crouch")
	# Reset restores every action's full project default set: Ctrl, C and
	# the L3 joypad event for crouch.
	assert_eq(crouch_events.size(), 3, "reset restores the full crouch default")
	var has_ctrl := false
	var has_c := false
	var has_l3 := false
	for crouch_event in crouch_events:
		var key := crouch_event as InputEventKey
		if key:
			if key.keycode == KEY_CTRL:
				has_ctrl = true
			if key.keycode == KEY_C:
				has_c = true
		var pad := crouch_event as InputEventJoypadButton
		if pad and pad.button_index == JOY_BUTTON_LEFT_STICK:
			has_l3 = true
	assert_true(has_ctrl and has_c, "reset keeps Ctrl-crouch from project.godot")
	assert_true(has_l3, "reset restores the crouch joypad default")
	# Reset restores reload to its full default set: keyboard R and the L2
	# trigger joypad default, discarding the temporary H binding.
	var reload_events: Array = InputMap.action_get_events("player|reload")
	assert_eq(reload_events.size(), 2, "conflicting user binding cleared on reset")
	var has_r := false
	var has_l2 := false
	for reload_event in reload_events:
		var key := reload_event as InputEventKey
		if key and key.keycode == KEY_R:
			has_r = true
		var trigger := reload_event as InputEventJoypadMotion
		if trigger and trigger.axis == JOY_AXIS_TRIGGER_LEFT:
			has_l2 = true
	assert_true(has_r, "reload keeps its keyboard default")
	assert_true(has_l2, "reload keeps its trigger joypad default")


func _restore_events(action : String, events : Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		var restored := event as InputEvent
		if restored:
			InputMap.action_add_event(action, restored)
	KeybindingManager.save_keys()
