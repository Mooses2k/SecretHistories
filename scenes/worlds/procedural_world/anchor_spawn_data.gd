@tool
## Base class for anchor-based spawning systems
## Provides core anchor management and selection strategies
class_name AnchorSpawnData
extends SpawnData


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

## Selection strategies for choosing anchors
enum SelectionStrategy {
	RANDOM,      ## Random selection from available anchors
	SEQUENTIAL,  ## Sequential selection in order
	WEIGHTED,    ## Weighted selection based on anchor properties
}

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Strategy for selecting anchors
@export var selection_strategy: SelectionStrategy = SelectionStrategy.RANDOM

## Whether to remove used anchors from the pool
@export var remove_used_anchors: bool = true

## Maximum distance between spawned objects (0 = no limit)
@export var max_spawn_distance: float = 0.0

## Minimum distance between spawned objects (0 = no limit)
@export var min_spawn_distance: float = 0.0

#--- private variables - order: export > normal var > onready -------------------------------------

var _used_anchors: Array = []
var _anchor_weights: Dictionary = {}

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	super._init()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Core anchor-based spawning implementation
func spawn_at_anchors(anchors: Array, rng: RandomNumberGenerator = null, should_log := false) -> Array:
	if _has_spawned:
		return []
	
	if anchors.is_empty():
		if should_log:
			print("AnchorSpawnData: No anchors provided for spawning")
		return []
	
	var item_scene: PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		print("ERROR AnchorSpawnData: Failed to load scene: %s" % scene_path)
		return []
	
	var spawned_items: Array = []
	var available_anchors := _filter_available_anchors(anchors)
	var selected_anchors := _select_anchors(available_anchors, rng)
	
	for index in selected_anchors.size():
		var anchor = selected_anchors[index]
		var spawned_item = _spawn_at_anchor(anchor, index, item_scene)
		
		if spawned_item:
			spawned_items.append(spawned_item)
			if remove_used_anchors:
				_used_anchors.append(anchor)
	
	_has_spawned = true
	return spawned_items


## Sets weights for anchor selection when using WEIGHTED strategy
func set_anchor_weights(weights: Dictionary) -> void:
	_anchor_weights = weights


## Adds weight for a specific anchor
func set_anchor_weight(anchor: Node, weight: float) -> void:
	_anchor_weights[anchor] = weight


## Gets the weight of an anchor (default 1.0)
func get_anchor_weight(anchor: Node) -> float:
	return _anchor_weights.get(anchor, 1.0)


## Clears used anchors list
func reset_used_anchors() -> void:
	_used_anchors.clear()


## Checks if an anchor is available for spawning
func is_anchor_available(anchor: Node) -> bool:
	if not is_instance_valid(anchor):
		return false
	
	if remove_used_anchors and anchor in _used_anchors:
		return false
	
	return true


## Gets all available anchors from the provided list
func get_available_anchors(anchors: Array) -> Array:
	return _filter_available_anchors(anchors)


## Validates anchor compatibility with spawn requirements
func validate_anchor(anchor: Node) -> bool:
	if not is_instance_valid(anchor):
		return false
	
	# Basic validation - anchor should be a Node3D for positioning
	if not anchor is Node3D:
		return false
	
	return true


## Gets the spawn position for an anchor
func get_anchor_spawn_position(anchor: Node) -> Vector3:
	if anchor is Node3D:
		var anchor_node3d = anchor as Node3D
		return anchor_node3d.global_position
	
	return Vector3.ZERO


## Interface for AnchorSpawner integration
## This method will be called by the future AnchorSpawner class
func configure_for_anchor_spawner(spawner_node: Node) -> void:
	# This method provides a hook for AnchorSpawner-specific configuration
	# Implementation will be added when AnchorSpawner is created in later phases
	pass

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## Filters anchors based on availability and validation
func _filter_available_anchors(anchors: Array) -> Array:
	var available: Array = []
	
	for anchor in anchors:
		if is_anchor_available(anchor) and validate_anchor(anchor):
			available.append(anchor)
	
	return available


## Selects anchors based on the configured strategy
func _select_anchors(available_anchors: Array, rng: RandomNumberGenerator) -> Array:
	if available_anchors.is_empty():
		return []
	
	var spawn_count := mini(amount, available_anchors.size())
	var selected: Array = []
	
	match selection_strategy:
		SelectionStrategy.RANDOM:
			selected = _select_random_anchors(available_anchors, spawn_count, rng)
		SelectionStrategy.SEQUENTIAL:
			selected = _select_sequential_anchors(available_anchors, spawn_count)
		SelectionStrategy.WEIGHTED:
			selected = _select_weighted_anchors(available_anchors, spawn_count, rng)
		_:
			# Fallback to random
			selected = _select_random_anchors(available_anchors, spawn_count, rng)
	
	# Apply distance constraints if specified
	if min_spawn_distance > 0.0 or max_spawn_distance > 0.0:
		selected = _apply_distance_constraints(selected)
	
	return selected


