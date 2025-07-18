class_name AnchorSpawner
extends Node

## Uses anchors (Marker3D) to spawn whatever SpawnData has in them.

@export var anchors_parent: NodePath

func _ready():
	pass


## Expects a dictionary of SpawnData where keys are index of Marker3D nodes.
func spawn_items_on_anchors(spawn_dict: Dictionary) -> void:
	if spawn_dict.is_empty():
		return
	
	var sarco_parent := owner.get_parent()
	var anchors = filter_list_anchors(get_node(anchors_parent).get_children())
	
	for anchor_index in spawn_dict.keys():
		var anchor := anchors[anchor_index] as Marker3D
		var spawn_data := spawn_dict[anchor_index] as SpawnData
		spawn_data.spawn_in(anchor)


func filter_list_anchors(anchor_nodes: Array) -> Array:
	var filtered_list := []
	
	for anchor_node in anchor_nodes:
		if anchor_node is Marker3D:
			filtered_list.append(anchor_node)
	
	return filtered_list
