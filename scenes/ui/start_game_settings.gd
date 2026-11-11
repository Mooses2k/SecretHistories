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
## their WorldData.OriginalPurpose keys. World generation matches the selected
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


## Debug spawn box (issue #651): registers one spawn of any item by path,
## following the same settings pattern the Equipment and Tiny Items lists
## use, so the generation's initial-settings-items step spawns it on the
## first dungeon level exactly like the counted entries. A .tscn path goes
## to the Equipment branch (loaded directly as the item scene), a .tres path
## to the Tiny Items branch (the tiny item data the tiny spawner wraps).
## Pressing again bumps the count, one more spawn per press.
func register_spawn_by_path(item_path : String) -> bool:
	var trimmed := item_path.strip_edges()
	if trimmed.is_empty():
		printerr("Spawn box: empty item path")
		return false
	if not trimmed.begins_with("res://"):
		printerr("Spawn box: item path must start with res://: " + trimmed)
		return false
	var resource : Resource = null
	if FileAccess.file_exists(trimmed):
		resource = load(trimmed)
	if resource == null:
		printerr("Spawn box: failed to load item path: " + trimmed)
		return false
	if trimmed.ends_with(".tres"):
		# Tiny items spawn through their item data resource, and only the
		# registered ones are spawnyable: anything else cannot become an item.
		var item_paths_resource: ItemPathsResource = load("res://resources/item_paths.tres")
		if item_paths_resource == null or not item_paths_resource.tiny_item_paths.has(trimmed):
			printerr("Spawn box: not a registered tiny item path: " + trimmed)
			return false
		_register_spawn_setting(trimmed, "Tiny Items")
	elif trimmed.ends_with(".tscn"):
		_register_spawn_setting(trimmed, "Equipment")
	else:
		printerr("Spawn box: not an item scene (.tscn) or registered tiny item (.tres): " + trimmed)
		return false
	return true


func _register_spawn_setting(item_path : String, group : String) -> void:
	if _settings.has_setting(item_path):
		# Each press spawns one more: bump the existing spawn count.
		var amount : int = _settings.get_setting(item_path)
		_settings.set_setting(item_path, amount + 1)
		return
	_settings.add_int_setting(item_path, 0, 999, 1, 1)
	_settings.set_setting_group(item_path, group)
	_settings.set_setting_meta(item_path, "display_name", item_path.get_file())
	_settings.set_setting_meta(item_path, "full_path", item_path)
