@tool
## Item-specific spawn data implementation
## Handles spawning of individual items with item-specific logic
class_name ItemSpawnData
extends SpawnData


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	super._init()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Override spawn_at_anchors for item-specific anchor spawning
## This will be used by future AnchorSpawner integration
func spawn_at_anchors(anchors: Array, rng: RandomNumberGenerator = null, should_log := false) -> Array:
	if _has_spawned:
		return []
	
	if anchors.is_empty():
		if should_log:
			print("ItemSpawnData: No anchors provided for spawning")
		return []
	
	var item_scene: PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		print("ERROR ItemSpawnData: Failed to load scene: %s" % scene_path)
		return []
	
	var spawned_items: Array = []
	var available_anchors := anchors.duplicate()
	var spawn_count := mini(amount, available_anchors.size())
	
	for index in spawn_count:
		var anchor_index: int = 0
		if rng:
			anchor_index = rng.randi() % available_anchors.size()
		
		var anchor = available_anchors[anchor_index]
		if not is_instance_valid(anchor):
			available_anchors.remove_at(anchor_index)
			continue
		
		var item = item_scene.instantiate()
		if not is_instance_valid(item):
			print("ERROR ItemSpawnData: Failed to instantiate scene: %s" % scene_path)
			continue
		
		# Position item at anchor
		if item is Node3D and anchor is Node3D:
			var node3d_item = item as Node3D
			var anchor_node3d = anchor as Node3D
			node3d_item.global_position = anchor_node3d.global_position
			
			# Apply stored transform rotation if available
			if index < _transforms.size():
				var stored_transform := _transforms[index] as Transform3D
				node3d_item.transform.basis = stored_transform.basis
		
		# Apply custom properties
		if index < _custom_properties.size():
			var custom_properties := _custom_properties[index] as Dictionary
			_apply_custom_properties(item, custom_properties)
		
		# Add to scene tree - use anchor's parent or a suitable parent
		var spawn_parent: Node = anchor.get_parent()
		if not spawn_parent:
			spawn_parent = anchor
		spawn_parent.add_child(item, true)
		
		# Apply item-specific post-spawn logic
		_post_spawn_item_setup(item)
		
		# Handle wall-specific properties
		if index < _custom_properties.size():
			_handle_wall_object_properties(item, _custom_properties[index])
		
		spawned_items.append(item)
		available_anchors.remove_at(anchor_index)
	
	_has_spawned = true
	return spawned_items


## Enhanced item spawning with better positioning support
func spawn_item_in(node: Node, should_log := false) -> void:
	if _has_spawned:
		return
	
	var item_scene: PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		print("ERROR ItemSpawnData: Failed to load scene: %s" % scene_path)
		return
	
	for index in amount:
		var item = item_scene.instantiate()
		if not is_instance_valid(item):
			print("ERROR ItemSpawnData: Failed to instantiate scene: %s" % scene_path)
			continue
		
		# Apply transform
		if item is Node3D:
			var node3d_item = item as Node3D
			node3d_item.transform = _transforms[index]
		
		# Apply custom properties
		var custom_properties := _custom_properties[index] as Dictionary
		_apply_custom_properties(item, custom_properties)
		
		# Handle tiny item configuration
		_configure_tiny_item(item, custom_properties)
		
		node.add_child(item, true)
		
		# Apply item-specific post-spawn logic
		_post_spawn_item_setup(item)
		
		# Handle wall-specific properties
		_handle_wall_object_properties(item, custom_properties)
	
	_has_spawned = true


## Item-specific spawn validation
func can_spawn_at_position(world_data: WorldData, position: Vector3) -> bool:
	var cell_index := CellFilter.get_cell_from_local_position(world_data, position)
	if cell_index == -1:
		return false
	
	# Check if cell is available for item spawning
	return CellFilter.is_cell_available(world_data, cell_index)


## Get suitable spawn positions for items using CellFilter
func get_item_spawn_positions(world_data: WorldData, room_data: RoomData, cell_filter: CellFilter, rng: RandomNumberGenerator = null) -> Array:
	var valid_cells := get_valid_spawn_cells(world_data, room_data, cell_filter, rng)
	var positions: Array = []
	
	for cell_index in valid_cells:
		var cell_position := CellFilter.get_cell_position(world_data, cell_index)
		var spawn_position := cell_position + _get_center_offset()
		positions.append(spawn_position)
	
	return positions

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## Item-specific post-spawn setup
## Overrides base implementation with item-specific logic
func _post_spawn_item_setup(item: Node) -> void:
	# Call base implementation first
	super._post_spawn_item_setup(item)
	
	# Item-specific setup can be added here in the future
	# For now, all logic is handled by the base class


## Item-specific property validation
func _validate_item_properties(item: Node, custom_properties: Dictionary) -> bool:
	# Basic validation - can be extended for item-specific checks
	if not is_instance_valid(item):
		return false
	
	# Validate critical item properties
	if custom_properties.has("wall_direction") and not item.get_node_or_null("WallAttachmentComponent"):
		print("WARNING ItemSpawnData: wall_direction specified but no WallAttachmentComponent found")
		return false
	
	return true


## Configures tiny items with data path and amount
func _configure_tiny_item(item: Node, custom_properties: Dictionary) -> void:
	# Check if this is a tiny item that needs configuration
	if not item.get_script():
		return
	
	var script_name = item.get_script().get_global_name()
	if script_name != "TinyItem":
		return
	
	# Configure tiny item properties
	var item_data_path = custom_properties.get("item_data_path", "")
	var tiny_item_amount = custom_properties.get("tiny_item_amount", 1)
	
	if not item_data_path.is_empty():
		item.item_data = load(item_data_path)
		item.amount = tiny_item_amount
		
		print("Configured tiny item: %s with amount: %d" % [item_data_path, tiny_item_amount])

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------