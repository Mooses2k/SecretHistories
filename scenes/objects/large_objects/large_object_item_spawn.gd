extends Node


@export var anchors_parent: NodePath
@export var max_items_to_spawn : int = 5


func _ready():
	if not owner.spawnable_items.is_empty():
		var random_num
		var anchors = filter_list_anchors(get_node(anchors_parent).get_children())
		
		for item_path in owner.spawnable_items:
			random_num = randi() % anchors.size()
			
			# handle bad refs in the loot list
			var loaded = load(item_path)
			if !loaded || (loaded and (!(loaded is PackedScene))):
				return

			var new_item = loaded.instantiate()
			if not is_instance_valid(new_item):
				return
				
			if new_item is ShardOfTheComet and GameManager.game.shard_has_spawned == false:
				GameManager.game.shard_has_spawned = true
			elif new_item is ShardOfTheComet and GameManager.game.shard_has_spawned:
				new_item.queue_free()
				return
			
			if new_item is ShardOfTheComet:   # the code below this indent breaks this spawn, so have to use old version here
				anchors[random_num].add_child(new_item)
				new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
			else:
				new_item.position = anchors[random_num].position
				if new_item.placement_position:
					new_item.position += new_item.placement_position.position
				new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
				get_parent().get_parent().add_child(new_item)
				anchors.remove_at(random_num)


func filter_list_anchors(anchor_nodes: Array) -> Array:
	var filtered_list := []
	
	for anchor_node in anchor_nodes:
		if anchor_node is Marker3D:
			filtered_list.append(anchor_node)
	
	return filtered_list
