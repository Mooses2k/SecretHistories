@tool
class_name GenerateWallObjects
extends GenerationStep

## Generates wall objects on convex corner pillars
## Places wall objects randomly on pillar sides that face outward between two CORRIDOR cells

### Member Variables and Dependencies -------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------
@export var _wall_object_spawn_list_resource: Resource = null
@export var _spawn_chance: float = 0.25  # Chance to spawn on each valid pillar side
@export var _wall_offset_multiplier: float = 0.23  # How far from pillar surface to place objects
@export var _wall_mount_height: float = 1.5  # Height above floor to mount wall objects

#--- private variables - order: export > normal var > onready -------------------------------------
var _rng := RandomNumberGenerator.new()

### Built-in Virtual Overrides --------------------------------------------------------------------

func _execute_step(data: WorldData, _gen_data: Dictionary, generation_seed: int):
	_rng.seed = generation_seed
	
	# Debug: First let's see how many pillars exist total
	var total_pillars = _count_total_pillars(data)
	print("DEBUG: Total pillars in world: %d" % total_pillars)
	
	var valid_pillar_sides = _find_valid_pillar_sides(data)
	print("Found %d valid pillar sides for potential wall object placement" % valid_pillar_sides.size())
	
	var objects_placed = 0
	for pillar_data in valid_pillar_sides:
		if _rng.randf() <= _spawn_chance:
			_spawn_wall_object_on_pillar(data, pillar_data)
			objects_placed += 1
	
	print("Placed %d wall objects out of %d valid pillar sides" % [objects_placed, valid_pillar_sides.size()])

### Private Methods -------------------------------------------------------------------------------

# Count total pillars for debugging
func _count_total_pillars(data: WorldData) -> int:
	var count = 0
	print("DEBUG: Scanning for pillars in %dx%d world..." % [data.world_size_x, data.world_size_z])
	
	# Pillars are at vertices, so check all positions
	for x in range(data.world_size_x):
		for z in range(data.world_size_z):
			var cell_index = data.get_cell_index_from_int_position(x, z)
			var pillar_tile = data.get_pillar_tile_index(cell_index)
			var cell_type = data.get_cell_type(cell_index)
			
			if pillar_tile != -1:
				count += 1
				print("DEBUG: Found pillar at vertex (%d, %d) - tile: %d, cell_type: %s" % [x, z, pillar_tile, data.CellType.keys()[cell_type]])
	
	return count


# Find valid pillar sides for wall object placement
func _find_valid_pillar_sides(data: WorldData) -> Array:
	var valid_sides = []
	
	# Check each position for pillars (pillars are at vertices)
	for x in range(1, data.world_size_x - 1):
		for z in range(1, data.world_size_z - 1):
			var pillar_cell_index = data.get_cell_index_from_int_position(x, z)
			
			# Check if there's a pillar at this vertex
			if data.get_pillar_tile_index(pillar_cell_index) == -1:
				continue
			
			print("DEBUG: Found pillar at vertex (%d, %d)" % [x, z])
			
			# Check each direction for valid wall placement
			# For a pillar at vertex (x,z), check the 4 adjacent cell pairs
			for direction in WorldData.Direction.DIRECTION_MAX:
				if _is_valid_pillar_side_for_vertex(data, x, z, direction):
					valid_sides.append({
						"pillar_x": x,
						"pillar_z": z,
						"direction": direction,
						"position": data.get_local_cell_position(pillar_cell_index)
					})
					print("DEBUG: Valid side found at vertex (%d,%d) - direction %d" % [x, z, direction])
	
	return valid_sides