## Random anchor selection
func _select_random_anchors(anchors: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var selected: Array = []
	var available := anchors.duplicate()
	
	for i in count:
		if available.is_empty():
			break
		
		var index: int = 0
		if rng:
			index = rng.randi() % available.size()
		
		selected.append(available[index])
		available.remove_at(index)
	
	return selected


## Sequential anchor selection
func _select_sequential_anchors(anchors: Array, count: int) -> Array:
	var selected: Array = []
	
	for i in mini(count, anchors.size()):
		selected.append(anchors[i])
	
	return selected


## Weighted anchor selection
func _select_weighted_anchors(anchors: Array, count: int, rng: RandomNumberGenerator) -> Array:
	if _anchor_weights.is_empty():
		# No weights defined, fall back to random
		return _select_random_anchors(anchors, count, rng)
	
	var selected: Array = []
	var available := anchors.duplicate()
	
	for i in count:
		if available.is_empty():
			break
		
		var chosen_anchor = _select_weighted_anchor(available, rng)
		if chosen_anchor:
			selected.append(chosen_anchor)
			available.erase(chosen_anchor)
	
	return selected


## Selects a single anchor using weighted probability
func _select_weighted_anchor(anchors: Array, rng: RandomNumberGenerator) -> Node:
	var total_weight: float = 0.0
	
	# Calculate total weight
	for anchor in anchors:
		total_weight += get_anchor_weight(anchor)
	
	if total_weight <= 0.0:
		# No valid weights, select randomly
		if rng and not anchors.is_empty():
			return anchors[rng.randi() % anchors.size()]
		return null
	
	# Select based on weight
	var random_value: float = 0.0
	if rng:
		random_value = rng.randf() * total_weight
	
	var current_weight: float = 0.0
	for anchor in anchors:
		current_weight += get_anchor_weight(anchor)
		if random_value <= current_weight:
			return anchor
	
	# Fallback to last anchor
	return anchors[-1] if not anchors.is_empty() else null


## Applies distance constraints to selected anchors
func _apply_distance_constraints(selected_anchors: Array) -> Array:
	if selected_anchors.size() <= 1:
		return selected_anchors
	
	var constrained: Array = []
	
	for anchor in selected_anchors:
		var anchor_pos := get_anchor_spawn_position(anchor)
		var valid := true
		
		# Check distance constraints against already selected anchors
		for existing_anchor in constrained:
			var existing_pos := get_anchor_spawn_position(existing_anchor)
			var distance := anchor_pos.distance_to(existing_pos)
			
			if min_spawn_distance > 0.0 and distance < min_spawn_distance:
				valid = false
				break
			
			if max_spawn_distance > 0.0 and distance > max_spawn_distance:
				valid = false
				break
		
		if valid:
			constrained.append(anchor)
	
	return constrained


## Spawns an item at a specific anchor
func _spawn_at_anchor(anchor: Node, index: int, item_scene: PackedScene) -> Node:
	var item = item_scene.instantiate()
	if not is_instance_valid(item):
		print("ERROR AnchorSpawnData: Failed to instantiate scene: %s" % scene_path)
		return null
	
	# Position item at anchor
	if item is Node3D and anchor is Node3D:
		var node3d_item = item as Node3D
		var spawn_position := get_anchor_spawn_position(anchor)
		node3d_item.global_position = spawn_position
		
		# Apply stored transform rotation if available
		if index < _transforms.size():
			var stored_transform := _transforms[index] as Transform3D
			node3d_item.transform.basis = stored_transform.basis
	
	# Apply custom properties
	if index < _custom_properties.size():
		var custom_properties := _custom_properties[index] as Dictionary
		_apply_custom_properties(item, custom_properties)
	
	# Add to scene tree
	var spawn_parent: Node = _get_spawn_parent(anchor)
	spawn_parent.add_child(item, true)
	
	# Apply post-spawn setup
	_post_spawn_item_setup(item)
	
	# Handle anchor-specific properties
	if index < _custom_properties.size():
		_handle_anchor_specific_properties(item, anchor, _custom_properties[index])
	
	return item


## Gets the appropriate parent node for spawning
func _get_spawn_parent(anchor: Node) -> Node:
	# Try to use anchor's parent, fallback to anchor itself
	var parent := anchor.get_parent()
	return parent if parent else anchor


## Handles anchor-specific property setup
func _handle_anchor_specific_properties(item: Node, anchor: Node, custom_properties: Dictionary) -> void:
	# This method can be overridden by subclasses for specific anchor handling
	# For now, delegate to base wall object handling
	_handle_wall_object_properties(item, custom_properties)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------