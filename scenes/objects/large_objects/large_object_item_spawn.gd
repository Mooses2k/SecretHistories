extends Node


export(NodePath) var anchors_parent: NodePath


func _ready():
	if not owner.spawnable_items.empty():
		var random_num
		var anchors = filter_list_anchors(get_node(anchors_parent).get_children())
		
		for item_path in owner.spawnable_items:
			random_num = randi() % anchors.size()
			# handle bad refs in the loot list
			if !is_instance_valid(item_path):
				return
			var new_item = load(item_path).instance()
				
			if new_item is ShardOfTheComet and GameManager.game.shard_has_spawned == false:
				GameManager.game.shard_has_spawned = true
				print("First shard spawned!!!!!", new_item)
			elif new_item is ShardOfTheComet and GameManager.game.shard_has_spawned:
				new_item.queue_free()
				print("Wiped out an extra shard, ", new_item)
				return
			
			new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
			new_item.translation = anchors[random_num].translation + Vector3(0, 0.3, 0)
			get_parent().get_parent().add_child(new_item)
			anchors.remove(random_num)


func filter_list_anchors(anchor_nodes: Array) -> Array:
	var filtered_list : Array
	
	for anchor_node in anchor_nodes:
		if anchor_node is Position3D:
			filtered_list.append(anchor_node)
	
	return filtered_list
