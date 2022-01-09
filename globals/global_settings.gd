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

var file_name = "res://keybinding.json"
var key_dict = {
	"move_up":87,
	"move_left":65,
	"move_down":83,
	"move_right":68,
	"sprint":16777237,
	"interact":70,
	"kick":16777238,
	"reload":0,
	"offhand_use":69,
	"throw":84,
	"inventory_menu":16777218,
	"map_menu":77
}
var setting_key = false


func _ready():
	load_keys()
# leftovers from tutorial version
#	get_child(0).visible = false
#	pause_mode = Node.PAUSE_MODE_PROCESS


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
		delete_old_keys()
		file.open(file_name,File.READ)
		var data = parse_json(file.get_as_text())
		file.close()
		if(typeof(data) == TYPE_DICTIONARY):
			key_dict = data
			setup_keys()
		else:
			printerr("corrupted data!")
	else:
		#NoFile, so lets save the default keys now
		save_keys()
	pass
	
func delete_old_keys():
	#Remove the old keys
	for i in key_dict:
		var oldkey = InputEventKey.new()
		oldkey.scancode = int(key_dict[i])
		InputMap.action_erase_event(i,oldkey)

func setup_keys():
	for i in key_dict:
		for j in get_tree().get_nodes_in_group("button_keys"):
			if(j.action_name == i):
				j.text = OS.get_scancode_string(key_dict[i])
		var newkey = InputEventKey.new()
		newkey.scancode = int(key_dict[i])
		InputMap.action_add_event(i,newkey)
	
func save_keys():
	var file = File.new()
	file.open(file_name,File.WRITE)
	file.store_string(to_json(key_dict))
	file.close()
	print("saved")
	pass
