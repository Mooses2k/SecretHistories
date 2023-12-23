extends Node


export(NodePath) var anchors_parent: NodePath
export var max_items_to_spawn : int = 5

func _ready():
	if not owner.spawnable_items.empty():	
		var items_to_spawn = max_items_to_spawn
		
		var anchors = filter_list_anchors(get_node(anchors_parent).get_children())
		anchors.shuffle()
		items_to_spawn = min(items_to_spawn, anchors.size())
		
		var spawnable_items = Array(owner.spawnable_items)
		spawnable_items.shuffle()
		items_to_spawn = min(items_to_spawn, spawnable_items.size())
		
		for i in items_to_spawn:
			var item_path = spawnable_items[i]
			
			# handle bad refs in the loot list
			var item_packed = load(item_path)
			if !is_instance_valid(item_packed):
				return
				
			var new_item = item_packed.instance()
				
			if new_item is ShardOfTheComet and GameManager.game.shard_has_spawned == false:
				GameManager.game.shard_has_spawned = true
				print("First shard spawned!!!!!", new_item)
			elif new_item is ShardOfTheComet and GameManager.game.shard_has_spawned:
				new_item.queue_free()
				print("Wiped out an extra shard, ", new_item)
				return
			
			if new_item is ShardOfTheComet:   # the code below this indent breaks this spawn, so have to use old version here
				anchors[i].add_child(new_item)
				new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
			else:
				new_item.translation = anchors[i].translation
				if new_item.placement_position:
					new_item.translation += new_item.placement_position.translation
				new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
				get_parent().get_parent().add_child(new_item)


func filter_list_anchors(anchor_nodes: Array) -> Array:
	var filtered_list : Array
	
	for anchor_node in anchor_nodes:
		if anchor_node is Position3D:
			filtered_list.append(anchor_node)
	
	return filtered_list
