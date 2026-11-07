extends Node

## Declarative keybinding settings (issues #307 and #606).
## One const map drives registration, display metadata, capture application,
## persistence and reset for every bindable action. Rows exist only for
## actions that live in InputMap, so no invented actions reach the menu, and
## actions stay rebindable and open for adventure authors.

const GROUP_NAME : String = "Input Key Settings"

## Ordered per the wiki Interface 5.2 control system: few keys overloaded
## with nuance, shown as coherent families, with separate keys still
## bindable. "action" rows bind an InputMap action; "mode" rows reposition an
## existing bool setting (tap/hold) next to its binding family. An optional
## "name" overrides the derived display label.
const BINDING_MAP : Array = [
	{
		"category": "Footwork and Movement",
		"rows": [
			{"action": "movement|move_up", "name": "Move Forward"},
			{"action": "movement|move_left", "name": "Move Left"},
			{"action": "movement|move_down", "name": "Move Back"},
			{"action": "movement|move_right", "name": "Move Right"},
			{"action": "player|sprint", "name": "Sprint / Dodge / Kick (Shift)"},
			# The kick, interact and ads escape-hatch actions ship unbound:
			# their contextual integrated paths stay the default behavior
			# (issue #606), and binding a key adds a dedicated trigger.
			{"action": "kick", "name": "Kick (separate key)"},
			{"action": "player|crouch", "name": "Crouch"},
			{"mode": "Hold Crouch"},
			{"action": "player|jump", "name": "Jump / Mantle / Stand"},
		],
	},
	{
		"category": "Player Actions",
		"rows": [
			{"action": "player|interact", "name": "Interact / ADS / Drag (RMB)"},
			{"mode": "Hold ADS (Aim Down Sights)"},
			{"action": "interact", "name": "Interact (separate key)"},
			{"action": "ads", "name": "ADS (separate key)"},
		],
	},
	{
		"category": "Hands and Inventory",
		"rows": [
			{"action": "playerhand|mainhand_use", "name": "Main Hand Use (LMB)"},
			{"action": "playerhand|mainhand_throw", "name": "Main Hand Throw / Drop (MMB)"},
			{"action": "playerhand|offhand_use", "name": "Offhand Use"},
			{"action": "playerhand|offhand_throw", "name": "Offhand Throw / Place"},
			{"action": "playerhand|cycle_offhand_slot", "name": "Cycle Offhand Slot"},
			{"action": "itm|next_hotbar_item", "name": "Next Hotbar Item (Wheel Down)"},
			{"action": "itm|previous_hotbar_item", "name": "Previous Hotbar Item (Wheel Up)"},
			{"action": "itm|holster_weapons", "name": "Holster Weapons"},
			{"action": "hotbar_1", "name": "Hotbar 1"},
			{"action": "hotbar_2", "name": "Hotbar 2"},
			{"action": "hotbar_3", "name": "Hotbar 3"},
			{"action": "hotbar_4", "name": "Hotbar 4"},
			{"action": "hotbar_5", "name": "Hotbar 5"},
			{"action": "hotbar_6", "name": "Hotbar 6"},
			{"action": "hotbar_7", "name": "Hotbar 7"},
			{"action": "hotbar_8", "name": "Hotbar 8"},
			{"action": "hotbar_9", "name": "Hotbar 9"},
			{"action": "hotbar_10", "name": "Hotbar 10"},
		],
	},
	{
		"category": "Firearms and Reload",
		"rows": [
			{"action": "player|reload", "name": "Reload"},
		],
	},
	{
		"category": "Interface and Misc",
		"rows": [
			{"action": "ablty|nightvision_darksight", "name": "Nightvision / Darksight"},
			{"action": "ablty|binocs_spyglass", "name": "Binoculars / Spyglass"},
			{"action": "ablty|zap_spell", "name": "Zap Spell"},
			{"action": "misc|map_menu", "name": "Map"},
			{"action": "misc|journal", "name": "Journal"},
			{"action": "misc|inventory_menu", "name": "Inventory Menu"},
			{"action": "misc|help_info", "name": "Help"},
			{"action": "misc|fullscreen", "name": "Toggle Fullscreen"},
			{"action": "misc|change_screen_filter", "name": "Change Screen Filter"},
			{"action": "com|communication_go", "name": "Command: Follow Me"},
			{"action": "com|communication_stop", "name": "Command: Stop"},
			{"action": "com|communication_text", "name": "Text Chat"},
		],
	},
]

