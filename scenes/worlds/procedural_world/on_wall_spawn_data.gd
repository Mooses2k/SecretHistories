@tool
## On-Wall Foundation spawn data implementation
## Extends AnchorSpawnData to support wall niche spawning and Wall Object spawning
## Handles wall direction, orientation, and positioning for wall-mounted items
##
## NOTE: Niche spawning (NICHE_CALCULATED) currently only works correctly for SOUTH walls.
## Other wall directions have positioning issues and are not yet supported.
class_name OnWallSpawnData
extends AnchorSpawnData


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

## Wall spawn types supported by this system
enum WallSpawnType {
	NICHE_CALCULATED,  ## Use calculated positioning for wall niches (currently only works for SOUTH walls)
	WALL_OBJECT,       ## Use Wall Object system (paintings, sconces on walls AND pillars)
}

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Type of wall spawning to use
@export var wall_spawn_type: WallSpawnType = WallSpawnType.NICHE_CALCULATED

## Wall direction for proper orientation (-1 = auto-detect)
@export var wall_direction: int = -1

## Whether Wall Objects can spawn on pillars (in addition to walls)
@export var allow_pillar_spawning: bool = true

## Whether Wall Objects can spawn on walls (in addition to pillars)
@export var allow_wall_spawning: bool = true

## Minimum distance from wall surface for Wall Object spawning
@export var wall_offset_distance: float = 0.225

## Height above floor for wall mounting
@export var wall_mount_height: float = 1.6

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	super._init()
	# Set appropriate default selection strategy for wall spawning
	selection_strategy = SelectionStrategy.RANDOM


## Override spawn_item_in to handle calculated positioning for wall niches
func spawn_item_in(node: Node, should_log := false) -> void:
	if _has_spawned:
		return
	
	# For niche spawning, use calculated positioning
	if wall_spawn_type == WallSpawnType.NICHE_CALCULATED:
		_spawn_niche_items_with_calculated_positioning(node, should_log)
	else:
		# Use base implementation for Wall Object spawning
		super.spawn_item_in(node, should_log)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Override spawn_at_anchors to handle Wall Object spawning
func spawn_at_anchors(anchors: Array, rng: RandomNumberGenerator = null, should_log := false) -> Array:
	if _has_spawned:
		return []
	
	if anchors.is_empty():
		if should_log:
			print("OnWallSpawnData: No anchors provided for spawning")
		return []
	
	var spawned_items: Array = []
	
	match wall_spawn_type:
		WallSpawnType.NICHE_CALCULATED:
			# Niche spawning uses spawn_item_in() instead of spawn_at_anchors()
			if should_log:
				print("OnWallSpawnData: Niche spawning should use spawn_item_in() not spawn_at_anchors()")
			return []
		WallSpawnType.WALL_OBJECT:
			spawned_items = _spawn_as_wall_objects(anchors, rng, should_log)
		_:
			if should_log:
				print("OnWallSpawnData: Unknown wall spawn type: %d" % wall_spawn_type)
			return []
	
	_has_spawned = true
	return spawned_items


## Configure for Wall Object spawning (paintings, sconces)
func configure_for_wall_objects(wall_dir: int = -1, allow_pillars: bool = true, allow_walls: bool = true) -> void:
	wall_spawn_type = WallSpawnType.WALL_OBJECT
	wall_direction = wall_dir
	allow_pillar_spawning = allow_pillars
	allow_wall_spawning = allow_walls


## Validates anchor for wall-specific requirements
func validate_anchor(anchor: Node) -> bool:
	if not super.validate_anchor(anchor):
		return false
	
	match wall_spawn_type:
		WallSpawnType.NICHE_CALCULATED:
			# Niche spawning doesn't use anchors
			return false
		WallSpawnType.WALL_OBJECT:
			return _validate_wall_object_anchor(anchor)
		_:
			return false


