@tool
extends EditorScript

## Editor utility script to scan directories and populate ItemPathsResource
## Run this script in the editor when new items are added to update the resource file

const EQUIPMENT_DIR := "res://scenes/objects/pickable_items/"
const TINY_ITEMS_DIR := "res://resources/tiny_items/"
const RESOURCE_PATH := "res://resources/item_paths.tres"

func _run():
	print("Starting item paths discovery...")
	
	var resource: ItemPathsResource = preload("res://resources/item_paths_resource.gd").new()
	
	# Scan for equipment (.tscn files)
	resource.equipment_paths = scan_directory_for_files(EQUIPMENT_DIR, ".tscn")
	print("Found ", resource.equipment_paths.size(), " equipment items")
	
	# Scan for tiny items (.tres files)
	resource.tiny_item_paths = scan_directory_for_files(TINY_ITEMS_DIR, ".tres")
	print("Found ", resource.tiny_item_paths.size(), " tiny items")
	
	# Save the resource
	var error := ResourceSaver.save(resource, RESOURCE_PATH)
	if error == OK:
		print("Successfully saved item paths to: ", RESOURCE_PATH)
		print("Equipment paths:")
		for path in resource.equipment_paths:
			print("  ", path)
		print("Tiny item paths:")
		for path in resource.tiny_item_paths:
			print("  ", path)
	else:
		printerr("Failed to save resource: ", error)

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