var _mapped_actions : Dictionary = {}

## Set by the last apply_binding call: "" when the binding caused no
## conflict, otherwise a notice naming the action whose key was cleared.
var last_conflict_notice : String = ""


func _ready() -> void:
	_register_rows()
	Settings.setting_changed.connect(on_setting_changed)


func get_last_conflict_notice() -> String:
	return last_conflict_notice


## Register every mapped row in map order. Dictionary insertion order is the
## settings list order, so the map order is the render order, with mode rows
## landing exactly where the map places them.
func _register_rows() -> void:
	for category_entry in BINDING_MAP:
		var entry: Dictionary = category_entry
		var category: String = entry["category"]
		var rows: Array = entry["rows"]
		for row in rows:
			var row_data: Dictionary = row
			if row_data.has("mode"):
				_register_mode_row(str(row_data["mode"]), category)
				continue
			var action: String = row_data["action"]
			if not InputMap.has_action(action):
				push_warning("Keybinding row skipped, action missing from InputMap: " + action)
				continue
			var display_name: String = row_data.get("name", "")
			if display_name.is_empty():
				display_name = _default_display_name(action)
			_register_action_row(action, display_name, category)


func _register_action_row(action : String, display_name : String, category : String) -> void:
	_mapped_actions[action] = true
	if not Settings.has_setting(action):
		Settings.add_string_setting(action, _action_value_strings(action))
	# The stored display strings are a render cache of the live InputMap;
	# rebuild them on every boot so rows never show stale or emptied values.
	Settings._settings[action][Settings._FIELD_VALUE] = _action_value_strings(action)
	Settings.set_setting_group(action, GROUP_NAME)
	Settings.set_setting_meta(action, "display_name", display_name)
	Settings.set_setting_meta(action, "key_category", category)


## Move an existing bool setting (registered by GameSettings into
## "Game Settings") into this group and reinsert it right after the rows
## registered just before it, so it renders adjacent to its family.
func _register_mode_row(setting_name : String, category : String) -> void:
	if not Settings.has_setting(setting_name):
		push_warning("Keybinding mode setting missing from Settings: " + setting_name)
		return
	var entry: Dictionary = Settings._settings[setting_name]
	Settings._settings.erase(setting_name)
	Settings._settings[setting_name] = entry
	Settings.set_setting_group(setting_name, GROUP_NAME)
	Settings.set_setting_meta(setting_name, "key_category", category)


func on_setting_changed(setting_name, _old_value, new_value) -> void:
	if not _mapped_actions.has(setting_name):
		return
	if new_value is InputEvent:
		apply_binding(setting_name, new_value)
	elif new_value == null:
		_apply_cleared_action(setting_name)


## One apply path for every captured binding: clear conflicting events on
## other mapped actions (the new binding wins, with a notice), replace the
## action's keyboard and mouse events with the new event (its joypad events
## stay, gamepad defaults are not rebindable yet), then persist row and dict.
func apply_binding(action : String, event : InputEvent) -> void:
	last_conflict_notice = _clear_conflicts(action, event)
	_clear_bindable_events(action)
	InputMap.action_add_event(action, event)
	_persist_row(action, null)


## Remove only the keyboard and mouse events of one action, keeping joypad
## events. Keyboard/mouse rebinds and clears never touch gamepad bindings.
func _clear_bindable_events(action : String) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			InputMap.action_erase_event(action, event)


## Conflict policy: the action being bound keeps the key, any other mapped
## action loses that single event and keeps its remaining events, and the
## returned notice names what was cleared. Escape and ui_cancel stay shared
## by design and are untouched: neither is a mapped row.
func _clear_conflicts(action : String, event : InputEvent) -> String:
	var binding_id := _event_binding_id(event)
	if binding_id.is_empty():
		return ""
	var notice := ""
	for other_action in _mapped_actions.keys():
		var other_name: String = other_action
		if other_name == action or not InputMap.has_action(other_name):
			continue
		var cleared := false
		for other_event in InputMap.action_get_events(other_name):
			if _event_binding_id(other_event) == binding_id:
				InputMap.action_erase_event(other_name, other_event)
				cleared = true
		if cleared:
			_persist_row(other_name, null)
			if notice.is_empty():
				notice = "%s was taken from %s" % [
					_event_display_label(event),
					str(Settings.get_setting_meta(other_name, "display_name")),
				]
	return notice


