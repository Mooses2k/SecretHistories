@tool
## Unified anchor-based spawning component
## Provides anchor-based spawning with integration to the spawn_data system
class_name AnchorSpawner
extends Node


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

## Emitted when spawning is complete
signal spawning_completed(spawned_items: Array)

## Emitted when an item is spawned at an anchor
signal item_spawned(item: Node, anchor: Node)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Path to the parent node containing anchor nodes
@export var anchors_parent: NodePath

## Maximum number of items to spawn (legacy compatibility)
@export var max_items_to_spawn: int = 5

## Array of AnchorSpawnData resources for spawning
@export var spawn_data_list: Array[AnchorSpawnData] = []

## Whether to spawn items automatically on ready
@export var auto_spawn_on_ready: bool = true

## Random seed for spawning (0 = use random seed)
@export var spawn_seed: int = 0

## Wall piece configuration - enables wall-based spawning
@export var enable_wall_piece_spawning: bool = false

## Wall direction for wall piece spawning (-1 = auto-detect)
@export var wall_direction: int = -1

## Whether to discover PlacementAnchors on wall pieces
@export var discover_placement_anchors: bool = true

## Whether to enable Wall Object spawning on walls
@export var enable_wall_object_spawning: bool = false

## Whether to enable Wall Object spawning on pillars (existing functionality)
@export var enable_pillar_object_spawning: bool = true

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng: RandomNumberGenerator
var _has_spawned: bool = false

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	if auto_spawn_on_ready:
		spawn_items()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Main spawning method - spawns all configured spawn data
func spawn_items() -> Array:
	if _has_spawned:
		return []
	
	_setup_rng()
	var all_spawned_items: Array = []
	var anchors := get_all_available_anchors()  # Use enhanced anchor discovery
	
	if anchors.is_empty():
		print("AnchorSpawner: No valid anchors found at path: %s" % anchors_parent)
		if enable_wall_piece_spawning:
			print("AnchorSpawner: Wall piece spawning enabled but no wall piece anchors found")
		return []
	
	print("AnchorSpawner: Found %d total anchors (%d standard, %d wall piece)" % [
		anchors.size(),
		_get_filtered_anchors().size(),
		_get_wall_piece_anchors().size()
	])
	
	# Handle legacy spawnable_items from owner (sarcophagus compatibility)
	_handle_legacy_spawnable_items(anchors, all_spawned_items)
	
	# Process configured spawn data
	for spawn_data in spawn_data_list:
		if not spawn_data:
			continue
		
		# Configure OnWallSpawnData if needed (check by class name to avoid type errors)
		if spawn_data.get_script() and spawn_data.get_script().get_global_name() == "OnWallSpawnData":
			_configure_on_wall_spawn_data(spawn_data)
		
		var spawned_items := spawn_data.spawn_at_anchors(anchors, _rng, true)
		all_spawned_items.append_array(spawned_items)
		
		# Emit signals for each spawned item
		for i in spawned_items.size():
			var item = spawned_items[i]
			var anchor = anchors[i % anchors.size()]  # Safe indexing
			item_spawned.emit(item, anchor)
	
	_has_spawned = true
	spawning_completed.emit(all_spawned_items)
	return all_spawned_items


## Spawns items using specific spawn data
func spawn_with_data(spawn_data: AnchorSpawnData) -> Array:
	if not spawn_data:
		return []
	
	_setup_rng()
	var anchors := _get_filtered_anchors()
	
	if anchors.is_empty():
		return []
	
	var spawned_items := spawn_data.spawn_at_anchors(anchors, _rng, true)
	
	# Emit signals for spawned items
	for i in spawned_items.size():
		var item = spawned_items[i]
		var anchor = anchors[i % anchors.size()]
		item_spawned.emit(item, anchor)
	
	return spawned_items


## Adds spawn data to the list
func add_spawn_data(spawn_data: AnchorSpawnData) -> void:
	if spawn_data and not spawn_data in spawn_data_list:
		spawn_data_list.append(spawn_data)


## Removes spawn data from the list
func remove_spawn_data(spawn_data: AnchorSpawnData) -> void:
	spawn_data_list.erase(spawn_data)


## Clears all spawn data
func clear_spawn_data() -> void:
	spawn_data_list.clear()


## Gets all available anchors
func get_available_anchors() -> Array:
	return _get_filtered_anchors()


