@tool
extends EditorScript

## Editor utility script: rebuild res://resources/item_paths.tres
## Run this script in the editor when new items are added to update the resource file
## The scanning, display name resolution and saving live in ItemPathsResource,
## so the same job can also run headlessly without an editor.


func _run() -> void:
	print("Starting item paths discovery...")

	var resource: ItemPathsResource = preload("res://resources/item_paths_resource.gd").new()
	resource.regenerate()

	print("Equipment paths:")
	for path in resource.equipment_paths:
		print("  ", path)
	print("Tiny item paths:")
	for path in resource.tiny_item_paths:
		print("  ", path)