# Check if this pillar side is valid for wall object placement
# A pillar at vertex (x,z) has 4 sides, each facing a different direction
# Each side is valid if the two cells adjacent to that side are both corridors
func _is_valid_pillar_side_for_vertex(data: WorldData, pillar_x: int, pillar_z: int, direction: int) -> bool:
	# For a pillar at vertex (pillar_x, pillar_z), determine which two cells
	# are adjacent to the side facing the given direction
	var cell1_x: int
	var cell1_z: int
	var cell2_x: int
	var cell2_z: int
	
	match direction:
		WorldData.Direction.NORTH:  # North side of pillar
			# Cells to the north of the pillar vertex
			cell1_x = pillar_x - 1
			cell1_z = pillar_z - 1
			cell2_x = pillar_x
			cell2_z = pillar_z - 1
		WorldData.Direction.EAST:   # East side of pillar
			# Cells to the east of the pillar vertex
			cell1_x = pillar_x
			cell1_z = pillar_z - 1
			cell2_x = pillar_x
			cell2_z = pillar_z
		WorldData.Direction.SOUTH:  # South side of pillar
			# Cells to the south of the pillar vertex
			cell1_x = pillar_x - 1
			cell1_z = pillar_z
			cell2_x = pillar_x
			cell2_z = pillar_z
		WorldData.Direction.WEST:   # West side of pillar
			# Cells to the west of the pillar vertex
			cell1_x = pillar_x - 1
			cell1_z = pillar_z - 1
			cell2_x = pillar_x - 1
			cell2_z = pillar_z
		_:
			return false
	
	# Check if both cells are valid and are corridors
	if cell1_x < 0 or cell1_x >= data.world_size_x or cell1_z < 0 or cell1_z >= data.world_size_z:
		return false
	if cell2_x < 0 or cell2_x >= data.world_size_x or cell2_z < 0 or cell2_z >= data.world_size_z:
		return false
	
	var cell1_index = data.get_cell_index_from_int_position(cell1_x, cell1_z)
	var cell2_index = data.get_cell_index_from_int_position(cell2_x, cell2_z)
	
	var cell1_type = data.get_cell_type(cell1_index)
	var cell2_type = data.get_cell_type(cell2_index)
	
	var both_corridors = (cell1_type == data.CellType.CORRIDOR and cell2_type == data.CellType.CORRIDOR)
	
	print("DEBUG: Pillar (%d,%d) direction %d - cell1(%d,%d)=%s, cell2(%d,%d)=%s, both_corridors=%s" % [
		pillar_x, pillar_z, direction,
		cell1_x, cell1_z, data.CellType.keys()[cell1_type],
		cell2_x, cell2_z, data.CellType.keys()[cell2_type],
		both_corridors
	])
	
	return both_corridors


func _spawn_wall_object_on_pillar(data: WorldData, pillar_data: Dictionary):
	print("DEBUG GenerateWallObjects: === SPAWNING WALL OBJECT ===")
	
	var spawn_list = _wall_object_spawn_list_resource as ObjectSpawnList
	if not spawn_list:
		push_warning("No wall object spawn list resource assigned")
		return
	
	var spawn_data = spawn_list.get_random_spawn_data(_rng)
	if spawn_data.scene_path.is_empty():
		print("ERROR GenerateWallObjects: Empty scene path from spawn list")
		return
	
	print("DEBUG GenerateWallObjects: Selected scene: %s" % spawn_data.scene_path)
	
	# Position wall object on the pillar side
	var pillar_position = pillar_data.position as Vector3
	var direction = pillar_data.direction as int
	var wall_offset = _get_wall_offset_for_direction(direction)
	
	print("DEBUG GenerateWallObjects: Pillar position: %s" % pillar_position)
	print("DEBUG GenerateWallObjects: Wall direction: %d (%s)" % [
		direction,
		["NORTH", "EAST", "SOUTH", "WEST"][direction] if direction < 4 else "UNKNOWN"
	])
	print("DEBUG GenerateWallObjects: Wall offset vector: %s" % wall_offset)
	
	# Position slightly away from pillar surface and at proper wall mounting height
	# Add directional offset to ensure each pillar side maps to a unique cell
	var base_offset = wall_offset * (WorldData.CELL_SIZE * _wall_offset_multiplier)
	var directional_offset = _get_directional_cell_offset(direction, pillar_data.pillar_x, pillar_data.pillar_z)
	var object_position = pillar_position + base_offset + directional_offset
	object_position.y += _wall_mount_height  # Mount at proper height above floor
	print("DEBUG GenerateWallObjects: Calculated object position: %s (raised %fm for wall mounting)" % [object_position, _wall_mount_height])
	print("DEBUG GenerateWallObjects: Base offset: %s, Directional offset: %s" % [base_offset, directional_offset])
	
	spawn_data.set_position_in_cell(object_position)
	
	# Rotate to face outward from pillar
	var rotation_angle = _get_rotation_for_direction(direction)
	spawn_data.set_y_rotation(rotation_angle)
	print("DEBUG GenerateWallObjects: Set rotation angle: %f radians (%f degrees)" % [
		rotation_angle, rad_to_deg(rotation_angle)
	])
	
	# Store wall direction and position info for the wall object to use
	spawn_data.set_custom_property("wall_direction", direction)
	spawn_data.set_custom_property("pillar_position", pillar_position)
	spawn_data.set_custom_property("wall_offset", wall_offset)
	print("DEBUG GenerateWallObjects: Set custom properties - wall_direction: %d" % direction)
	
	# Get the target cell index for placement using the adjusted position
	var target_cell_index = data.get_cell_index_from_local_position(object_position)
	var pillar_x = pillar_data.pillar_x as int
	var pillar_z = pillar_data.pillar_z as int
	
	print("DEBUG GenerateWallObjects: Target cell index: %d (from position %s)" % [target_cell_index, object_position])
	
	# Check if target cell is valid and free
	if target_cell_index != -1 and data.get_cell_type(target_cell_index) == data.CellType.CORRIDOR:
		# Check if this specific cell+direction combination is already occupied
		var existing_objects = data.get_objects_to_spawn()
		var cell_occupied = existing_objects.has(target_cell_index)
		
		if not cell_occupied:
			data.set_object_spawn_data_to_cell(target_cell_index, spawn_data)
			print("DEBUG GenerateWallObjects: ✓ Successfully placed wall object spawn data at cell %d" % target_cell_index)
			print("DEBUG GenerateWallObjects: Final SpawnData: %s" % spawn_data.to_string())
		else:
			print("DEBUG GenerateWallObjects: Cell %d already has an object, trying nearby cells" % target_cell_index)
			_try_place_in_nearby_cell(data, spawn_data, object_position, direction, pillar_x, pillar_z)
	else:
		print("ERROR GenerateWallObjects: Cannot place wall object - target cell %d is invalid or not a corridor" % target_cell_index)
	
	print("DEBUG GenerateWallObjects: === END WALL OBJECT SPAWN ===")


