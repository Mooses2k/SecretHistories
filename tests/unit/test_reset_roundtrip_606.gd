extends GutTest

## Pins the reset-to-defaults contract (#606 owner playtest): reset repairs
## a corrupted user setup straight from project.godot, turns the left-hand
## mouse flag off, and the saved dict reboots back into exactly the project
## defaults (keyboard/mouse) with joypad defaults intact.

const OWNER_CORRUPTED_DICT := '{
"hotbar_10": ["key(0)"],
"interact": ["key(S)"],
"itm|holster_weapons": ["key(H)"],
"itm|next_hotbar_item": ["mouse(5)", "?"],
"itm|previous_hotbar_item": ["mouse(4)", "?"],
"movement|move_down": ["?"],
"movement|move_left": ["key(A)", "?"],
"movement|move_right": ["key(D)", "?"],
"movement|move_up": ["key(W)", "?"],
"player|crouch": ["key(Ctrl)", "key(C)", "?"],
"player|interact": ["?"],
"player|reload": ["key(R)", "?"],
"player|sprint": ["key(Shift)", "?"],
"playerhand|mainhand_throw": ["mouse(3)", "?"],
"playerhand|mainhand_use": ["mouse(1)", "?", "?"],
"playerhand|offhand_throw": ["key(T)", "key(G)"],
"playerhand|offhand_use": ["?"]
}'


func after_each() -> void:
	KeyInputSettings.reset_actions()


func _action_ids(action : String) -> PackedStringArray:
	var ids := PackedStringArray()
	for event in InputMap.action_get_events(action):
		ids.append(KeyInputSettings._event_binding_id(event))
	return ids


func test_reset_repairs_the_corrupted_owner_setup() -> void:
	var corrupted: Variant = JSON.parse_string(OWNER_CORRUPTED_DICT)
	assert_true(corrupted is Dictionary, "precondition: corrupted dict parses")
	KeybindingManager.setup_keys(corrupted)
	# The corruption: S stolen from Move Back, RMB stolen from Interact,
	# Alt stolen from Offhand Use, all three left empty.
	assert_true(_action_ids("movement|move_down").is_empty(), "precondition: move back empty")
	assert_true(_action_ids("player|interact").is_empty(), "precondition: interact empty")
	assert_true(_action_ids("playerhand|offhand_use").is_empty(),
			"precondition: offhand use empty")

	KeyInputSettings.reset_actions()

	assert_true(_action_ids("movement|move_down").has("k83_0_0_0_0"),
			"S back on Move Back")
	assert_true(_action_ids("player|interact").has("m2"), "RMB back on Interact")
	assert_true(_action_ids("playerhand|offhand_use").has("k4194328_0_0_0_0"),
			"Alt back on Offhand Use")
	assert_true(_action_ids("kick").is_empty(), "additive kick row unbound again")
	assert_true(_action_ids("interact").is_empty(), "additive interact row unbound again")
	assert_true(_action_ids("ads").is_empty(), "additive ads row unbound again")


func test_reboot_round_trip_lands_on_project_defaults() -> void:
	# A realistic user state: a custom rebind plus default everything else,
	# saved to the dict, then a reboot: fresh project InputMap, dict applied
	# through setup_keys, joypad defaults merged, defaults reconciled.
	KeyInputSettings.apply_binding("player|crouch", _key_event(KEY_K))
	KeybindingManager.save_keys()
	var saved_text: String = FileAccess.get_file_as_string(KeybindingManager.file_name)
	var saved: Variant = str_to_var(saved_text)
	assert_true(saved is Dictionary, "precondition: saved dict parses")

	_reboot_from(saved)

	# The user rebind survives the reboot, exactly once.
	var crouch_ids := _action_ids("player|crouch")
	var k_count := 0
	for id in crouch_ids:
		if id.begins_with("k75_"):
			k_count += 1
	assert_eq(k_count, 1, "the K rebind survives the reboot without duplicating")
	# The rest of the map lands back on the project defaults. debug_* rows
	# of a legacy modifier-less dict stay degraded until the reset below.
	assert_true(_live_matches_project_defaults(
			["player|crouch", "debug_level_up", "debug_give_item"]),
			"reboot state equals project defaults outside the rebind")


func test_reset_then_reboot_is_exact_everywhere() -> void:
	# Reset repairs the whole map and its dict: after reset plus reboot the
	# live InputMap matches every project default exactly, debug rows
	# included (reset rewrites the dict with full modifier strings).
	KeyInputSettings.reset_actions()
	var saved_text: String = FileAccess.get_file_as_string(KeybindingManager.file_name)
	var saved: Variant = str_to_var(saved_text)
	assert_true(saved is Dictionary, "precondition: reset dict parses")
	_reboot_from(saved)
	assert_true(_live_matches_project_defaults([]),
			"after reset and reboot every default matches exactly")


func test_saved_dict_carries_no_joypad_question_marks() -> void:
	KeyInputSettings.reset_actions()
	var dict: Dictionary = KeybindingManager.gen_dict_from_input_map()
	for action in dict.keys():
		for event_str in dict[action]:
			assert_ne(str(event_str), "?",
					"no unparseable joypad row in %s" % str(action))


func _key_event(keycode : Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func _reboot_from(saved_dict : Dictionary) -> void:
	for _action in InputMap.get_actions():
		var action := String(_action)
		if action.begins_with("ui_"):
			continue
		InputMap.action_erase_events(action)
	KeybindingManager.setup_keys(saved_dict)
	KeybindingManager._merge_missing_joypad_defaults()
	KeybindingManager._reconcile_default_events()


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
