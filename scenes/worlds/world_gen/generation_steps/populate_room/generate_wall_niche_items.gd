@tool
## Generation step for spawning items in wall niches using OnWallSpawnData
## Follows the spawn_data pattern used by sarcophagus generation
class_name GenerateWallNicheItems
extends GenerationStep


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Loot list resource for niche items
@export var _niche_loot_list_resource: Resource = null

## Minimum number of niche items to spawn
@export var _min_niche_items: int = 1

## Maximum number of niche items to spawn
@export var _max_niche_items: int = 3

## Spawn chance per wall with niche tiles (0.0 to 1.0)
@export var _niche_spawn_chance: float = 0.8

## Whether to enable debug logging
@export var _debug_logging: bool = true

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng: RandomNumberGenerator

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_rng = RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data: WorldData, gen_data: Dictionary, generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	
	if not _niche_loot_list_resource or not _niche_loot_list_resource is ObjectSpawnList:
		if _debug_logging:
			print("GenerateWallNicheItems: No valid loot list resource assigned")
		return
	
	_rng.seed = generation_seed
	
	if _debug_logging:
		print("GenerateWallNicheItems: Starting wall niche item generation")
	
	# Check ALL cells in the world for niche wall tiles (not just rooms - corridors too!)
	var niche_walls_found = 0
	var world_size_x = data.world_size_x
	var world_size_z = data.world_size_z
	
	if _debug_logging:
		print("GenerateWallNicheItems: Checking world %dx%d for niche wall tiles" % [world_size_x, world_size_z])
	
	# Iterate through all cells in the world
	for x in world_size_x:
		for z in world_size_z:
			var cell_index = data.get_cell_index_from_int_position(x, z)
			
			if cell_index == -1:
				continue
			
			# Check all 4 walls of this cell for niche tiles
			for direction in [WorldData.Direction.NORTH, WorldData.Direction.EAST, WorldData.Direction.SOUTH, WorldData.Direction.WEST]:
				var wall_tile = data.get_wall_tile_index(cell_index, direction)
				
				# Check if this wall has a niche tile
				if _is_niche_wall_tile(wall_tile):
					if _debug_logging:
						print("GenerateWallNicheItems: Found niche wall tile %d at cell %d (x:%d, z:%d) direction %d" % [wall_tile, cell_index, x, z, direction])
					
					# Create spawn data for this niche wall
					if _should_spawn_niche_item():
						_create_niche_spawn_data(data, cell_index, Vector2i(x, z), wall_tile, direction)
						niche_walls_found += 1
	
	if _debug_logging:
		print("GenerateWallNicheItems: Found %d niche walls total" % niche_walls_found)


## Checks if a wall tile is a niche tile
func _is_niche_wall_tile(wall_tile: int) -> bool:
	# From procedural_world.tscn: alternative_double_wall_tiles = Array[int]([20, 21, 22])
	# These are the wall tiles that contain niches
	return wall_tile in [20, 21, 22]


## Determines if a niche item should spawn based on chance
func _should_spawn_niche_item() -> bool:
	return _rng.randf() <= _niche_spawn_chance


## Creates OnWallSpawnData for a niche wall
func _create_niche_spawn_data(data: WorldData, cell_index: int, cell_pos: Vector2i, wall_tile: int, direction: int) -> void:
	# Get random item from loot list
	var base_spawn_data = _niche_loot_list_resource.get_random_spawn_data(_rng)
	if base_spawn_data.scene_path.is_empty():
		if _debug_logging:
			print("GenerateWallNicheItems: Empty scene path from loot list")
		return
	
	# Create OnWallSpawnData for niche spawning
	var wall_spawn_data = OnWallSpawnData.new()
	wall_spawn_data.scene_path = base_spawn_data.scene_path
	wall_spawn_data.amount = base_spawn_data.amount
	
	# Use calculated positioning since MeshLibrary tiles can't have PlacementAnchors
	wall_spawn_data.wall_spawn_type = OnWallSpawnData.WallSpawnType.NICHE_CALCULATED
	
	# Don't set a specific position - let OnWallSpawnData find the PlacementAnchors
	# The PlacementAnchors are already precisely positioned on the wall tiles
	var cell_world_pos = data.get_local_cell_position(cell_index)
	wall_spawn_data.set_center_position_in_cell(cell_world_pos)
	
	# Set custom properties for surgical niche spawning
	wall_spawn_data.set_custom_property("cell_index", cell_index)  # Store cell_index for surgical GridMap access
	wall_spawn_data.set_custom_property("wall_tile", wall_tile)
	wall_spawn_data.set_custom_property("wall_direction", direction)
	wall_spawn_data.set_custom_property("cell_position", cell_pos)
	wall_spawn_data.set_custom_property("niche_type", "wall_niche")
	
	# Store the spawn data in the cell
	data.set_object_spawn_data_to_cell(cell_index, wall_spawn_data)
	
	if _debug_logging:
		print("GenerateWallNicheItems: Created niche spawn data for %s at cell %d (pos: %s)" % [
			base_spawn_data.scene_path.get_file(),
			cell_index,
			cell_world_pos
		])


## Determines wall direction by checking neighboring cells
func _determine_wall_direction(cell_pos: Vector2i, data: WorldData) -> int:
	# For now, use a simple heuristic based on position
	# This could be enhanced later with proper neighbor checking
	# Default to north-facing wall
	return 0


### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
