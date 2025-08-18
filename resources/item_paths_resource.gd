class_name ItemPathsResource
extends Resource

## Resource that stores lists of equipment and tiny item file paths
## This allows dynamic discovery of items without using DirAccess in builds

@export var equipment_paths: PackedStringArray = PackedStringArray()
@export var tiny_item_paths: PackedStringArray = PackedStringArray()

## Get a display-friendly name for equipment items (removes path prefix)
func get_equipment_display_name(full_path: String) -> String:
	var prefix := "res://scenes/objects/pickable_items/equipment/"
	if full_path.begins_with(prefix):
		return full_path.substr(prefix.length())
	return full_path

## Get a display-friendly name for tiny items (removes path prefix)
func get_tiny_item_display_name(full_path: String) -> String:
	var prefix := "res://resources/tiny_items/"
	if full_path.begins_with(prefix):
		return full_path.substr(prefix.length())
	return full_path