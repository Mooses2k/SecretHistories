extends Node


var file_name = "%s://globals/settings/keybinding.dict" % ("user" if OS.has_feature("standalone") else "res")
var file_name_default = "%s://globals/settings/default_keys.dict" % ("user" if OS.has_feature("standalone") else "res")

var setting_key = false
var keys_default : Dictionary

enum EventType {
	KEY,
	KEY_PHYSICAL,
	MOUSE_BUTTON,
}

var event_prefixes = [
	"key", # KEY
	"pkey", # KEY_PHYSICAL
	"mouse", # MOUSE_BUTTON
]

## Modifier tokens allowed in a key string, in the order event2str writes
## them: "key(Alt+Ctrl+W)". A lone modifier key ("key(Alt)") is its own
## binding, not a combo prefix.
const MODIFIER_TOKENS : PackedStringArray = ["Alt", "Shift", "Ctrl", "Meta"]


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
	# map lacks, then persist. Idempotent: once present, the "?" dict rows
	# keep the live events and the merge no-ops.
	if _merge_missing_joypad_defaults():
		keys_default = gen_dict_from_input_map()
		save_keys()
		save_default_keys()

	# Reboot reconcile (#606): events re-parsed from the dict strings are
	# new objects that differ from the project.godot default events in
	# incidental fields (device, exact flags). Any live keyboard/mouse
	# event that IS a project default binding gets replaced by the actual
	# default event object, so default actions hold the exact project
	# events after every boot and drift cannot accumulate.
	_reconcile_default_events()


## Returns true when at least one project.godot joypad default was missing
## from the live InputMap and was re-added. Keyboard/mouse bindings (user
## customizations included) are never touched.
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


## Replaces every live keyboard/mouse event that carries a project default
## binding with the actual project default event object, so identity
## matches exactly (device and flags included).
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
			if not (default is InputEventKey or default is InputEventMouseButton):
				continue
			for live_event in InputMap.action_get_events(action):
				var live := live_event as InputEvent
				if live != null and live != default and _same_binding(live, default):
					InputMap.action_erase_event(action, live)
					InputMap.action_add_event(action, default)
					break


## Binding-level equality of two keyboard/mouse events: key (physical
## resolved) plus modifier flags for keys, button index for mouse buttons.
## A modifier key's own flag is implied by the key itself and ignored, so
## a parsed lone "key(Alt)" matches the project default Alt event.
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
	return ""


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
	return null


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
