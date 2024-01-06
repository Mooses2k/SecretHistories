extends Node


export var anchors_parent: NodePath
export var max_items_to_spawn : int = 5


func _ready():
	if not owner.spawnable_items.empty():
		var random_num
		var anchors = filter_list_anchors(get_node(anchors_parent).get_children())
		
		for item_path in owner.spawnable_items:
			random_num = randi() % anchors.size()
			
			# handle bad refs in the loot list
			var loaded = load(item_path)
			if !loaded || (loaded and (!(loaded is PackedScene) || !is_instance_valid(loaded.instance()))):
				return

			var new_item = loaded.instance()
				
			if new_item is ShardOfTheComet and GameManager.game.shard_has_spawned == false:
				GameManager.game.shard_has_spawned = true
			elif new_item is ShardOfTheComet and GameManager.game.shard_has_spawned:
				new_item.queue_free()
				return
			
			if new_item is ShardOfTheComet:   # the code below this indent breaks this spawn, so have to use old version here
				anchors[random_num].add_child(new_item)
				new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
			else:
				new_item.translation = anchors[random_num].translation
				if new_item.placement_position:
					new_item.translation += new_item.placement_position.translation
				new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
				get_parent().get_parent().add_child(new_item)
				anchors.remove(random_num)


func filter_list_anchors(anchor_nodes: Array) -> Array:
	var filtered_list := []
	
	for anchor_node in anchor_nodes:
		if anchor_node is Position3D:
			filtered_list.append(anchor_node)
	
	return filtered_list