## Comparable identity of a bindable event: keyboard keys by their keycode
## (physical preferred), mouse buttons by button index, joypad buttons by
## button index and joypad axes by axis, device and value sign. Joypad events
## need a non-empty id so reset conflict clearing never treats them as
## erasable unknowns. Unbindable event types return "" and never conflict.
func _event_binding_id(event : InputEvent) -> String:
	if event is InputEventKey:
		var keycode: int = event.keycode
		if keycode == 0:
			keycode = event.physical_keycode
		if keycode != 0:
			return "k%d" % keycode
	if event is InputEventMouseButton:
		return "m%d" % event.button_index
	if event is InputEventJoypadButton:
		return "jb%d_%d" % [event.button_index, event.device]
	if event is InputEventJoypadMotion:
		var value_sign := 1 if event.axis_value >= 0.0 else -1
		return "jm%d_%d_%d" % [event.axis, event.device, value_sign]
	return ""


func _apply_cleared_action(action : String) -> void:
	_clear_bindable_events(action)
	_persist_row(action, null)


## Update the row's display cache, tell the editors through keys_saved, and
## persist the whole InputMap to the keybinding dict.
func _persist_row(action : String, old_value) -> void:
	if not Settings._settings.has(action):
		return
	var value_strings := _action_value_strings(action)
	Settings._settings[action][Settings._FIELD_VALUE] = value_strings
	Settings.emit_signal("keys_saved", action, old_value, value_strings)
	KeybindingManager.save_keys()


## One reset path: restore every mapped action's default events straight
## from project.godot (no hardcoded table, no string round-trip), then clear
## any user binding that now conflicts with a restored default.
func reset_actions() -> void:
	for action in _mapped_actions.keys():
		var action_name: String = action
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		for event in _project_default_events(action_name):
			InputMap.action_add_event(action_name, event)
		_persist_row(action_name, null)
	_clear_conflicts_with_defaults()
	KeybindingManager.save_keys()


func _project_default_events(action : String) -> Array:
	if not ProjectSettings.has_setting("input/" + action):
		return []
	var config: Variant = ProjectSettings.get_setting("input/" + action)
	if config is Dictionary:
		var events: Variant = config.get("events")
		if events is Array:
			return events
	return []


## Project defaults are conflict-free among themselves, so any remaining
## conflict is a user binding colliding with a restored default: defaults
## win, the colliding event is cleared from the other mapped action.
func _clear_conflicts_with_defaults() -> void:
	for action in _mapped_actions.keys():
		var action_name: String = action
		if not InputMap.has_action(action_name):
			continue
		var default_ids := PackedStringArray()
		for event in _project_default_events(action_name):
			default_ids.append(_event_binding_id(event))
		for other_action in _mapped_actions.keys():
			var other_name: String = other_action
			if other_name == action_name or not InputMap.has_action(other_name):
				continue
			var cleared := false
			for other_event in InputMap.action_get_events(other_name):
				if default_ids.has(_event_binding_id(other_event)):
					InputMap.action_erase_event(other_name, other_event)
					cleared = true
			if cleared:
				_persist_row(other_name, null)


## Display strings for one action's current InputMap events, in order.
func _action_value_strings(action : String) -> PackedStringArray:
	var value_strings := PackedStringArray()
	for event in InputMap.action_get_events(action):
		var label := _event_display_label(event)
		if not label.is_empty():
			value_strings.append(label)
	return value_strings


func _event_display_label(event : InputEvent) -> String:
	if event is InputEventKey:
		var keycode: int = event.keycode
		if keycode == 0:
			keycode = event.physical_keycode
		if keycode != 0:
			return str(OS.get_keycode_string(keycode as Key))
	if event is InputEventMouseButton:
		return _mouse_button_label(event.button_index)
	return ""


func _mouse_button_label(button_index : int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return "Mouse Left Button"
		MOUSE_BUTTON_RIGHT:
			return "Mouse Right Button"
		MOUSE_BUTTON_MIDDLE:
			return "Mouse Middle Button"
		MOUSE_BUTTON_WHEEL_UP:
			return "Mouse Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Mouse Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT:
			return "Mouse Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT:
			return "Mouse Wheel Right"
		_:
			return "Mouse Button %d" % button_index


func _default_display_name(action : String) -> String:
	if action.contains("|"):
		return action.get_slice("|", 1).capitalize()
	return action.capitalize()
