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
## existing bool setting (tap/hold) next to its binding family; "setting"
## rows register a new non-action setting (overload composition, 5.2.1).
## An optional "name" overrides the derived display label.

## Overload composition settings (wiki Interface 5.2.1): which behaviors the
## Shift family composes. The wiki preset bundles, minus the behaviors that
## do not exist in dev4 yet (butt-strike on ADS, prone kick, grapple throw,
## dodge on Space): Sprint/kick/dodge (default), Sprint/kick, Sprint/dodge,
## Kick. Individual bools stay editable as per-behavior overrides.
const SETTING_OVERLOAD_PRESET : String = "Shift Overload Preset"
const SETTING_SHIFT_KICK : String = "Kick on Shift (tap)"
const SETTING_SHIFT_DODGE : String = "Dodge on Shift + direction"
const SETTING_SHIFT_SPRINT : String = "Sprint on Shift (hold)"
const SETTING_LEFT_HAND : String = "Left-hand Mouse"

## Preset bundles: each entry is [kick, dodge, sprint]. Kick on Shift tap is
## the footwork overload's anchor behavior and stays on in every preset.
const OVERLOAD_PRESETS : Array = [
	[true, true, true],   # Sprint / kick / dodge (default)
	[true, false, true],  # Sprint / kick
	[true, true, false],  # Sprint / dodge
	[true, false, false], # Kick
]

const OVERLOAD_PRESET_VARIANTS : PackedStringArray = [
	"Sprint / kick / dodge",
	"Sprint / kick",
	"Sprint / dodge",
	"Kick",
]

## Left-hand mouse swap (wiki Interface 5.2: "have left-hand mouse bind as
## well"): these two actions exchange their keyboard/mouse events while the
## setting is on. Joypad events never move.
const LEFT_HAND_ACTIONS : Array = ["playerhand|mainhand_use", "player|interact"]