## Gets all available anchors including wall piece anchors
func get_all_available_anchors() -> Array:
	var all_anchors: Array = []
	
	# Get standard anchors
	all_anchors.append_array(_get_filtered_anchors())
	
	# Get wall piece anchors if enabled
	if enable_wall_piece_spawning:
		all_anchors.append_array(_get_wall_piece_anchors())
	
	return all_anchors


## Configure wall piece spawning
func configure_wall_piece_spawning(enabled: bool, wall_dir: int = -1, discover_anchors: bool = true, wall_objects: bool = false, pillar_objects: bool = true) -> void:
	enable_wall_piece_spawning = enabled
	wall_direction = wall_dir
	discover_placement_anchors = discover_anchors
	enable_wall_object_spawning = wall_objects
	enable_pillar_object_spawning = pillar_objects


## Discovers PlacementAnchors on wall pieces
func discover_wall_piece_anchors() -> Array:
	return _get_wall_piece_anchors()


## Resets spawning state to allow re-spawning
func reset_spawning() -> void:
	_has_spawned = false
	
	# Reset spawn data states
	for spawn_data in spawn_data_list:
		if spawn_data:
			spawn_data.reset_used_anchors()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## Sets up the random number generator
func _setup_rng() -> void:
	_rng = RandomNumberGenerator.new()
	if spawn_seed != 0:
		_rng.seed = spawn_seed
	else:
		_rng.randomize()


## Gets and filters anchor nodes
func _get_filtered_anchors() -> Array:
	if anchors_parent.is_empty():
		return []
	
	var parent_node := get_node_or_null(anchors_parent)
	if not parent_node:
		print("AnchorSpawner: Could not find anchors parent at path: %s" % anchors_parent)
		return []
	
	return _filter_anchor_nodes(parent_node.get_children())


## Filters anchor nodes to only include valid Marker3D nodes
func _filter_anchor_nodes(anchor_nodes: Array) -> Array:
	var filtered_list: Array = []
	
	for anchor_node in anchor_nodes:
		if anchor_node is Marker3D:
			filtered_list.append(anchor_node)
	
	return filtered_list


## Gets anchors from wall pieces (PlacementAnchors and Wall Object spawn points)
func _get_wall_piece_anchors() -> Array:
	var wall_anchors: Array = []
	
	if not enable_wall_piece_spawning:
		return wall_anchors
	
	# Search for wall pieces in the scene
	var wall_pieces := _find_wall_pieces()
	
	for wall_piece in wall_pieces:
		if discover_placement_anchors:
			# Find PlacementAnchors on wall pieces
			var placement_anchors := _find_placement_anchors_on_node(wall_piece)
			wall_anchors.append_array(placement_anchors)
		
		if enable_wall_object_spawning:
			# Find Wall Object spawn points on wall pieces
			var wall_object_anchors := _find_wall_object_anchors_on_node(wall_piece)
			wall_anchors.append_array(wall_object_anchors)
	
	return wall_anchors


## Finds wall pieces in the scene tree
func _find_wall_pieces() -> Array:
	var wall_pieces: Array = []
	
	# This is a placeholder for future wall piece discovery
	# When wall pieces are implemented, this method will search for them
	# For now, we can search for nodes with specific naming patterns or components
	
	var root_node := get_tree().current_scene
	if root_node:
		wall_pieces = _search_for_wall_pieces_recursive(root_node)
	
	return wall_pieces


## Recursively searches for wall pieces
func _search_for_wall_pieces_recursive(node: Node) -> Array:
	var wall_pieces: Array = []
	
	# Check if this node is a wall piece
	if _is_wall_piece(node):
		wall_pieces.append(node)
	
	# Search children
	for child in node.get_children():
		wall_pieces.append_array(_search_for_wall_pieces_recursive(child))
	
	return wall_pieces


## Checks if a node is a wall piece
func _is_wall_piece(node: Node) -> bool:
	# Check for wall piece indicators
	# This could be based on node name, script, or specific components
	
	# Check for wall piece naming pattern
	if "wall" in node.name.to_lower() and ("piece" in node.name.to_lower() or "niche" in node.name.to_lower()):
		return true
	
	# Check for specific wall piece script or class
	if node.get_script():
		var script_name = node.get_script().get_global_name()
		if script_name and "wall" in script_name.to_lower() and "piece" in script_name.to_lower():
			return true
	
	# Check for AnchorSpawner component (wall pieces might have their own spawners)
	if node.has_node("AnchorSpawner"):
		return true
	
	return false


