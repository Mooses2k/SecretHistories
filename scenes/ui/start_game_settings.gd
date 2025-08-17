extends Node


var _settings : SettingsClass


func attach_settings(value : SettingsClass):
	_settings = value
	generate_settings()


func generate_settings():
	add_generation_settings()
	add_equipment()
	add_tiny_items()


func add_generation_settings():
	_settings.add_int_setting("World Seed", -55555, 55555, 1, randi() % 111110 - 55555)
	_settings.set_setting_group("World Seed", "Generation Settings")
	_settings.set_setting_meta("World Seed", _settings._CAN_RANDOMIZE_FLAG, true)


# add_equipment and add_tiny_items iterate through the pickable items and tiny items folders and 
# add the appropriate things they find to the Debug/Cheat list for things that can be spawned
# on the first dungeon level
# !IMPORTANT! You must run the script: item_paths_updater.gd after adding new equipment and tiny items to the game.
# This method avoid the DirAccess method which only works in editor, but not in builds

func add_equipment():
	var item_paths_resource: ItemPathsResource = load("res://resources/item_paths.tres")
	if not item_paths_resource:
		printerr("Failed to load item paths resource. Run utils/item_paths_updater.gd to generate it.")
		return
	
	for full_path in item_paths_resource.equipment_paths:
		var display_name := item_paths_resource.get_equipment_display_name(full_path)
		_settings.add_int_setting(display_name, 0, 999, 1, 0)
		_settings.set_setting_group(display_name, "Equipment")
		# Store the full path as metadata so other systems can access it
		_settings.set_setting_meta(display_name, "full_path", full_path)


func add_tiny_items():
	var item_paths_resource: ItemPathsResource = load("res://resources/item_paths.tres")
	if not item_paths_resource:
		printerr("Failed to load item paths resource. Run utils/item_paths_updater.gd to generate it.")
		return
	
	for full_path in item_paths_resource.tiny_item_paths:
		var display_name := item_paths_resource.get_tiny_item_display_name(full_path)
		_settings.add_int_setting(display_name, 0, 999, 1, 0)
		_settings.set_setting_group(display_name, "Tiny Items")
		# Store the full path as metadata so other systems can access it
		_settings.set_setting_meta(display_name, "full_path", full_path)
