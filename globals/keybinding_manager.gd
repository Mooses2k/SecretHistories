extends Node


var file_name = "%s://globals/settings/keybinding.dict" % ("user" if OS.has_feature("standalone") else "res")
var file_name_default = "%s://globals/settings/default_keys.dict" % ("user" if OS.has_feature("standalone") else "res")

var setting_key = false
var keys_default : Dictionary

## The dict rows setup_keys last applied. The joypad merge consults them:
## a row that already carries joypad strings owns that action's joypad
## state, so the migration must not resurrect defaults a user rebind or
## conflict clear removed.
var applied_key_dict : Dictionary = {}

enum EventType {
	KEY,
	KEY_PHYSICAL,
	MOUSE_BUTTON,
	JOY_BUTTON,
	JOY_AXIS,
}

var event_prefixes = [
	"key", # KEY
	"pkey", # KEY_PHYSICAL
	"mouse", # MOUSE_BUTTON
	"joyb", # JOY_BUTTON
	"joym", # JOY_AXIS
]

## Modifier tokens allowed in a key string, in the order event2str writes
## them: "key(Alt+Ctrl+W)". A lone modifier key ("key(Alt)") is its own
## binding, not a combo prefix.
const MODIFIER_TOKENS : PackedStringArray = ["Alt", "Shift", "Ctrl", "Meta"]

## Device field of a joypad binding that applies to every pad, matching the
## project.godot joypad defaults.
const GAMEPAD_DEVICE_ALL : int = -1


func _ready():
	load_keys()
# leftovers from tutorial version
#	get_child(0).visible = false
#	pause_mode = Node.PAUSE_MODE_PROCESS


func gen_dict_from_input_map() -> Dictionary:
	var actions = InputMap.get_actions()
	var result = Dictionary()
	for _action in actions:
		var action : String = _action as String
		# ignore built in ui actions
		if not action.begins_with("ui_"):
			result[action] = Array()
			for event in InputMap.action_get_events(action):
				var event_str := event2str(event)
				if not event_str.is_empty():
					result[action].push_back(event_str)
	return result


# We'll use this when the game loads
func load_keys():
	if(FileAccess.file_exists(file_name)):
		var file_str = FileAccess.get_file_as_string(file_name)
		var data = str_to_var(file_str)
		if(typeof(data) == TYPE_DICTIONARY):
			setup_keys(data)
		else:
			printerr("corrupted data!")
	else:
		#NoFile, so lets save the default keys now
		save_keys()
		save_default_keys()

	var file_str = FileAccess.get_file_as_string(file_name_default)
	var data = str_to_var(file_str)
	if(typeof(data) == TYPE_DICTIONARY):
		keys_default = data
	else:
		printerr("corrupted data!")

	# Stale-default migration: dev4 shipped the hotbar wheel actions reversed
	# (wheel up cycled to the next slot, wheel down to the previous, opposite
	# of 3.x). Saved keybinding files captured that old default, so a
	# project.godot swap alone never reaches existing installs. Detect that
	# exact stale pattern in the loaded map and swap it, then persist.
	if _migrate_reversed_wheel_defaults():
		keys_default = gen_dict_from_input_map()
		save_keys()
		save_default_keys()

	# Gamepad default migration (#268): a pre-existing keybinding.dict holds
	# only keyboard/mouse strings, so setup_keys erased the joypad defaults
	# the project file ships. Re-add any project joypad default the loaded
	# map lacks, then persist. Rows that already carry joypad strings are
	# skipped: they were saved by a build that persists gamepad bindings, so
	# they own that action's joypad state and user rebinds and conflict
	# clears must survive the reboot. Idempotent: once merged, no-ops.
	if _merge_missing_joypad_defaults():
		keys_default = gen_dict_from_input_map()
		save_keys()
		save_default_keys()

	# Reboot reconcile (#606): events re-parsed from the dict strings are
	# new objects that differ from the project.godot default events in
	# incidental fields (device, exact flags). Any live keyboard, mouse or
	# joypad event that IS a project default binding gets replaced by the
	# actual default event object, so default actions hold the exact project
	# events after every boot and drift cannot accumulate.
	_reconcile_default_events()


## Returns true when at least one project.godot joypad default was missing
## from the live InputMap and was re-added. Keyboard/mouse bindings (user
## customizations included) are never touched, and actions whose applied
## dict row already carries joypad strings are skipped entirely (see
## _dict_row_owns_joypad).
func _merge_missing_joypad_defaults() -> bool:
	var changed := false
	for _action in InputMap.get_actions():
		var action : String = _action as String
		if not ProjectSettings.has_setting("input/" + action):
			continue
		var config: Variant = ProjectSettings.get_setting("input/" + action)
		if not (config is Dictionary):
			continue
		var events: Variant = config.get("events")
		if not (events is Array):
			continue
		if _dict_row_owns_joypad(action):
			continue
		for event in events:
			var joypad_event := event as InputEvent
			if joypad_event == null:
				continue
			if not (joypad_event is InputEventJoypadButton
					or joypad_event is InputEventJoypadMotion):
				continue
			if not InputMap.action_has_event(action, joypad_event):
				InputMap.action_add_event(action, joypad_event)
				changed = true
	return changed


