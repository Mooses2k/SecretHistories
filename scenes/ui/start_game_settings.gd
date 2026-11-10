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
	_settings.add_enum_setting(ForceRoomPurpose.SETTING_NAME, FORCE_ROOM_PURPOSE_VARIANTS, 0)
	_settings.set_setting_group(ForceRoomPurpose.SETTING_NAME, "Generation Settings")


## Display names for the Force Room Purpose debug enum: OFF plus the purposes
## wired into procedural_world.tscn's GenerateRoomPurposes step, named after
## their RoomData.OriginalPurpose keys. World generation matches the selected
## variant against those keys, so this list is display data: wiring a new
## purpose into the generation scene means adding its key here too.
const FORCE_ROOM_PURPOSE_VARIANTS := ["OFF", "CRYPT", "FOUNTAIN", "STATUE_GALLERY", "TROPHY_ROOM"]


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
		# The setting key is the full item path: unique per item, and what the
		# spawn step reads. The friendly name travels as display metadata so
		# the UI can show it without making labels unique keys.
		_settings.add_int_setting(full_path, 0, 999, 1, 0)
		_settings.set_setting_group(full_path, "Equipment")
		_settings.set_setting_meta(full_path, "display_name", item_paths_resource.get_equipment_display_name(full_path))
		_settings.set_setting_meta(full_path, "full_path", full_path)


func add_tiny_items():
	var item_paths_resource: ItemPathsResource = load("res://resources/item_paths.tres")
	if not item_paths_resource:
		printerr("Failed to load item paths resource. Run utils/item_paths_updater.gd to generate it.")
		return

	for full_path in item_paths_resource.tiny_item_paths:
		_settings.add_int_setting(full_path, 0, 999, 1, 0)
		_settings.set_setting_group(full_path, "Tiny Items")
		_settings.set_setting_meta(full_path, "display_name", item_paths_resource.get_tiny_item_display_name(full_path))
		_settings.set_setting_meta(full_path, "full_path", full_path)
