extends Node


export(NodePath) var anchors_parent: NodePath
onready var spawnable_item_scenes := get_parent().get_node("SpawnableItems") as ResourcePreloader
export var max_placement_distance = 1.5


func _ready():
	var resource_list = spawnable_item_scenes.get_resource_list()
	var list_size = resource_list.size()
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
			var current_item = spawnable_item_scenes.get_resource(resource_list[random_num]).instance() as RigidBody
			anchor.add_child(current_item)
			spawned_num += 1
			
#			current_item.set_item_state(GlobalConsts.ItemState.DROPPED)
#			if current_item:
#				# Calculates where to place the item
#				var hold_pos = current_item.find_node("HoldPosition") as Position3D
#				var origin : Vector3 = owner.global_transform.origin
#				var end : Vector3 = anchor.global_transform.origin
#				var dir : Vector3 = end - origin
#				dir = dir.normalized() * min(dir.length(), max_placement_distance)
#				var layers = current_item.collision_layer
#				var mask = current_item.collision_mask
#				current_item.collision_layer = current_item.dropped_layers
#				current_item.collision_mask = current_item.dropped_mask
#				var result = PhysicsTestMotionResult.new()
#				# The return value can be ignored, since extra information is put into the 'result' variable
#				PhysicsServer.body_test_motion(current_item.get_rid(), anchor.global_transform, dir, false, result, true)
#				current_item.collision_layer = layers
#				current_item.collision_mask = mask
				