## Gets wall direction from anchor or uses configured direction
func get_wall_direction_for_anchor(anchor: Node) -> int:
	# Try to get wall direction from anchor's custom properties first
	if anchor.has_method("get") and anchor.get("wall_direction") != null:
		return anchor.get("wall_direction")
	
	# Use configured wall direction
	if wall_direction != -1:
		return wall_direction
	
	# Try to detect from anchor's parent or position
	return _detect_wall_direction_from_anchor(anchor)


## Interface for AnchorSpawner integration - enhanced for wall pieces
func configure_for_anchor_spawner(spawner_node: Node) -> void:
	super.configure_for_anchor_spawner(spawner_node)
	
	# Additional wall-specific configuration can be added here
	# This provides integration points for future wall piece discovery

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## Spawns items as Wall Objects (wall and pillar mounting)
func _spawn_as_wall_objects(anchors: Array, rng: RandomNumberGenerator, should_log: bool) -> Array:
	if should_log:
		print("OnWallSpawnData: Using Wall Object spawning mode")
	
	var item_scene: PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		print("ERROR OnWallSpawnData: Failed to load scene: %s" % scene_path)
		return []
	
	var spawned_items: Array = []
	var available_anchors := _filter_available_anchors(anchors)
	var selected_anchors := _select_anchors(available_anchors, rng)
	
	for index in selected_anchors.size():
		var anchor = selected_anchors[index]
		var spawned_item = _spawn_wall_object_at_anchor(anchor, index, item_scene, rng)
		
		if spawned_item:
			spawned_items.append(spawned_item)
			if remove_used_anchors:
				_used_anchors.append(anchor)
	
	return spawned_items


## Spawns a Wall Object at a specific anchor
func _spawn_wall_object_at_anchor(anchor: Node, index: int, item_scene: PackedScene, rng: RandomNumberGenerator) -> Node:
	var item = item_scene.instantiate()
	if not is_instance_valid(item):
		print("ERROR OnWallSpawnData: Failed to instantiate scene: %s" % scene_path)
		return null
	
	# Position and orient item for wall mounting
	if item is Node3D and anchor is Node3D:
		var node3d_item = item as Node3D
		var wall_dir := get_wall_direction_for_anchor(anchor)
		
		# Calculate wall-mounted position
		var spawn_position := _calculate_wall_spawn_position(anchor, wall_dir)
		node3d_item.global_position = spawn_position
		
		# Apply wall-oriented rotation
		var wall_rotation := _calculate_wall_rotation(wall_dir)
		node3d_item.transform.basis = Basis.from_euler(wall_rotation)
		
		# Apply stored transform rotation if available (combines with wall rotation)
		if index < _transforms.size():
			var stored_transform := _transforms[index] as Transform3D
			node3d_item.transform.basis = node3d_item.transform.basis * stored_transform.basis
	
	# Apply custom properties including wall-specific ones
	if index < _custom_properties.size():
		var custom_properties := _custom_properties[index] as Dictionary
		_apply_wall_object_properties(item, anchor, custom_properties)
		_apply_custom_properties(item, custom_properties)
	
	# Add to scene tree
	var spawn_parent: Node = _get_spawn_parent(anchor)
	spawn_parent.add_child(item, true)
	
	# Apply post-spawn setup
	_post_spawn_item_setup(item)
	
	return item


## Validates anchor for Wall Object spawning
func _validate_wall_object_anchor(anchor: Node) -> bool:
	# Wall Objects can use various anchor types
	# Marker3D for pillar positions, PlacementAnchor for wall positions, etc.
	if anchor is Marker3D or anchor is PlacementAnchor:
		return true
	
	return false


## Detects wall direction from anchor context
func _detect_wall_direction_from_anchor(anchor: Node) -> int:
	# Try to detect wall direction from anchor's parent or position
	# This is a placeholder for future wall piece integration
	
	# For now, return a default direction
	return 0  # WorldData.Direction.NORTH


