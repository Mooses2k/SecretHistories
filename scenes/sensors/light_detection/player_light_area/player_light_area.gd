tool class_name PlayerLightArea extends LightArea


export var parent_item_path: NodePath


func _enter_tree() -> void:
	if !parent_item_path.is_empty():
		var parent_item = get_node(parent_item_path)
		if parent_item is CandelabraItem and is_instance_valid(parent_item):
			collision_shape.disabled = parent_item.is_dropped or !parent_item.is_lit
	._enter_tree()
