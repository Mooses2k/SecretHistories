extends Node


var _settings : SettingsClass


func attach_settings(value : SettingsClass):
	_settings = value
	generate_settings()


func generate_settings():
	add_generation_settings()
	add_equipment()
#	add_tiny_items()


func add_generation_settings():
	_settings.add_int_setting("World Seed", -55555, 55555, 1, randi() % 111110 - 55555)
	_settings.set_setting_group("World Seed", "Generation Settings")
	_settings.set_setting_meta("World Seed", _settings._CAN_RANDOMIZE_FLAG, true)


# add_equipment and add_tiny_items iterate through the pickable items and tiny items folders and 
# add the appropriate things they find to the Debug/Cheat list for things that can be spawned
# on the first dungeon level

func add_equipment():
	var dir = Directory.new()
	var dir_stack = Array()
	dir.open("res://scenes/objects/pickable_items/")
	dir.list_dir_begin(true, true)
	dir_stack.push_back(dir)
	while not dir_stack.empty():
		var top : Directory = dir_stack[-1]
		var next : String = top.get_next()
		var full_path = top.get_current_dir().plus_file(next)
		if next.empty():
			dir_stack.pop_back()
			continue
		elif top.current_is_dir():
			var new_dir = Directory.new()
			new_dir.open(full_path)
			new_dir.list_dir_begin(true, true)
			dir_stack.push_back(new_dir)
			continue
		else:
			if full_path.ends_with(".tscn") and not full_path.get_file().begins_with("_"):
				_settings.add_int_setting(full_path, 0, 999, 1, 0)
				_settings.set_setting_group(full_path, "Equipment")


func add_tiny_items():
	var dir = Directory.new()
	var dir_stack = Array()
	dir.open("res://resources/tiny_items/")
	dir.list_dir_begin(true, true)
	dir_stack.push_back(dir)
	while not dir_stack.empty():
		var top : Directory = dir_stack[-1]
		var next : String = top.get_next()
		var full_path = top.get_current_dir().plus_file(next)
		if next.empty():
			dir_stack.pop_back()
			continue
		elif top.current_is_dir():
			var new_dir = Directory.new()
			new_dir.open(full_path)
			new_dir.list_dir_begin(true, true)
			dir_stack.push_back(new_dir)
			continue
		else:
			if full_path.ends_with(".tres") and not full_path.get_file().begins_with("_"):
				_settings.add_int_setting(full_path, 0, 999, 1, 0)
				_settings.set_setting_group(full_path, "Tiny Items")
