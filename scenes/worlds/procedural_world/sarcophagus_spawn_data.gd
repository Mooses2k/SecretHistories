@tool
## Sarcophagus-specific spawn data implementation
## Extends AnchorSpawnData with sarcophagus-specific logic for lid types, wall directions, and comet shard handling
class_name SarcophagusSpawnData
extends AnchorSpawnData


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

## Sarcophagus lid types (mirrors sarcophagus.gd PossibleLids)
enum LidType {
	EMPTY,
	PLAIN,
	KNIGHT,
	SAINT,
}

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Type of sarcophagus lid
@export var lid_type: LidType = LidType.EMPTY

## Wall direction for sarcophagus orientation
@export var wall_direction: int = -1

## Whether this sarcophagus can spawn comet shards
@export var can_spawn_comet_shard: bool = true

## Specific items that can spawn in this sarcophagus
@export var sarcophagus_items: PackedStringArray = []

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	super._init()
	# Set default selection strategy for sarcophagi
	selection_strategy = SelectionStrategy.RANDOM

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Override spawn_at_anchors to include sarcophagus-specific logic
func spawn_at_anchors(anchors: Array, rng: RandomNumberGenerator = null, should_log := false) -> Array:
	if _has_spawned:
		return []
	
	if anchors.is_empty():
		if should_log:
			print("SarcophagusSpawnData: No anchors provided for spawning")
		return []
	
	# Handle sarcophagus-specific spawning
	var spawned_items: Array = []
	var available_anchors := _filter_available_anchors(anchors)
	var selected_anchors := _select_anchors(available_anchors, rng)
	
	for index in selected_anchors.size():
		var anchor = selected_anchors[index]
		var spawned_item = _spawn_sarcophagus_item_at_anchor(anchor, index, rng)
		
		if spawned_item:
			spawned_items.append(spawned_item)
			if remove_used_anchors:
				_used_anchors.append(anchor)
	
	_has_spawned = true
	return spawned_items


## Sets up sarcophagus-specific properties
func configure_sarcophagus(lid: LidType, wall_dir: int, items: PackedStringArray) -> void:
	lid_type = lid
	wall_direction = wall_dir
	sarcophagus_items = items


## Gets a random lid type using RNG
static func get_random_lid_type(rng: RandomNumberGenerator) -> LidType:
	var lid_values := LidType.values()
	return lid_values[rng.randi() % lid_values.size()]


## Validates anchor for sarcophagus-specific requirements
func validate_anchor(anchor: Node) -> bool:
	if not super.validate_anchor(anchor):
		return false
	
	# Additional sarcophagus-specific validation can be added here
	# For now, use base validation
	return true

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## Spawns a sarcophagus item at a specific anchor with sarcophagus-specific logic
func _spawn_sarcophagus_item_at_anchor(anchor: Node, index: int, rng: RandomNumberGenerator) -> Node:
	# Determine what to spawn - either from scene_path or sarcophagus_items
	var item_to_spawn: String = ""
	
	if not scene_path.is_empty():
		item_to_spawn = scene_path
	elif not sarcophagus_items.is_empty():
		# Select random item from sarcophagus items
		var item_index := rng.randi() % sarcophagus_items.size() if rng else 0
		item_to_spawn = sarcophagus_items[item_index]
	else:
		print("SarcophagusSpawnData: No items configured for spawning")
		return null
	
	var item_scene: PackedScene = load(item_to_spawn)
	if not is_instance_valid(item_scene):
		print("ERROR SarcophagusSpawnData: Failed to load scene: %s" % item_to_spawn)
		return null
	
	var item = item_scene.instantiate()
	if not is_instance_valid(item):
		print("ERROR SarcophagusSpawnData: Failed to instantiate scene: %s" % item_to_spawn)
		return null
	
	# Handle special comet shard logic
	if _is_comet_shard(item):
		return _handle_comet_shard_spawn(item, anchor)
	
	# Standard sarcophagus item spawning
	return _handle_standard_sarcophagus_spawn(item, anchor, index)


## Checks if an item is a comet shard
func _is_comet_shard(item: Node) -> bool:
	if not item.get_script():
		return false
	return item.get_script().get_global_name() == "ShardOfTheComet"


## Handles comet shard spawning with game state management
func _handle_comet_shard_spawn(item: Node, anchor: Node) -> Node:
	if not can_spawn_comet_shard:
		item.queue_free()
		return null
	
	# Check global shard spawn state
	if GameManager.game.shard_has_spawned:
		item.queue_free()
		return null
	
	# Mark shard as spawned globally
	GameManager.game.shard_has_spawned = true
	
	# Use original comet shard spawning logic
	anchor.add_child(item)
	item.set_item_state(GlobalConsts.ItemState.DROPPED)
	
	return item


## Handles standard sarcophagus item spawning
func _handle_standard_sarcophagus_spawn(item: Node, anchor: Node, index: int) -> Node:
	# Position item at anchor
	if item is Node3D and anchor is Node3D:
		var node3d_item = item as Node3D
		var spawn_position := get_anchor_spawn_position(anchor)
		node3d_item.position = spawn_position
		
		# Handle placement_position offset if available
		if item.has_method("get") and item.get("placement_position"):
			var placement_position = item.get("placement_position")
			if placement_position:
				node3d_item.position += placement_position.position
		
		# Apply stored transform rotation if available
		if index < _transforms.size():
			var stored_transform := _transforms[index] as Transform3D
			node3d_item.transform.basis = stored_transform.basis
	
	# Set item state
	item.set_item_state(GlobalConsts.ItemState.DROPPED)
	
	# Apply custom properties including sarcophagus-specific ones
	if index < _custom_properties.size():
		var custom_properties := _custom_properties[index] as Dictionary
		_apply_sarcophagus_properties(item, custom_properties)
		_apply_custom_properties(item, custom_properties)
	
	# Add to scene tree - use grandparent to match original logic
	var spawn_parent: Node = _get_sarcophagus_spawn_parent(anchor)
	spawn_parent.add_child(item, true)
	
	# Apply post-spawn setup
	_post_spawn_item_setup(item)
	
	# Handle lighting items
	_handle_lighting_items(item)
	
	return item


## Gets the appropriate parent for sarcophagus spawning (matches original logic)
func _get_sarcophagus_spawn_parent(anchor: Node) -> Node:
	# Original logic: get_parent().get_parent().add_child(new_item)
	var parent := anchor.get_parent()
	if parent:
		var grandparent := parent.get_parent()
		if grandparent:
			return grandparent
	
	# Fallback to base implementation
	return _get_spawn_parent(anchor)


## Applies sarcophagus-specific properties
func _apply_sarcophagus_properties(item: Node, custom_properties: Dictionary) -> void:
	# Add sarcophagus-specific properties
	if wall_direction != -1:
		custom_properties["wall_direction"] = wall_direction
	
	if lid_type != LidType.EMPTY:
		custom_properties["lid_type"] = lid_type


## Handles lighting items (candles, candelabra)
func _handle_lighting_items(item: Node) -> void:
	if not item.get_script():
		return
	
	var script_name = item.get_script().get_global_name()
	if script_name == "CandleItem" or script_name == "CandelabraItem":
		item.light()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------