func _get_wall_offset_for_direction(direction: int) -> Vector3:
	match direction:
		WorldData.Direction.NORTH:
			return Vector3(0, 0, -1)
		WorldData.Direction.EAST:
			return Vector3(1, 0, 0)
		WorldData.Direction.SOUTH:
			return Vector3(0, 0, 1)
		WorldData.Direction.WEST:
			return Vector3(-1, 0, 0)
		_:
			return Vector3.ZERO


func _get_rotation_for_direction(direction: int) -> float:
	match direction:
		WorldData.Direction.NORTH:
			return 0.0
		WorldData.Direction.EAST:
			return PI * 1.5
		WorldData.Direction.SOUTH:
			return PI
		WorldData.Direction.WEST:
			return PI * 0.5
		_:
			return 0.0


func _get_directional_cell_offset(direction: int, pillar_x: int, pillar_z: int) -> Vector3:
	## Calculate a small directional offset to ensure each pillar side maps to a unique cell
	## This prevents multiple pillar sides from conflicting over the same cell index
	
	# Use much smaller offset to avoid visible displacement
	var base_offset := 0.01  # Tiny offset just for cell differentiation
	var coord_factor := (pillar_x + pillar_z) % 4  # Use pillar coordinates for variation
	
	match direction:
		WorldData.Direction.NORTH:
			return Vector3(base_offset * coord_factor, 0, -base_offset)
		WorldData.Direction.EAST:
			return Vector3(base_offset, 0, base_offset * coord_factor)
		WorldData.Direction.SOUTH:
			return Vector3(-base_offset * coord_factor, 0, base_offset)
		WorldData.Direction.WEST:
			return Vector3(-base_offset, 0, -base_offset * coord_factor)
		_:
			return Vector3.ZERO


func _try_place_in_nearby_cell(data: WorldData, spawn_data: SpawnData, object_position: Vector3, direction: int, pillar_x: int, pillar_z: int):
	## Try to place the wall object in a nearby free cell
	## This is a fallback when the primary target cell is occupied
	
	print("DEBUG GenerateWallObjects: Trying to place in nearby cell from position %s" % object_position)
	
	# Try cells in expanding rings around the target position
	var max_search_radius := 3
	var placed := false
	
	for search_radius in range(1, max_search_radius + 1):
		if placed:
			break
		
		# Try positions in a ring at this radius
		for offset_x in range(-search_radius, search_radius + 1):
			for offset_z in range(-search_radius, search_radius + 1):
				if placed:
					break
				
				# Skip positions not on the current ring boundary
				if abs(offset_x) != search_radius and abs(offset_z) != search_radius:
					continue
				
				var test_position := object_position + Vector3(offset_x * 0.5, 0, offset_z * 0.5)
				var test_cell_index := data.get_cell_index_from_local_position(test_position)
				
				if test_cell_index != -1 and data.get_cell_type(test_cell_index) == data.CellType.CORRIDOR:
					var existing_objects = data.get_objects_to_spawn()
					if not existing_objects.has(test_cell_index):
						# Update spawn data position to the new location
						spawn_data.set_position_in_cell(test_position)
						data.set_object_spawn_data_to_cell(test_cell_index, spawn_data)
						print("DEBUG GenerateWallObjects: ✓ Placed wall object in nearby cell %d at %s (radius %d)" % [test_cell_index, test_position, search_radius])
						placed = true
	
	if not placed:
		print("DEBUG GenerateWallObjects: Could not find any nearby free cell within radius %d" % max_search_radius)

### -----------------------------------------------------------------------------------------------
