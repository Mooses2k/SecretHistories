tool class_name PlayerLightArea extends LightArea


export var parent_item_path: NodePath
var parent_item


func _enter_tree() -> void:
	if !parent_item_path.is_empty():
		parent_item = get_node(parent_item_path)
	._enter_tree()