## Finds PlacementAnchors on a wall piece node
func _find_placement_anchors_on_node(node: Node) -> Array:
	var anchors: Array = []
	
	# Search recursively for PlacementAnchor nodes
	var queue: Array = [node]
	while not queue.is_empty():
		var current_node = queue.pop_front()
		
		if current_node is PlacementAnchor:
			anchors.append(current_node)
		
		for child in current_node.get_children():
			queue.append(child)
	
	return anchors


## Finds Wall Object anchor points on a wall piece node
func _find_wall_object_anchors_on_node(node: Node) -> Array:
	var anchors: Array = []
	
	# Search for Marker3D nodes that could serve as Wall Object spawn points
	var queue: Array = [node]
	while not queue.is_empty():
		var current_node = queue.pop_front()
		
		# Look for Marker3D nodes with wall object indicators
		if current_node is Marker3D and _is_wall_object_anchor(current_node):
			anchors.append(current_node)
		
		for child in current_node.get_children():
			queue.append(child)
	
	return anchors


## Checks if a Marker3D is suitable for Wall Object spawning
func _is_wall_object_anchor(marker: Marker3D) -> bool:
	# Check naming patterns for wall object anchors
	var name_lower = marker.name.to_lower()
	
	if "wall" in name_lower and ("object" in name_lower or "spawn" in name_lower or "mount" in name_lower):
		return true
	
	if "painting" in name_lower or "sconce" in name_lower or "tapestry" in name_lower:
		return true
	
	return false


## Handles legacy spawnable_items from owner (for sarcophagus compatibility)
func _handle_legacy_spawnable_items(anchors: Array, all_spawned_items: Array) -> void:
	if not owner or not owner.has_method("get") or not owner.get("spawnable_items"):
		return
	
	var spawnable_items = owner.get("spawnable_items")
	if not spawnable_items or spawnable_items.is_empty():
		return
	
	var available_anchors := anchors.duplicate()
	
	for item_path in spawnable_items:
		if available_anchors.is_empty():
			break
		
		var random_num := _rng.randi() % available_anchors.size()
		var chosen_anchor = available_anchors[random_num]
		
		# Handle bad refs in the loot list
		var loaded = load(item_path)
		if not loaded or not (loaded is PackedScene):
			continue
		
		var new_item = loaded.instantiate()
		if not is_instance_valid(new_item):
			continue
		
		# Special handling for ShardOfTheComet (preserve original logic)
		if new_item.get_script() and new_item.get_script().get_global_name() == "ShardOfTheComet":
			if GameManager.game.shard_has_spawned:
				new_item.queue_free()
				continue
			else:
				GameManager.game.shard_has_spawned = true
				chosen_anchor.add_child(new_item)
				new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
		else:
			# Standard item spawning logic
			new_item.position = chosen_anchor.position
			if new_item.has_method("get") and new_item.get("placement_position"):
				var placement_position = new_item.get("placement_position")
				if placement_position:
					new_item.position += placement_position.position
			
			new_item.set_item_state(GlobalConsts.ItemState.DROPPED)
			get_parent().get_parent().add_child(new_item)
			available_anchors.remove_at(random_num)
		
		# Handle lighting items (preserve original logic)
		if new_item.get_script():
			var script_name = new_item.get_script().get_global_name()
			if script_name == "CandleItem" or script_name == "CandelabraItem":
				new_item.light()
		
		all_spawned_items.append(new_item)
		item_spawned.emit(new_item, chosen_anchor)

## Configures OnWallSpawnData with AnchorSpawner settings
func _configure_on_wall_spawn_data(on_wall_data: AnchorSpawnData) -> void:
	# Configure wall direction
	if wall_direction != -1 and on_wall_data.has_method("set"):
		on_wall_data.set("wall_direction", wall_direction)
	
	# Configure Wall Object spawning capabilities
	if on_wall_data.has_method("set"):
		if on_wall_data.has_method("get") and on_wall_data.get("allow_wall_spawning") != null:
			on_wall_data.set("allow_wall_spawning", enable_wall_object_spawning)
		if on_wall_data.has_method("get") and on_wall_data.get("allow_pillar_spawning") != null:
			on_wall_data.set("allow_pillar_spawning", enable_pillar_object_spawning)
	
	# Call the integration interface
	on_wall_data.configure_for_anchor_spawner(self)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