## Returns true when the live map held the stale reversed hotbar wheel
## default and it was swapped in place. Leaves anything else (already
## correct or user-customized) untouched.
func _migrate_reversed_wheel_defaults() -> bool:
	var next_up := false
	var prev_down := false
	for event in InputMap.action_get_events("itm|next_hotbar_item"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			next_up = true
	for event in InputMap.action_get_events("itm|previous_hotbar_item"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			prev_down = true
	if not (next_up and prev_down):
		return false
	InputMap.action_erase_events("itm|next_hotbar_item")
	var next_event := InputEventMouseButton.new()
	next_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event("itm|next_hotbar_item", next_event)
	InputMap.action_erase_events("itm|previous_hotbar_item")
	var prev_event := InputEventMouseButton.new()
	prev_event.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("itm|previous_hotbar_item", prev_event)
	return true


func setup_keys(key_dict : Dictionary):
	applied_key_dict = key_dict
	for action in key_dict.keys():
		var action_name : String = action as String
		InputMap.action_erase_events(action_name)
		for event_str in key_dict[action]:
			var event = str2event(event_str)
			if event:
				InputMap.action_add_event(action_name, event)
			else:
				# Legacy "?" rows held joypad events the string format never
				# carried; the joypad default merge restores them after this.
				push_warning("keybinding.dict: unparseable event '%s' on %s" % [
					str(event_str), action_name])


## True when the applied dict row for one action carries at least one
## joypad string. Legacy dicts (keyboard/mouse strings only) return false
## and still gain the project joypad defaults through the merge.
func _dict_row_owns_joypad(action : String) -> bool:
	if not applied_key_dict.has(action):
		return false
	var row: Variant = applied_key_dict[action]
	if not (row is Array):
		return false
	for event_str in row:
		var text := str(event_str)
		if text.begins_with(event_prefixes[EventType.JOY_BUTTON]) \
				or text.begins_with(event_prefixes[EventType.JOY_AXIS]):
			return true
	return false


## Replaces every live keyboard, mouse or joypad event that carries a
## project default binding with the actual project default event object, so
## identity matches exactly (device and flags included).
func _reconcile_default_events() -> void:
	for _action in InputMap.get_actions():
		var action : String = _action as String
		if not ProjectSettings.has_setting("input/" + action):
			continue
		var config: Variant = ProjectSettings.get_setting("input/" + action)
		if not (config is Dictionary):
			continue
		var events: Variant = config.get("events")
		if not (events is Array):
			continue
		for default_event in events:
			var default := default_event as InputEvent
			if default == null:
				continue
			if not (default is InputEventKey or default is InputEventMouseButton
					or default is InputEventJoypadButton
					or default is InputEventJoypadMotion):
				continue
			for live_event in InputMap.action_get_events(action):
				var live := live_event as InputEvent
				if live != null and live != default and _same_binding(live, default):
					InputMap.action_erase_event(action, live)
					InputMap.action_add_event(action, default)
					break


## Binding-level equality of two events: key (physical resolved) plus
## modifier flags for keys, button index for mouse buttons, button index
## and device for joypad buttons, axis, device and value sign for joypad
## axes. A modifier key's own flag is implied by the key itself and
## ignored, so a parsed lone "key(Alt)" matches the project default Alt
## event.
func _same_binding(left : InputEvent, right : InputEvent) -> bool:
	if left is InputEventKey and right is InputEventKey:
		var keycode: int = _resolved_keycode(left)
		if keycode != _resolved_keycode(right):
			return false
		if keycode != KEY_ALT and left.alt_pressed != right.alt_pressed:
			return false
		if keycode != KEY_SHIFT and left.shift_pressed != right.shift_pressed:
			return false
		if keycode != KEY_CTRL and left.ctrl_pressed != right.ctrl_pressed:
			return false
		if keycode != KEY_META and left.meta_pressed != right.meta_pressed:
			return false
		return true
	if left is InputEventMouseButton and right is InputEventMouseButton:
		return left.button_index == right.button_index
	if left is InputEventJoypadButton and right is InputEventJoypadButton:
		return left.button_index == right.button_index \
				and left.device == right.device
	if left is InputEventJoypadMotion and right is InputEventJoypadMotion:
		if left.axis != right.axis or left.device != right.device:
			return false
		return signf(left.axis_value) == signf(right.axis_value)
	return false


func _resolved_keycode(event : InputEventKey) -> int:
	return event.keycode if event.keycode != 0 else event.physical_keycode


func event2str(event : InputEvent) -> String:
	if event is InputEventKey:
		var ev_type = EventType.KEY
		var keycode = event.keycode
		if event.keycode == 0:
			ev_type = EventType.KEY_PHYSICAL
			keycode = event.physical_keycode
		if keycode == 0:
			return ""
		return "%s(%s%s)" % [event_prefixes[ev_type],
				_key_modifier_prefix(event, keycode),
				OS.get_keycode_string(keycode)]
	elif event is InputEventMouseButton:
		var ev_type = EventType.MOUSE_BUTTON
		return "%s(%s)" % [event_prefixes[ev_type], event.get_button_index()]
	elif event is InputEventJoypadButton:
		return "%s(%d,%d)" % [event_prefixes[EventType.JOY_BUTTON],
				event.button_index, event.device]
	elif event is InputEventJoypadMotion:
		return "%s(%d,%d,%d)" % [event_prefixes[EventType.JOY_AXIS],
				event.axis, _axis_sign(event.axis_value), event.device]
	return ""


## Axis identity is the sign: a stick or trigger binding is its full +/-1.0
## travel direction, matching the project defaults, never a fractional
## sample of the travel.
func _axis_sign(axis_value : float) -> int:
	return 1 if axis_value >= 0.0 else -1


## Modifier flags of a key event as combo tokens ("Alt+Ctrl+"). A modifier
## key pressed on its own is not its own prefix: the Alt key event writes
## "key(Alt)", never "key(Alt+Alt)".
func _key_modifier_prefix(event : InputEventKey, keycode : int) -> String:
	var prefix := ""
	if keycode != KEY_ALT and event.alt_pressed:
		prefix += "Alt+"
	if keycode != KEY_SHIFT and event.shift_pressed:
		prefix += "Shift+"
	if keycode != KEY_CTRL and event.ctrl_pressed:
		prefix += "Ctrl+"
	if keycode != KEY_META and event.meta_pressed:
		prefix += "Meta+"
	return prefix


func str2event(string : String) -> InputEvent:
	string = string.strip_edges()
	for ev_type in event_prefixes.size():
		if string.begins_with(event_prefixes[ev_type]):
			string = string.trim_prefix(event_prefixes[ev_type])
			string = string.trim_prefix("(").trim_suffix(")")
			match ev_type:
				EventType.KEY, EventType.KEY_PHYSICAL:
					return _str2key_event(string, ev_type == EventType.KEY_PHYSICAL)
				EventType.MOUSE_BUTTON:
					var button_index = int(string)
					var event = InputEventMouseButton.new()
					event.button_index = button_index
					return event
				EventType.JOY_BUTTON:
					return _str2joy_button_event(string)
				EventType.JOY_AXIS:
					return _str2joy_motion_event(string)
	return null


## Parses "joyb(button,device)" strings back into joypad button events. A
## missing device means all devices, matching the project defaults.
func _str2joy_button_event(string : String) -> InputEvent:
	var parts := string.split(",")
	if parts.is_empty() or not parts[0].is_valid_int():
		return null
	var event := InputEventJoypadButton.new()
	event.button_index = int(parts[0])
	event.device = GAMEPAD_DEVICE_ALL
	if parts.size() > 1 and parts[1].is_valid_int():
		event.device = int(parts[1])
	return event


## Parses "joym(axis,sign,device)" strings back into joypad motion events.
## The sign carries the direction; the value is always the full +/-1.0
## travel. A missing device means all devices.
func _str2joy_motion_event(string : String) -> InputEvent:
	var parts := string.split(",")
	if parts.size() < 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null
	var event := InputEventJoypadMotion.new()
	event.axis = int(parts[0])
	event.axis_value = 1.0 if int(parts[1]) >= 0 else -1.0
	event.device = GAMEPAD_DEVICE_ALL
	if parts.size() > 2 and parts[2].is_valid_int():
		event.device = int(parts[2])
	return event


## Parses "key(Alt+Ctrl+W)" style strings: leading modifier tokens set the
## flags, the last token is the key. A lone modifier ("key(Shift)") gets
## its own flag set, matching the OS event the player pressed to bind it.
func _str2key_event(string : String, physical : bool) -> InputEvent:
	if string.is_empty():
		return null
	var tokens := string.split("+")
	var modifiers := {}
	var key_token := ""
	for i in range(tokens.size()):
		var token := tokens[i]
		if i < tokens.size() - 1 and token in MODIFIER_TOKENS:
			modifiers[token] = true
			continue
		key_token = token
		break
	var keycode: Key = OS.find_keycode_from_string(key_token)
	if keycode == KEY_NONE:
		return null
	var event := InputEventKey.new()
	if physical:
		event.physical_keycode = keycode
	else:
		event.keycode = keycode
	event.alt_pressed = bool(modifiers.get("Alt", false)) or keycode == KEY_ALT
	event.shift_pressed = bool(modifiers.get("Shift", false)) or keycode == KEY_SHIFT
	event.ctrl_pressed = bool(modifiers.get("Ctrl", false)) or keycode == KEY_CTRL
	event.meta_pressed = bool(modifiers.get("Meta", false)) or keycode == KEY_META
	return event


func save_keys():
	var key_dict = gen_dict_from_input_map()
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	file.store_string(var_to_str(key_dict))
	file.close()
	print("saved keys")


func save_default_keys():
	var key_dict = gen_dict_from_input_map()
	var file = FileAccess.open(file_name_default, FileAccess.WRITE)
	file.store_string(var_to_str(key_dict))
	file.close()
	print("saved keys")