const BINDING_MAP : Array = [
	{
		"category": "Footwork and Movement",
		"rows": [
			{"action": "movement|move_up", "name": "Move Forward"},
			{"action": "movement|move_left", "name": "Move Left"},
			{"action": "movement|move_down", "name": "Move Back"},
			{"action": "movement|move_right", "name": "Move Right"},
			{"action": "player|sprint", "name": "Sprint / Dodge / Kick (Shift)"},
			{"setting": SETTING_OVERLOAD_PRESET},
			{"setting": SETTING_SHIFT_KICK},
			{"setting": SETTING_SHIFT_DODGE},
			{"setting": SETTING_SHIFT_SPRINT},
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
			{"setting": SETTING_LEFT_HAND},
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


## Read gate for the contextual Shift-overload behaviors (wiki 5.2.1).
## Defaults to enabled when the setting is not registered, so the humanoid
## seam never blocks the shipped behavior by accident.
func shift_kick_enabled() -> bool:
	return _overload_enabled(SETTING_SHIFT_KICK)


func shift_dodge_enabled() -> bool:
	return _overload_enabled(SETTING_SHIFT_DODGE)


func shift_sprint_enabled() -> bool:
	return _overload_enabled(SETTING_SHIFT_SPRINT)


func _overload_enabled(setting_name : String) -> bool:
	if not Settings.has_setting(setting_name):
		return true
	return bool(Settings.get_setting(setting_name))


func set_shift_kick(enabled : bool) -> void:
	Settings.set_setting(SETTING_SHIFT_KICK, enabled)


func set_shift_dodge(enabled : bool) -> void:
	Settings.set_setting(SETTING_SHIFT_DODGE, enabled)


func set_shift_sprint(enabled : bool) -> void:
	Settings.set_setting(SETTING_SHIFT_SPRINT, enabled)


func get_left_hand_mouse() -> bool:
	if not Settings.has_setting(SETTING_LEFT_HAND):
		return false
	return bool(Settings.get_setting(SETTING_LEFT_HAND))


func set_left_hand_mouse(enabled : bool) -> void:
	Settings.set_setting(SETTING_LEFT_HAND, enabled)


## Left-hand mouse (wiki Interface 5.2): exchange the keyboard and mouse
## events of mainhand use and interact, so LMB does the RMB job and vice
## versa. Idempotent: only swaps when the current map is in the expected
## state, so a boot against an already swapped keybinding.dict never swaps
## twice. Joypad events never move. Returns true when events moved.
func _apply_left_hand_swap(enabled : bool) -> bool:
	var mainhand_action : String = LEFT_HAND_ACTIONS[0]
	var interact_action : String = LEFT_HAND_ACTIONS[1]
	if not InputMap.has_action(mainhand_action) or not InputMap.has_action(interact_action):
		return false
	if not _left_hand_can_swap(enabled, mainhand_action, interact_action):
		return false
	var mainhand_events := _bindable_events(mainhand_action)
	var interact_events := _bindable_events(interact_action)
	_clear_bindable_events(mainhand_action)
	_clear_bindable_events(interact_action)
	for event in interact_events:
		InputMap.action_add_event(mainhand_action, event)
	for event in mainhand_events:
		InputMap.action_add_event(interact_action, event)
	_persist_row(mainhand_action, null)
	_persist_row(interact_action, null)
	KeybindingManager.save_keys()
	return true


## The swap is safe only when the two actions currently hold the roles the
## toggle expects: enabling requires the right-handed layout, disabling
## requires the swapped one. Custom rebinds that blur the roles refuse the
## swap instead of silently reshuffling the user's keys.
func _left_hand_can_swap(enabled : bool, mainhand_action : String, interact_action : String) -> bool:
	var mainhand_has_lmb := false
	var mainhand_has_rmb := false
	var interact_has_lmb := false
	var interact_has_rmb := false
	for event in _bindable_events(mainhand_action):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				mainhand_has_lmb = true
			if event.button_index == MOUSE_BUTTON_RIGHT:
				mainhand_has_rmb = true
	for event in _bindable_events(interact_action):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				interact_has_lmb = true
			if event.button_index == MOUSE_BUTTON_RIGHT:
				interact_has_rmb = true
	if enabled:
		return mainhand_has_lmb and interact_has_rmb
	return mainhand_has_rmb and interact_has_lmb


## Keyboard and mouse events of one action, kept in order for the exchange.
func _bindable_events(action : String) -> Array:
	var events := Array()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			events.append(event)
	return events


func get_overload_preset() -> int:
	if not Settings.has_setting(SETTING_OVERLOAD_PRESET):
		return 0
	return int(Settings.get_setting(SETTING_OVERLOAD_PRESET))


func set_overload_preset(index : int) -> void:
	Settings.set_setting(SETTING_OVERLOAD_PRESET, index)


## Write the per-behavior bools for one wiki preset bundle. The bools stay
## individually editable afterwards.
func apply_overload_preset(index : int) -> void:
	if index < 0 or index >= OVERLOAD_PRESETS.size():
		return
	var preset: Array = OVERLOAD_PRESETS[index]
	set_shift_kick(bool(preset[0]))
	set_shift_dodge(bool(preset[1]))
	set_shift_sprint(bool(preset[2]))


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
			if row_data.has("setting"):
				_register_setting_row(str(row_data["setting"]), category)
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


## Register a new non-action setting (overload composition, left-hand mouse)
## in this group right where the map places it.
func _register_setting_row(setting_name : String, category : String) -> void:
	if Settings.has_setting(setting_name):
		return
	match setting_name:
		SETTING_OVERLOAD_PRESET:
			Settings.add_enum_setting(SETTING_OVERLOAD_PRESET,
					OVERLOAD_PRESET_VARIANTS, 0)
		SETTING_SHIFT_KICK, SETTING_SHIFT_DODGE, SETTING_SHIFT_SPRINT:
			Settings.add_bool_setting(setting_name, true)
		SETTING_LEFT_HAND:
			Settings.add_bool_setting(SETTING_LEFT_HAND, false)
		_:
			push_warning("Unknown setting row skipped: " + setting_name)
			return
	Settings.set_setting_group(setting_name, GROUP_NAME)
	Settings.set_setting_meta(setting_name, "key_category", category)


func on_setting_changed(setting_name, _old_value, new_value) -> void:
	match setting_name:
		SETTING_OVERLOAD_PRESET:
			if new_value is int:
				apply_overload_preset(new_value)
				SettingsConfig.save_settings()
			return
		SETTING_SHIFT_KICK, SETTING_SHIFT_DODGE, SETTING_SHIFT_SPRINT:
			if new_value is bool:
				SettingsConfig.save_settings()
			return
		SETTING_LEFT_HAND:
			if new_value is bool:
				_apply_left_hand_swap(new_value)
				SettingsConfig.save_settings()
			return
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
	# Reset restores the right-handed project defaults, so the left-hand
	# swap must be re-applied when the setting is on.
	if get_left_hand_mouse():
		_apply_left_hand_swap(true)
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