## Calculates spawn position for wall mounting
func _calculate_wall_spawn_position(anchor: Node, wall_dir: int) -> Vector3:
	var base_position := get_anchor_spawn_position(anchor)
	
	# Add wall offset based on direction
	var wall_offset := _get_wall_offset_for_direction(wall_dir)
	var offset_distance := wall_offset * wall_offset_distance
	
	# Add height offset for wall mounting
	var final_position := base_position + offset_distance
	final_position.y += wall_mount_height
	
	return final_position


## Calculates rotation for wall mounting based on direction
func _calculate_wall_rotation(wall_dir: int) -> Vector3:
	match wall_dir:
		0:  # WorldData.Direction.NORTH
			return Vector3(0, 0, 0)
		1:  # WorldData.Direction.EAST
			return Vector3(0, PI * 1.5, 0)
		2:  # WorldData.Direction.SOUTH
			return Vector3(0, PI, 0)
		3:  # WorldData.Direction.WEST
			return Vector3(0, PI * 0.5, 0)
		_:
			return Vector3.ZERO


## Gets wall offset vector for direction
func _get_wall_offset_for_direction(wall_dir: int) -> Vector3:
	match wall_dir:
		0:  # WorldData.Direction.NORTH
			return Vector3(0, 0, -1)
		1:  # WorldData.Direction.EAST
			return Vector3(1, 0, 0)
		2:  # WorldData.Direction.SOUTH
			return Vector3(0, 0, 1)
		3:  # WorldData.Direction.WEST
			return Vector3(-1, 0, 0)
		_:
			return Vector3(0, 0, -1)


## Applies wall-specific properties to spawned Wall Objects
func _apply_wall_object_properties(item: Node, anchor: Node, custom_properties: Dictionary) -> void:
	var wall_dir := get_wall_direction_for_anchor(anchor)
	
	# Set wall direction for WallAttachmentComponent
	custom_properties["wall_direction"] = wall_dir
	
	# Add anchor position for reference
	custom_properties["anchor_position"] = get_anchor_spawn_position(anchor)
	
	# Add wall spawn type for debugging
	custom_properties["wall_spawn_type"] = "OnWallSpawnData"


## Spawns niche items using calculated positioning (special case for wall niches)
## NOTE: Currently only works correctly for SOUTH walls
func _spawn_niche_items_with_calculated_positioning(node: Node, should_log: bool) -> void:
	# Get stored metadata from custom properties
	var cell_index: int = -1
	var wall_direction: int = -1
	var wall_tile_id: int = -1
	
	# Extract metadata from first item's custom properties
	if not _custom_properties.is_empty():
		var custom_props := _custom_properties[0] as Dictionary
		cell_index = custom_props.get("cell_index", -1)
		wall_direction = custom_props.get("wall_direction", -1)
		wall_tile_id = custom_props.get("wall_tile", -1)
	
	if cell_index == -1 or wall_direction == -1:
		print("OnWallSpawnData ERROR: Missing cell_index or wall_direction metadata")
		return
	
	# Get WorldData for coordinate conversion
	var world_data := _get_world_data_from_node(node)
	if not world_data:
		print("OnWallSpawnData ERROR: Could not find WorldData for coordinate conversion")
		return
	
	# Calculate precise niche position using mathematical approach
	var niche_position := _calculate_niche_position(world_data, cell_index, wall_direction)
	
	# Spawn items at the calculated niche position
	_spawn_items_at_calculated_position(niche_position, node, should_log)


