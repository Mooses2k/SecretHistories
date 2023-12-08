extends Node


export(NodePath) var anchors_parent: NodePath


func _ready():
	if not owner.spawnable_items.empty():
		var list_size = owner.spawnable_items.size()
		var spawned_num = 0
		var random_num
		
		for anchor in get_node(anchors_parent).get_children():
			random_num = randi() % 3
			
			if spawned_num > 10:
				break;
				
			if random_num == 1:
				continue;
				
			if anchor is Position3D and not "Position" in anchor.name:
				random_num = randi() % list_size
				var current_item = load(owner.spawnable_items[random_num]).instance() as RigidBody
				anchor.add_child(current_item)
				spawned_num += 1
