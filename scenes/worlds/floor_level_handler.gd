# Write your doc string for this file here
class_name FloorLevelHandler
extends Reference

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const MAX_DISTANCE_TO_KEEP_INSTANCE = 0

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _floor_level: GameWorld = null
# Don't know what this will be, just keeping it here for the future
var _floor_serialized := {}

var _floor_world_data: WorldData = null
var _floor_packed_scene: PackedScene = null
var _child_packed_scenes := {}

var _floor_index: int = 0

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init(p_floor: GameWorld, p_index: int) -> void:
	_floor_level = p_floor
	_floor_world_data = _floor_level.world_data
	_floor_index = p_index


func _to_string() -> String:
	var msg := "[FloorLevelHandler:%s]"%[get_instance_id()]
	msg += "\n\t - floor_index: %s"%[_floor_index]
	msg += "\n\t - floor_level: %s"%[_floor_level]
	msg += "\n\t - floor_serialized: %s"%[_floor_serialized]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func update_floor_data(current_index: int) -> void:
	var distance := abs(current_index - _floor_index)
	
	if distance == 0:
		return
	
	if distance <= MAX_DISTANCE_TO_KEEP_INSTANCE:
		if not _floor_serialized.empty() and not is_instance_valid(_floor_level):
			_restore_floor_level()
	else:
		if _floor_serialized.empty() and is_instance_valid(_floor_level):
			_serialize_floor_level()
	
	print("Updated floor data: %s"%[self])


func get_level_instance() -> GameWorld:
	if not is_instance_valid(_floor_level):
		_restore_floor_level()
	
	return _floor_level

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _restore_floor_level() -> void:
	# Write code to deserialize level here
	_floor_level = _floor_serialized.packed_scene.instance()
	_floor_level.world_data = _floor_world_data
	_floor_level.connect("ready", self, "_on_floor_level_ready", [], CONNECT_ONESHOT)


func _sort_by_node_path_length(a: NodePath, b: NodePath) -> bool:
	var a_before_b := a.get_name_count() < b.get_name_count()
	if a == NodePath(".") and not a_before_b:
		a_before_b = true
	return a_before_b


# READ ME NUMBER 2 (start from number 1)
# Here we try to get the data we saved, of child scenes that were instanced on SerializedWorld, 
# saved as PackedScenes and stored on a dictionary with "parent node paths" as keys, sort the keys 
# by shortest nodepaths so that we make sure we are instancing parents first and children later, 
# and try to rebuild the scene.
# If this worked, we would have a "quick and dirty" "generic" way to save state regardless of which
# scene was instanced and how procedural world was built, but it doesn't becauese this ends up 
# breaking dependencies. It breaks all BT nodes for some reason. It breaks sarcophagus lids because
# their "Position3D" nodes are saved to the sarcophagus scene, but are child to another scene that 
# will only be instanced later in this way, but that gets instanced before when we just load 
# sarcophagus.tscn
# This should have been clear for me before starting and is a deal breaker, making this a waste of 
# time. It will be better to use a similar interface to ask all important nodes to serialize 
# themselves and then, when loading, rebuild de level and use the saved serialized data to change 
# positions, delete things that were consumed, add things that were brought from other levels.
func _on_floor_level_ready() -> void:
	var child_node_paths: Array = _floor_serialized.children.keys()
	child_node_paths.sort_custom(self, "_sort_by_node_path_length")
	print("---- Sorted Child Node Paths: \n%s"%[JSON.print(child_node_paths, "\t")])
	
	for node_path in child_node_paths:
		var children_to_add := _floor_serialized.children[node_path] as Array
		for child_data in children_to_add:
			var child_node: Node = child_data.packed_scene.instance()
			var parent_node: Node = _floor_level.get_node(child_data.parent_path)
			if parent_node == null:
				push_error("failed to add: %s"%[child_data])
				continue
			if parent_node.has_node(child_data.node_name):
				var current_node = parent_node.get_node(child_data.node_name)
				parent_node.remove_child(current_node)
				current_node.free()
			
			parent_node.add_child(child_node, true)


func _serialize_floor_level() -> void:
	# Write code to serialize level here. 
	_floor_serialized = _get_serialized_data(_floor_level, _floor_level)
	# READ ME NUMBER 3 (start from number 1)
	# Search for this print if you have trouble visualizing what/how things are being saved.
	print("---- Serialized Data: \n%s"%[JSON.print(_floor_serialized, "\t")])

	# You'll probably want to keep the part below so just 
	# left it here from my failed attempts, if it's needed just uncomment them.
	if _floor_level.is_inside_tree():
		_floor_level.queue_free()
	else:
		_floor_level.free()
	
	_floor_level = null
	pass


# READ ME NUMBER 1
# This approach was a failure and is only here to register it as an attempt and serve as example
# or curiosity. What I was trying to do was save the current state of every scene that makes
# the scene tree by identifying all the nodes that are owners of child nodes, and if so save them
# (and consequently their children) as a "temporary" packed scene in the memmory. 
# The "main" packed scene gets stored on `_floor_packed_scene` and any instanced child scenes
# get saved on the dict `_child_packed_scenes` where keys are paths from FloorLevel Root 
# ("ProceduralWorld") to the parent where this packed scene should be instanced.
func _get_serialized_data(starting_node: Node, owner_to_check: Node) -> Dictionary:
	var serialized_data := {
		node_name = starting_node.name,
		packed_scene = null,
		parent_path = null,
		children = {},
	}
	
	var is_owner_of_child_nodes := false
	for child in starting_node.get_children():
		if child.owner == starting_node:
			is_owner_of_child_nodes = true
			break
	
	if is_owner_of_child_nodes:
		var packed_scene := PackedScene.new()
		packed_scene.pack(starting_node)
		serialized_data.packed_scene = packed_scene
#		print("node_name: %s | owner: %s"%[starting_node.name, starting_node.owner])
		
		if starting_node != owner_to_check:
			var parent := starting_node.get_parent()
			serialized_data.parent_path = owner_to_check.get_path_to(parent)
		
	for child in starting_node.get_children():
		var node: Node = child
		var child_data := {}
		print("checking for nested scenes in %s"%[node.name])
		child_data = _get_serialized_data(node, owner_to_check)
		
		if not child_data.children.empty():
			serialized_data.children.merge(child_data.children)
			child_data.children.clear()
		
		if child_data.packed_scene != null:
			if not serialized_data.children.has(child_data.parent_path):
				serialized_data.children[child_data.parent_path] = []
			serialized_data.children[child_data.parent_path].append(child_data)
	
	return serialized_data

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