## Finds the specific GridMap tile instance at the given cell and wall direction
func _find_gridmap_tile_at_cell(world_node: Node, cell_index: int, wall_direction: int) -> Node:
	# Navigate to the GridMaps node using runtime path structure
	# Runtime path: root/Game/World/ProceduralWorld/Gridmaps
	var gridmaps_node: Node = null
	
	# Try multiple approaches to find Gridmaps node
	# Method 1: Direct child (if world_node is ProceduralWorld)
	gridmaps_node = world_node.get_node_or_null("Gridmaps")
	
	# Method 2: Navigate up to find ProceduralWorld then down to Gridmaps
	if not gridmaps_node:
		var current_node := world_node
		while current_node:
			var procedural_world := current_node.get_node_or_null("ProceduralWorld")
			if procedural_world:
				gridmaps_node = procedural_world.get_node_or_null("Gridmaps")
				break
			current_node = current_node.get_parent()
	
	# Method 3: Try to find it in the scene tree by walking up to Game/World
	if not gridmaps_node:
		var current_node := world_node
		while current_node:
			if current_node.name == "World" or current_node.name == "ProceduralWorld":
				gridmaps_node = current_node.get_node_or_null("Gridmaps")
				if gridmaps_node:
					break
			current_node = current_node.get_parent()
	
	if not gridmaps_node:
		print("OnWallSpawnData ERROR: Could not find Gridmaps node. Searched from: %s" % world_node.name)
		return null
	
	# Get the appropriate wall GridMap based on direction
	var wall_gridmap: GridMap = null
	match wall_direction:
		0:  # WorldData.Direction.NORTH
			wall_gridmap = gridmaps_node.get_node_or_null("wall_zn") as GridMap
		1:  # WorldData.Direction.EAST
			wall_gridmap = gridmaps_node.get_node_or_null("wall_xp") as GridMap
		2:  # WorldData.Direction.SOUTH
			wall_gridmap = gridmaps_node.get_node_or_null("wall_zp") as GridMap
		3:  # WorldData.Direction.WEST
			wall_gridmap = gridmaps_node.get_node_or_null("wall_xn") as GridMap
		_:
			print("OnWallSpawnData ERROR: Invalid wall direction: %d" % wall_direction)
			return null
	
	if not wall_gridmap:
		print("OnWallSpawnData ERROR: Could not find wall GridMap for direction %d" % wall_direction)
		return null
	
	# Get world data to convert cell_index to grid coordinates
	var world_data := _get_world_data_from_node(world_node)
	if not world_data:
		print("OnWallSpawnData ERROR: Could not find WorldData")
		return null
	
	# Convert cell_index to grid coordinates
	var coords := world_data.get_int_position_from_cell_index(cell_index)
	var grid_pos := Vector3(coords[0], 0, coords[1])
	
	# Get the tile item ID at this position
	var tile_item_id := wall_gridmap.get_cell_item(grid_pos)
	if tile_item_id == -1:
		print("OnWallSpawnData ERROR: No tile found at grid position %s" % grid_pos)
		return null
	
	# Find the instantiated tile node - GridMap creates child nodes for each tile
	# The tile instances are typically direct children of the GridMap
	for child in wall_gridmap.get_children():
		# Check if this child corresponds to our grid position
		if _is_tile_at_position(child, grid_pos, wall_gridmap):
			return child
	
	print("OnWallSpawnData ERROR: Could not find instantiated tile node at position %s" % grid_pos)
	return null


## Checks if a tile node is at the specified grid position
func _is_tile_at_position(tile_node: Node, grid_pos: Vector3, gridmap: GridMap) -> bool:
	if not tile_node is Node3D:
		return false
	
	var tile_node3d := tile_node as Node3D
	var expected_world_pos := gridmap.map_to_local(grid_pos)
	var actual_world_pos := tile_node3d.global_position
	
	# Allow for small floating point differences
	var distance := expected_world_pos.distance_to(actual_world_pos)
	return distance < 0.1


## Gets WorldData from the world node
func _get_world_data_from_node(world_node: Node) -> WorldData:
	# Method 1: Check if world_node has world_data property directly
	if world_node.has_method("get") and world_node.get("world_data"):
		var data = world_node.get("world_data")
		if data is WorldData:
			return data as WorldData
	
	# Method 2: If world_node is ProceduralWorld, check parent (World) for world_data
	var parent_node := world_node.get_parent()
	if parent_node and parent_node.name == "World":
		if parent_node.has_method("get") and parent_node.get("world_data"):
			var data = parent_node.get("world_data")
			if data is WorldData:
				return data as WorldData
	
	# Method 3: Walk up the tree looking for World node with world_data
	var current_node := world_node
	while current_node:
		if current_node.name == "World":
			if current_node.has_method("get") and current_node.get("world_data"):
				var data = current_node.get("world_data")
				if data is WorldData:
					return data as WorldData
		current_node = current_node.get_parent()
	
	# Method 4: Try legacy 'data' property as fallback
	current_node = world_node
	while current_node:
		if current_node.has_method("get") and current_node.get("data"):
			var data = current_node.get("data")
			if data is WorldData:
				return data as WorldData
		current_node = current_node.get_parent()
	
	return null


