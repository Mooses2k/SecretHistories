@tool
## Character-specific spawn data implementation
## Handles character spawning with loadout system integration, inventory system integration,
## continuous spawning mechanics, and CellFilter integration for positioning
class_name CharacterSpawnData
extends SpawnData


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CHARACTER_CENTER_POSITION_OFFSET = Vector3(0.75, 0.0, 0.75)
const ENEMY_GROUP: String = "CULTIST"

#--- public variables - order: export > normal var > onready --------------------------------------

## Character loadout configuration
## Array of Dictionary representing loadout sets with weighted item packs
@export var character_loadout: Array = []

## Level threshold for continuous spawning (negative values for deep levels)
@export var continuous_spawn_level: int = -5

## Maximum number of characters for continuous spawning
@export var continuous_spawn_max: int = 7

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()
var _total_weights_by_set := []

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	super._init()
	# Initialize loadout weights when loadout is set
	_calculate_loadout_weights()


func _to_string() -> String:
	var msg := "[CharacterSpawnData:%s | amount: %s scene_path: %s transforms: %s loadout_sets: %s]" % [
		get_instance_id(), amount, scene_path, _transforms, character_loadout.size()
	]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Enhanced character spawning with loadout integration
func spawn_character_in(node: Node, should_log := false) -> Node3D:
	if _has_spawned:
		return null
	
	var character_scene: PackedScene = load(scene_path)
	if not is_instance_valid(character_scene):
		print("ERROR CharacterSpawnData: Failed to load scene: %s" % scene_path)
		return null
	
	var character = character_scene.instantiate() as Node3D
	if not is_instance_valid(character):
		print("ERROR CharacterSpawnData: Failed to instantiate character scene: %s" % scene_path)
		return null
	
	# Apply transform
	character.transform = _transforms.front()
	
	# Add to scene tree
	node.add_child(character, true)
	
	# Apply loadout system
	_apply_character_loadout(character)
	
	# Apply custom properties
	if not _custom_properties.is_empty():
		var custom_properties := _custom_properties.front() as Dictionary
		_apply_custom_properties(character, custom_properties)
	
	# Apply post-spawn setup
	_post_spawn_character_setup(character)
	
	if should_log:
		print("Character spawned: %s at: %s" % [character, character.position])
	
	_has_spawned = true
	return character


## Spawns character at filtered cell positions using CellFilter integration
func spawn_character_at_filtered_cells(node: Node, world_data: WorldData, cells: Array, should_log := false) -> Node3D:
	if _has_spawned:
		return null
	
	if cells.is_empty():
		if should_log:
			print("CharacterSpawnData: No valid cells provided for character spawning")
		return null
	
	var character_scene: PackedScene = load(scene_path)
	if not is_instance_valid(character_scene):
		print("ERROR CharacterSpawnData: Failed to load scene: %s" % scene_path)
		return null
	
	var character = character_scene.instantiate() as Node3D
	if not is_instance_valid(character):
		print("ERROR CharacterSpawnData: Failed to instantiate character scene: %s" % scene_path)
		return null
	
	# Use first available cell for character positioning
	var cell_index: int = cells[0]
	var cell_position := CellFilter.get_cell_position(world_data, cell_index)
	var spawn_position := cell_position + _get_center_offset()
	
	# Set character position
	character.global_position = spawn_position
	
	# Apply stored transform rotation if available
	if not _transforms.is_empty():
		var stored_transform := _transforms.front() as Transform3D
		character.transform.basis = stored_transform.basis
	
	# Add to scene tree
	node.add_child(character, true)
	
	# Apply loadout system
	_apply_character_loadout(character)
	
	# Apply custom properties
	if not _custom_properties.is_empty():
		var custom_properties := _custom_properties.front() as Dictionary
		_apply_custom_properties(character, custom_properties)
	
	# Apply post-spawn setup
	_post_spawn_character_setup(character)
	
	if should_log:
		print("Character spawned at filtered cell: %s at: %s" % [character, character.global_position])
	
	_has_spawned = true
	return character


## Creates a duplicate for continuous spawning with new positioning
func create_continuous_spawn_copy(world_data: WorldData, player_position: Vector3, rng: RandomNumberGenerator) -> CharacterSpawnData:
	var copy := duplicate() as CharacterSpawnData
	copy._has_spawned = false
	copy._rng = rng
	
	# Use AwayFromPlayerCellFilter to find suitable spawn location
	var away_filter := AwayFromPlayerCellFilter.new()
	away_filter.set_player_position(player_position)
	
	var candidate_cells := away_filter.filter_cells(world_data, null, rng)
	if candidate_cells.is_empty():
		print("CharacterSpawnData: No suitable spawn location found away from player")
		return null
	
	# Get the first suitable cell and convert to world position
	var spawn_cell_index: int = candidate_cells[0]
	var spawn_position := CellFilter.get_cell_position(world_data, spawn_cell_index)
	
	# Use navigation to ensure the position is navigable
	var navigation_map = Engine.get_main_loop().current_scene.get_world_3d().navigation_map
	spawn_position = NavigationServer3D.map_get_closest_point(navigation_map, spawn_position)
	spawn_position = CellFilter.get_cell_position(world_data, CellFilter.get_cell_from_local_position(world_data, spawn_position))
	
	copy.set_center_position_in_cell(spawn_position)
	return copy


