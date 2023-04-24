extends Node


enum FullscreenMode {
	FULLSCREEN = 0,
	BORDERLESS_WINDOWED = 1,
	WINDOWED = 2
}

var fullscreen_mode : int setget set_fullscreen_mode

var vsync : bool
var brightness : float

var master_audio_enabled : bool
var sound_enabled : bool
var music_enabled : bool
var voice_enabled : bool

var master_audio_volume : float
var sound_volume : float
var music_volume : float
var voice_volume : float

var file_name = "%s://keybinding.dict" % ("user" if OS.has_feature("standalone") else "res")

var mouse_sensitivity : float = 1

var setting_key = false


func _ready():
	pass
#	load_keys()
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


#func _process(delta):
#	if(Input.is_action_just_pressed("ui_cancel")):
#		get_tree().paused = !get_tree().paused
#		get_child(0).visible = get_tree().paused


func set_fullscreen_mode(value : int):
	fullscreen_mode = value
	match fullscreen_mode:
		FullscreenMode.FULLSCREEN:
			OS.window_fullscreen = true
			OS.window_borderless = false
		FullscreenMode.BORDERLESS_WINDOWED:
			OS.window_fullscreen = false
			OS.window_borderless = true
		FullscreenMode.WINDOWED:
			OS.window_fullscreen = false
			OS.window_borderless = false


#We'll use this when the game loads
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
	pass


func setup_keys(key_dict : Dictionary):
	for action in key_dict.keys():
#		for j in get_tree().get_nodes_in_group("button_keys"):
#			if(j.action_name == i):
#				j.text = OS.get_scancode_string(key_dict[i])
		var has_invalid : bool = false
		var events = Array()
		print("action : ", action)
		for event_str in key_dict[action]:
			var event = str2event(event_str)
			print("\tevent: ", var2str(event))
			if event:
				events.push_back(event)
			else:
				has_invalid = true
		if not has_invalid:
			InputMap.action_erase_events(action)
		for event in events:
			InputMap.action_add_event(action, event)


enum EventType {
	KEY,
	KEY_PHYSICAL,
	MOUSE_BUTTON,
}

var event_prefixes = [
	"key", # KEY
	"pkey", # KEY_PHYSICAL
]


func event2str(event : InputEvent) -> String:
	if event is InputEventKey:
		var ev_type = EventType.KEY
		var scancode = event.scancode
		if event.scancode == 0:
			ev_type = EventType.KEY_PHYSICAL
			scancode = event.physical_scancode
		return "%s(%s)" % [event_prefixes[ev_type], OS.get_scancode_string(scancode)]
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
	return null


func save_keys():
	var key_dict = gen_dict_from_input_map()
	var file = File.new()
	file.open(file_name,File.WRITE)
	file.store_string(var2str(key_dict))
	file.close()
	print("saved keys")