## NOTE: This is currently BROKEN for all niche walls except SOUTH
## Calculates the precise niche position using mathematical approach
func _calculate_niche_position(world_data: WorldData, cell_index: int, wall_direction: int) -> Vector3:
	# Get the cell center position (for double-tiles, this is the center of the 2x2 cell set)
	var cell_center := world_data.get_local_cell_position(cell_index)
	
	# Constants for niche positioning
	const NICHE_HEIGHT := 1.3  # 1.3m above floor
	const NICHE_OFFSET_FROM_CENTER := 1.45  # Distance from center towards wall (for 3m wide double-tiles)
	
	# Determine the direction vector TOWARDS the wall
	# Based on gridmaps.gd: wall_zn=NORTH, wall_xp=EAST, wall_zp=SOUTH, wall_xn=WEST
	# Coordinate system: +X = East, -X = West, +Z = South, -Z = North
	# The niche is IN the wall, so we move TOWARDS the wall surface (away from room center)
	var towards_wall_direction := Vector3.ZERO
	match wall_direction:
		0:  # NORTH wall (wall_zn) - niche faces INTO room (towards +Z), so move towards -Z
			towards_wall_direction = Vector3(0, 0, -1)
		1:  # EAST wall (wall_xp) - niche faces INTO room (towards -X), so move towards +X
			towards_wall_direction = Vector3(1, 0, 0)
		2:  # SOUTH wall (wall_zp) - niche faces INTO room (towards -Z), so move towards +Z
			towards_wall_direction = Vector3(0, 0, 1)
		3:  # WEST wall (wall_xn) - niche faces INTO room (towards +X), so move towards -X
			towards_wall_direction = Vector3(-1, 0, 0)
		_:
			print("OnWallSpawnData ERROR: Invalid wall direction: %d" % wall_direction)
			towards_wall_direction = Vector3(0, 0, 1)  # Default to south
	
	# Simple calculation: from center, move 1.45m towards the wall
	# For double-tiles (3m wide), the niche is 1.45m from center towards the wall
	var niche_position := cell_center + (towards_wall_direction * NICHE_OFFSET_FROM_CENTER)
	niche_position.y = NICHE_HEIGHT
	
	return niche_position


## Spawns items at the calculated niche position
func _spawn_items_at_calculated_position(niche_position: Vector3, world_node: Node, should_log: bool) -> void:
	var item_scene: PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		print("ERROR OnWallSpawnData: Failed to load scene: %s" % scene_path)
		return
	
	var spawn_count := amount
	
	for index in spawn_count:
		var item := item_scene.instantiate()
		
		if not is_instance_valid(item):
			print("ERROR OnWallSpawnData: Failed to instantiate scene: %s" % scene_path)
			continue
		
		# Position item at the calculated niche position
		if item is Node3D:
			var node3d_item := item as Node3D
			node3d_item.global_position = niche_position
			
			# Apply stored transform rotation if available
			if index < _transforms.size():
				var stored_transform := _transforms[index] as Transform3D
				node3d_item.transform.basis = stored_transform.basis
		
		# Apply custom properties
		if index < _custom_properties.size():
			var custom_properties := _custom_properties[index] as Dictionary
			_apply_custom_properties(item, custom_properties)
		
		# Add to scene tree
		world_node.add_child(item, true)
		
		# Apply post-spawn setup
		_post_spawn_item_setup(item)
	
	# Mark as spawned
	_has_spawned = true

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
