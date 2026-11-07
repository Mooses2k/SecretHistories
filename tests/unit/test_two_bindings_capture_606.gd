extends GutTest

## Pins the two-bindings-per-action capture contract (#606 owner playtest):
## a capture appends while fewer than two keyboard/mouse events are held,
## a third capture clears both and stores the new one with a notice, and
## modifier combos and lone modifier keys round-trip through the dict.

const KICK := "kick"
const OFFHAND_THROW := "playerhand|offhand_throw"


func before_each() -> void:
	InputMap.action_erase_events(KICK)


func after_each() -> void:
	InputMap.action_erase_events(KICK)
	KeybindingManager.save_keys()


## Rebuild one action's events exactly from project.godot so the test does
## not depend on earlier tests' live-map pollution.
func _restore_project_defaults(action : String) -> void:
	InputMap.action_erase_events(action)
	for event in KeyInputSettings._project_default_events(action):
		InputMap.action_add_event(action, event)


func _key_event(keycode : Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func _key_ids(action : String) -> PackedStringArray:
	var ids := PackedStringArray()
	for event in InputMap.action_get_events(action):
		ids.append(KeyInputSettings._event_binding_id(event))
	return ids


func test_capture_appends_up_to_two_bindings() -> void:
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_P))
	var ids_one := _key_ids(KICK)
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_O))
	var ids_two := _key_ids(KICK)
	assert_eq(ids_two.size(), 2, "two captures are held as two bindings")
	assert_true(ids_two.has(ids_one[0]), "the first binding survives the second capture")
	assert_true(ids_two.has(KeyInputSettings._event_binding_id(_key_event(KEY_O))),
			"the second capture joined the action")


func test_third_capture_clears_both_and_explains_it() -> void:
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_P))
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_O))
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_U))
	assert_eq(_key_ids(KICK).size(), 1, "the third capture clears both slots")
	assert_true(_key_ids(KICK).has(KeyInputSettings._event_binding_id(_key_event(KEY_U))),
			"the new binding is the only one left")
	assert_true(KeyInputSettings.get_last_conflict_notice().contains("two bindings"),
			"the notice explains the two-slot clear")


func test_rebinding_the_same_event_does_not_duplicate_it() -> void:
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_P))
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_O))
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_P))
	assert_eq(_key_ids(KICK).size(), 2, "same-binding capture updates instead of appending")
	assert_true(_key_ids(KICK).has(KeyInputSettings._event_binding_id(_key_event(KEY_O))),
			"the other slot survives")


func test_conflicts_clear_one_event_and_the_notice_names_the_row() -> void:
	_restore_project_defaults(OFFHAND_THROW)
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_T))
	assert_eq(KeyInputSettings.get_last_conflict_notice(),
			"T was taken from Offhand Throw / Place")
	var throw_events: Array = InputMap.action_get_events("playerhand|offhand_throw")
	var has_g := false
	var has_t := false
	for event in throw_events:
		var key := event as InputEventKey
		if key and key.keycode == KEY_G:
			has_g = true
		if key and key.keycode == KEY_T:
			has_t = true
	assert_true(has_g, "offhand throw keeps its other binding")
	assert_false(has_t, "the conflicting T moved off offhand throw")
	_restore_project_defaults(OFFHAND_THROW)
	KeybindingManager.save_keys()


func test_modifier_binding_ids_distinguish_combos() -> void:
	var plain_w := _key_event(KEY_W)
	var combo_w := _key_event(KEY_W)
	combo_w.alt_pressed = true
	assert_ne(KeyInputSettings._event_binding_id(plain_w),
			KeyInputSettings._event_binding_id(combo_w),
			"Alt+W and W are different bindings")


func test_modifier_combos_and_lone_modifiers_round_trip_through_the_dict() -> void:
	var combo := _key_event(KEY_W)
	combo.alt_pressed = true
	combo.ctrl_pressed = true
	var combo_text: String = KeybindingManager.event2str(combo)
	assert_eq(combo_text, "key(Alt+Ctrl+W)", "modifiers serialize in a stable order")
	var combo_back: InputEvent = KeybindingManager.str2event(combo_text)
	var back_key := combo_back as InputEventKey
	assert_true(back_key != null and back_key.keycode == KEY_W, "combo key survives")
	assert_true(back_key != null and back_key.alt_pressed and back_key.ctrl_pressed,
			"combo modifiers survive")

	var lone := _key_event(KEY_ALT)
	lone.alt_pressed = true
	var lone_text: String = KeybindingManager.event2str(lone)
	assert_eq(lone_text, "key(Alt)", "a lone modifier is its own binding, not a prefix")
	var lone_back := KeybindingManager.str2event(lone_text) as InputEventKey
	assert_true(lone_back != null and lone_back.keycode == KEY_ALT,
			"lone modifier key survives")
	assert_true(lone_back != null and lone_back.alt_pressed,
			"the lone modifier carries its own flag")

	assert_true(KeybindingManager.str2event("key(Gibberish)") == null,
			"unknown key names refuse to parse")