## Checks if continuous spawning should occur based on current game state
func should_trigger_continuous_spawn(current_floor_level: int, current_enemy_count: int) -> bool:
	return (current_floor_level <= continuous_spawn_level 
		and current_enemy_count < continuous_spawn_max)


## Sets up character loadout configuration
func configure_character_loadout(loadout: Array) -> void:
	character_loadout = loadout
	_calculate_loadout_weights()


## Sets continuous spawning parameters
func configure_continuous_spawning(level_threshold: int, max_enemies: int) -> void:
	continuous_spawn_level = level_threshold
	continuous_spawn_max = max_enemies


## Gets valid spawn cells using CellFilter for character positioning
func get_character_spawn_cells(world_data: WorldData, room_data: RoomData, cell_filter: CellFilter, rng: RandomNumberGenerator = null) -> Array:
	if not cell_filter:
		push_warning("CharacterSpawnData.get_character_spawn_cells(): No CellFilter provided")
		return []
	
	return cell_filter.filter_cells(world_data, room_data, rng)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## Applies character loadout using the loadout system from CharacterSpawner
func _apply_character_loadout(character: Node3D) -> void:
	if character_loadout.is_empty():
		return
	
	var inventory = character.get_node_or_null("Inventory")
	if not inventory:
		print("WARNING CharacterSpawnData: Character has no Inventory node for loadout application")
		return
	
	for set_index in character_loadout.size():
		var total_weight := _total_weights_by_set[set_index] as int
		if total_weight == 0:
			continue
		
		var chosen_pack := _get_chosen_pack(total_weight, set_index)
		_apply_loadout_pack(inventory, chosen_pack)


## Gets a chosen pack from a loadout set using weighted selection
func _get_chosen_pack(total_weight: int, set_index: int) -> Dictionary:
	var rng_value := _rng.randi() % total_weight
	var cumulative_weight := 0
	
	for pack in (character_loadout[set_index] as Dictionary).keys():
		cumulative_weight += character_loadout[set_index][pack]
		if rng_value < cumulative_weight:
			return pack
	
	# Fallback to empty dictionary
	return {}


## Applies a loadout pack to character inventory
func _apply_loadout_pack(inventory: Node, pack: Dictionary) -> void:
	for item in pack.keys():
		var min_amount := pack[item].x as int
		var max_amount := pack[item].y as int
		var amount := min_amount
		
		if max_amount > min_amount:
			amount = _rng.randi() % (max_amount - min_amount) + min_amount
		
		_add_item_to_inventory(inventory, item, amount, pack[item])


## Adds an item to character inventory with proper type handling
func _add_item_to_inventory(inventory: Node, item, amount: int, range_vector: Vector2) -> void:
	# Handle TinyItemData (stackable items)
	if item is TinyItemData:
		if not inventory.tiny_items.has(item):
			inventory.tiny_items[item] = 0
		inventory.tiny_items[item] += amount
	
	# Handle PackedScene items (weapons, tools, etc.)
	elif item is PackedScene:
		var instanced = item.instantiate()
		if instanced is PickableItem:
			inventory.add_item(instanced)
			instanced.set_range(range_vector)
		else:
			instanced.queue_free()


## Character-specific post-spawn setup
func _post_spawn_character_setup(character: Node3D) -> void:
	# Add character to enemy group for continuous spawning tracking
	if not character.is_in_group(ENEMY_GROUP):
		character.add_to_group(ENEMY_GROUP)
	
	# Additional character-specific setup can be added here
	# For now, delegate to base implementation
	_post_spawn_item_setup(character)


## Calculates total weights for each loadout set
func _calculate_loadout_weights() -> void:
	_total_weights_by_set.clear()
	_total_weights_by_set.resize(character_loadout.size())
	
	for set_index in character_loadout.size():
		var set_weight := 0
		for pack in (character_loadout[set_index] as Dictionary).keys():
			set_weight += character_loadout[set_index][pack]
		_total_weights_by_set[set_index] = set_weight


## Override amount setter to enforce single character per spawn data
func _set_amount(value: int) -> void:
	if value != 1:
		value = 1
		push_warning("CharacterSpawnData: Can't spawn more than 1 character per spawn data instance")
	
	super._set_amount(value)


## Override center offset for character positioning
func _get_center_offset() -> Vector3:
	return CHARACTER_CENTER_POSITION_OFFSET

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
