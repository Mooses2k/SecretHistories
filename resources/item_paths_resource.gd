class_name ItemPathsResource
extends Resource

## Resource that stores lists of equipment and tiny item file paths
## This allows dynamic discovery of items without using DirAccess in builds
## The display name arrays hold one friendly name per path, in the same order.
## Display names come from each item's own name data: the item_name export on
## the equipment scene root, and the name export on the tiny item data
## resource. Items whose data carries no usable name fall back to a cleaned-up
## file name.

const EQUIPMENT_DIR := "res://scenes/objects/pickable_items/"
const TINY_ITEMS_DIR := "res://resources/tiny_items/"
const RESOURCE_PATH := "res://resources/item_paths.tres"

const _GENERIC_EQUIPMENT_NAME := "Equipment"
const _GENERIC_TINY_NAME := "Tiny Item"

@export var equipment_paths: PackedStringArray = PackedStringArray()
@export var equipment_display_names: PackedStringArray = PackedStringArray()
@export var tiny_item_paths: PackedStringArray = PackedStringArray()
@export var tiny_item_display_names: PackedStringArray = PackedStringArray()


## Get a display-friendly name for equipment items
func get_equipment_display_name(full_path: String) -> String:
	var index := equipment_paths.find(full_path)
	if index >= 0 and index < equipment_display_names.size() \
			and not equipment_display_names[index].is_empty():
		return equipment_display_names[index]
	return get_fallback_display_name(full_path)


## Get a display-friendly name for tiny items
func get_tiny_item_display_name(full_path: String) -> String:
	var index := tiny_item_paths.find(full_path)
	if index >= 0 and index < tiny_item_display_names.size() \
			and not tiny_item_display_names[index].is_empty():
		return tiny_item_display_names[index]
	return get_fallback_display_name(full_path)


## Cleaned-up file name, for items whose data carries no usable name
func get_fallback_display_name(full_path: String) -> String:
	var file_name: String = full_path.get_basename().get_file()
	return file_name.replace("-", "_").capitalize()


## Scan the item folders, resolve display names, and rewrite the .tres file.
## Generation-time work that loads every item scene and data resource: run it
## from the editor tool (utils/item_paths_updater.gd) or a headless runner,
## never from game runtime.
func regenerate() -> void:
	equipment_paths = scan_directory_for_files(EQUIPMENT_DIR, ".tscn")
	print("Found ", equipment_paths.size(), " equipment items")
	tiny_item_paths = scan_directory_for_files(TINY_ITEMS_DIR, ".tres")
	print("Found ", tiny_item_paths.size(), " tiny items")
	compute_display_names()
	print("Resolved display names for ", equipment_display_names.size(),
			" equipment and ", tiny_item_display_names.size(), " tiny items")

	var error := ResourceSaver.save(self, RESOURCE_PATH)
	if error != OK:
		push_error("Failed to save item paths resource: " + str(error))
		return
	print("Successfully saved item paths to: ", RESOURCE_PATH)


## Recursively scan a directory for files with the specified extension
## Excludes files that start with underscore (following original logic)
func scan_directory_for_files(base_path: String, extension: String) -> PackedStringArray:
	var found_files := PackedStringArray()
	var dir_stack := Array()

	var dir := DirAccess.open(base_path)
	if not dir:
		printerr("Failed to open directory: ", base_path)
		return found_files

	dir.list_dir_begin()
	dir_stack.push_back(dir)

	while not dir_stack.is_empty():
		var top: DirAccess = dir_stack[-1]
		var next: String = top.get_next()
		var current_dir := top.get_current_dir()

		if not current_dir.ends_with("/"):
			current_dir += "/"

		var full_path := current_dir + next

		if next.is_empty():
			dir_stack.pop_back()
			continue
		elif top.current_is_dir():
			var new_dir := DirAccess.open(full_path)
			if new_dir:
				new_dir.list_dir_begin()
				dir_stack.push_back(new_dir)
			continue
		else:
			# Check if file matches criteria (same logic as original)
			if full_path.ends_with(extension) and not full_path.get_file().begins_with("_"):
				found_files.append(full_path)

	return found_files


## Fill the display name arrays from each item's own name data.
## Generation-time work: it loads every item scene and data resource, so it
## only runs from regenerate(). Runtime reads the arrays and never loads item
## scenes for the sake of a name.
func compute_display_names() -> void:
	equipment_display_names = PackedStringArray()
	for full_path in equipment_paths:
		equipment_display_names.append(_read_scene_display_name(full_path))
	tiny_item_display_names = PackedStringArray()
	for full_path in tiny_item_paths:
		tiny_item_display_names.append(_read_resource_display_name(full_path))


## Read item_name out of a packed scene without instantiating it
func _read_scene_display_name(scene_path: String) -> String:
	if not ResourceLoader.exists(scene_path):
		push_warning("Item scene missing, using file name fallback: " + scene_path)
		return get_fallback_display_name(scene_path)
	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		push_warning("Item scene failed to load, using file name fallback: " + scene_path)
		return get_fallback_display_name(scene_path)
	var scene_state := packed_scene.get_state()
	# The item script lives on the scene root, so the root's item_name wins.
	# Later nodes are only consulted if the root carries no item_name at all.
	for node_index in scene_state.get_node_count():
		for property_index in scene_state.get_node_property_count(node_index):
			if scene_state.get_node_property_name(node_index, property_index) != "item_name":
				continue
			var item_name: String = scene_state.get_node_property_value(node_index, property_index)
			if not item_name.is_empty() and item_name != _GENERIC_EQUIPMENT_NAME:
				return item_name
	return get_fallback_display_name(scene_path)


## Read name out of a tiny item data resource
func _read_resource_display_name(resource_path: String) -> String:
	if not ResourceLoader.exists(resource_path):
		push_warning("Tiny item data missing, using file name fallback: " + resource_path)
		return get_fallback_display_name(resource_path)
	var item_data: Resource = load(resource_path)
	if item_data:
		var item_name: String = str(item_data.get("name"))
		if not item_name.is_empty() and item_name != _GENERIC_TINY_NAME:
			return item_name
	return get_fallback_display_name(resource_path)
