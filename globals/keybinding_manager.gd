extends Node


var file_name = "%s://globals/settings/keybinding.dict" % ("user" if OS.has_feature("standalone") else "res")
var file_name_default = "%s://globals/settings/defaultKeys.dict" % ("user" if OS.has_feature("standalone") else "res")

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
			for event in InputMap.get_action_list(action):
				result[action].push_back(event2str(event))
	return result


# We'll use this when the game loads
func load_keys():
	var file = File.new()
	if(file.file_exists(file_name)):
		file.open(file_name,File.READ)
		var file_str = file.get_as_text()
		file.close()
		var data = str2var(file_str)
		if(typeof(data) == TYPE_DICTIONARY):
			setup_keys(data)
		else:
			printerr("corrupted data!")
	else:
		#NoFile, so lets save the default keys now
		save_keys()
		save_default_keys()
	
	file = File.new()
	file.open(file_name_default, File.READ)
	var file_str = file.get_as_text()
	file.close()
	var data = str2var(file_str)
	if(typeof(data) == TYPE_DICTIONARY):
		keys_default = data
	else:
		printerr("corrupted data!")
	pass


func setup_keys(key_dict : Dictionary):
	for action in key_dict.keys():
#		for j in get_tree().get_nodes_in_group("button_keys"):
#			if(j.action_name == i):
#				j.text = OS.get_scancode_string(key_dict[i])
		var has_invalid : bool = false
		var events = Array()
		for event_str in key_dict[action]:
			var event = str2event(event_str)
			if event:
				events.push_back(event)
			else:
				has_invalid = true
		if not has_invalid:
			InputMap.action_erase_events(action)
		for event in events:
			InputMap.action_add_event(action, event)


func event2str(event : InputEvent) -> String:
	if event is InputEventKey:
		var ev_type = EventType.KEY
		var scancode = event.scancode
		if event.scancode == 0:
			ev_type = EventType.KEY_PHYSICAL
			scancode = event.physical_scancode
		print("event == " + "%s(%s)" % [event_prefixes[ev_type], OS.get_scancode_string(scancode)])
		return "%s(%s)" % [event_prefixes[ev_type], OS.get_scancode_string(scancode)]
	elif event is InputEventMouseButton:
		print("Mouse Button " + str(event.get_button_index() ))
		var ev_type = EventType.MOUSE_BUTTON
		var scancode = event.get_button_index() 
		return "%s(%s)" % [event_prefixes[ev_type], scancode]
	else:
		print(var2str(event))
	return "?"


func str2event(string : String) -> InputEvent:
	string = string.strip_edges()
	for ev_type in event_prefixes.size():
		if string.begins_with(event_prefixes[ev_type]):
			string = string.trim_prefix(event_prefixes[ev_type])
			string = string.trim_prefix("(").trim_suffix(")")
			match ev_type:
				EventType.KEY:
					var scancode = OS.find_scancode_from_string(string)
					var event = InputEventKey.new()
					event.scancode = scancode
					return event
				EventType.KEY_PHYSICAL:
					var scancode = OS.find_scancode_from_string(string)
					var event = InputEventKey.new()
					event.physical_scancode = scancode
					return event
				EventType.MOUSE_BUTTON:
					var button_index = int(string)
					var event = InputEventMouseButton.new()
					event.button_index = button_index
					return event
	return null


func save_keys():
	var key_dict = gen_dict_from_input_map()
	var file = File.new()
	file.open(file_name, File.WRITE)
	file.store_string(var2str(key_dict))
	file.close()
	print("saved keys")


func save_default_keys():
	var key_dict = gen_dict_from_input_map()
	var file = File.new()
	file.open(file_name_default, File.WRITE)
	file.store_string(var2str(key_dict))
	file.close()
	print("saved keys")
