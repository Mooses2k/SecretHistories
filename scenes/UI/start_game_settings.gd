extends Node

var _settings : SettingsClass

func attach_settings(value : SettingsClass):
	_settings = value
	generate_settings()
	pass

func generate_settings():
	add_equipment()
	add_tiny_items()
	pass

func add_equipment():
	var dir = Directory.new()
	var dir_stack = Array()
	dir.open("res://scenes/objects/pickable_items/equipment/")
	dir.list_dir_begin(true, true)
	dir_stack.push_back(dir)
	while not dir_stack.empty():
		var top : Directory = dir_stack[-1]
		var next : String = top.get_next()
		var full_path = path_from_parts(top.get_current_dir(), next)
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
			if full_path.ends_with(".tscn"):
				_settings.add_int_setting(full_path, 0, 999, 1, 0)
				_settings.set_setting_group(full_path, "Equipment")
	pass

func add_tiny_items():
	var dir = Directory.new()
	var dir_stack = Array()
	dir.open("res://resources/tiny_items/")
	dir.list_dir_begin(true, true)
	dir_stack.push_back(dir)
	while not dir_stack.empty():
		var top : Directory = dir_stack[-1]
		var next : String = top.get_next()
		var full_path = path_from_parts(top.get_current_dir(), next)
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
			if full_path.ends_with(".tres"):
				_settings.add_int_setting(full_path, 0, 999, 1, 999)
				_settings.set_setting_group(full_path, "Tiny Items") 

func path_from_parts(a : String, b : String) -> String:
	if not a.ends_with("/"):
		return a + "/" + b
	return a + b
