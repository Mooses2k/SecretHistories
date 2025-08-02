@tool
extends GenerationStep


var floor_tile : int = -1
var wall_tile : int = -1
var alternative_wall_tiles : Array[int] = []
@export var alternative_wall_tile_chance : float = 0.1
var double_wall_tile : int = -1
var alternative_double_wall_tiles : Array[int] = []
@export var alternative_double_wall_tile_chance : float = 0.1
var double_floor_tile : int = -1
var alternative_double_floor_tiles : Array[int] = []
@export var alternative_double_floor_tile_chance : float = 0.2
var door_tile : int = -1
@export var door_width : float = 1.5
var double_door_tile : int = -1
@export var double_door_width : float = 1.5
var ceiling_tile : int = -1
var alternative_ceiling_tiles : Array[int] = []
@export var alternative_ceiling_tile_chance : float = 0.05
var double_ceiling_tile : int = -1
var alternative_double_ceiling_tiles : Array[int] = []
@export var alternative_double_ceiling_tile_chance : float = 0.1

var pillar_room_double_wall_tile : int = -1
var pillar_room_double_door_tile : int = -1
@export var pillar_room_double_door_width : float = 1.7
var pillar_room_double_ceiling_tile : int = -1
var pillar_room_double_floor_tile : int = -1
var pillar_room_pillar_tile : int = -1
var pillar_tile : int = -1
var corridor_room_border_wall_tile : int = -1
var corridor_room_border_arch_grate_tile : int = -1

const PillarRoomGenerator = preload("res://scenes/worlds/world_gen/generation_steps/generate_room_pillars.gd")


func _get_property_list() -> Array[Dictionary]:
	var result : Array[Dictionary] = []
	var meshlib_items : PackedStringArray = PackedStringArray(["None:-1"])
	var meshlib : MeshLibrary = $"../../Gridmaps".mesh_library as MeshLibrary
	for item_idx : int in meshlib.get_item_list():
		var item_name : String = meshlib.get_item_name(item_idx)
		meshlib_items.push_back("%s:%d" % [item_name, item_idx])
	var enum_hint : String = ",".join(meshlib_items)
	#print(enum_hint)

	result.append({
		"name" : "floor_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "wall_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "double_wall_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "door_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "double_door_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "double_floor_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "ceiling_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "double_ceiling_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "pillar_room_double_wall_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "pillar_room_double_door_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "pillar_room_double_ceiling_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "pillar_room_double_floor_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "pillar_room_pillar_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "pillar_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "corridor_room_border_wall_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})
	result.append({
		"name" : "corridor_room_border_arch_grate_tile",
		"usage" : PROPERTY_USAGE_DEFAULT,
		"type" : TYPE_INT,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : enum_hint,
	})

	result.append({
		"name" : "alternative_wall_tiles",
		"type" : TYPE_ARRAY,
		"usage" : PROPERTY_USAGE_DEFAULT,
		"hint" : PROPERTY_HINT_TYPE_STRING,
		"hint_string" : "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, enum_hint],
	})
	result.append({
		"name" : "alternative_double_wall_tiles",
		"type" : TYPE_ARRAY,
		"usage" : PROPERTY_USAGE_DEFAULT,
		"hint" : PROPERTY_HINT_TYPE_STRING,
		"hint_string" : "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, enum_hint],
	})
	result.append({
		"name" : "alternative_ceiling_tiles",
		"type" : TYPE_ARRAY,
		"usage" : PROPERTY_USAGE_DEFAULT,
		"hint" : PROPERTY_HINT_TYPE_STRING,
		"hint_string" : "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, enum_hint],
	})
	result.append({
		"name" : "alternative_double_ceiling_tiles",
		"type" : TYPE_ARRAY,
		"usage" : PROPERTY_USAGE_DEFAULT,
		"hint" : PROPERTY_HINT_TYPE_STRING,
		"hint_string" : "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, enum_hint],
	})
	result.append({
		"name" : "alternative_double_floor_tiles",
		"type" : TYPE_ARRAY,
		"usage" : PROPERTY_USAGE_DEFAULT,
		"hint" : PROPERTY_HINT_TYPE_STRING,
		"hint_string" : "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, enum_hint],
	})

	return result


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	# DEBUG: Track if this step is being called multiple times
	if not has_meta("execution_count"):
		set_meta("execution_count", 0)
	var exec_count = get_meta("execution_count") + 1
	set_meta("execution_count", exec_count)

	print("DEBUG: Starting generate_grid_tiles execution #%d (seed: %d)" % [exec_count, generation_seed])

	var pillar_rooms = gen_data.get(PillarRoomGenerator.PILLAR_ROOMS_KEY, Array())
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = generation_seed

	print("DEBUG: About to call select_floor_tiles")
	select_floor_tiles(data, pillar_rooms, rng)
	print("DEBUG: Finished select_floor_tiles")

	select_ceiling_tiles(data, pillar_rooms, rng)
	select_wall_tiles(data, rng)
	select_pillar_room_walls(data, pillar_rooms)
	apply_special_border_walls(data)
	place_pillars(data)
	place_pillar_room_pillars(data, pillar_rooms)
	print("DEBUG: Finished generate_grid_tiles execution #%d" % exec_count)


func select_floor_tiles(data : WorldData, pillar_rooms : Array, rng : RandomNumberGenerator):
	print("DEBUG: Starting select_floor_tiles with %d pillar rooms" % pillar_rooms.size())

	# Get all rooms to check for even dimensions
	var all_rooms : Array = data.get_all_rooms()
	var even_dimension_rooms : Array = []
	var pillar_room_cells : Dictionary = {}

	# Find rooms with even dimensions (both width and height divisible by 2)
	for room_data in all_rooms:
		var room : RoomData = room_data as RoomData
		if room and room.rect2.size.x % 2 == 0 and room.rect2.size.y % 2 == 0:
			# Skip pillar rooms as they have their own handling
			if not room.has_pillars:
				even_dimension_rooms.append(room)

	print("DEBUG: Found %d even dimension rooms" % even_dimension_rooms.size())

	# Pre-mark pillar room cells to avoid double placement
	for _room in pillar_rooms:
		var room : Rect2 = _room as Rect2
		print("DEBUG: Processing pillar room at %s with size %s" % [room.position, room.size])
		for i in room.size.x / 2:
			for j in room.size.y / 2:
				var cell = data.get_cell_index_from_int_position(room.position.x + 2 * i, room.position.y + 2 * j)
				pillar_room_cells[cell] = true

	print("DEBUG: Marked %d pillar room cells" % pillar_room_cells.size())

	# Pre-mark even dimension room cells to avoid double placement
	var even_room_cells : Dictionary = {}
	for room_data in even_dimension_rooms:
		var room : RoomData = room_data as RoomData
		var room_rect : Rect2 = room.rect2
		print("DEBUG: Processing even dimension room at %s with size %s" % [room_rect.position, room_rect.size])
		for i in room_rect.size.x / 2:
			for j in room_rect.size.y / 2:
				var cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * i, room_rect.position.y + 2 * j)
				even_room_cells[cell] = true

	print("DEBUG: Marked %d even dimension room cells" % even_room_cells.size())

	# DEBUG: Check for overlaps between pillar room cells and even dimension room cells
	var overlap_count = 0
	for cell in pillar_room_cells:
		if even_room_cells.has(cell):
			overlap_count += 1
			var cell_pos = data.get_int_position_from_cell_index(cell)
			print("WARNING: Cell overlap detected at (%d,%d) - both pillar room and even dimension room!" % [cell_pos[0], cell_pos[1]])

	if overlap_count > 0:
		print("CRITICAL: Found %d overlapping cells between pillar rooms and even dimension rooms!" % overlap_count)
	else:
		print("DEBUG: No overlaps detected between pillar rooms and even dimension rooms")

	# Set floor tiles - FIXED to prevent z-fighting from double tiles
	var processed_cells : Dictionary = {}

	# First, handle pillar rooms (place double tiles only on 2x2 origins)
	for _room in pillar_rooms:
		var room : Rect2 = _room as Rect2
		print("DEBUG: Processing pillar room floor tiles at %s with size %s" % [room.position, room.size])
		for i in room.size.x / 2:
			for j in room.size.y / 2:
				var cell = data.get_cell_index_from_int_position(room.position.x + 2 * i, room.position.y + 2 * j)
				var cell_pos = data.get_int_position_from_cell_index(cell)
				var cell_key = "(%d,%d)" % [cell_pos[0], cell_pos[1]]

				# Check if this is a staircase cell
				var is_stairs_down = data.get_cell_meta(cell, data.CellMetaKeys.META_IS_DOWN_STAIRCASE, false)
				var is_stairs_up = data.get_cell_meta(cell, data.CellMetaKeys.META_IS_UP_STAIRCASE, false)

				if is_stairs_down or is_stairs_up:
					print("DEBUG: Skipping staircase cell at %s" % cell_key)
					continue

				print("DEBUG: Placing pillar room double floor tile at %s (covers 2x2 area)" % cell_key)
				data.set_ground_tile_index(cell, pillar_room_double_floor_tile)

				# Mark all 4 cells of the 2x2 double tile as processed
				for di in 2:
					for dj in 2:
						var sub_cell = data.get_cell_index_from_int_position(room.position.x + 2 * i + di, room.position.y + 2 * j + dj)
						processed_cells[sub_cell] = true
						# Set surface type for all cells in the 2x2 group
						data.set_cell_surfacetype(sub_cell, data.SurfaceType.STONE)

	# Second, handle even dimension rooms (place double tiles only on 2x2 origins)
	for room_data in even_dimension_rooms:
		var room : RoomData = room_data as RoomData
		var room_rect : Rect2 = room.rect2
		print("DEBUG: Processing even dimension room floor tiles at %s with size %s" % [room_rect.position, room_rect.size])
		for i in room_rect.size.x / 2:
			for j in room_rect.size.y / 2:
				var cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * i, room_rect.position.y + 2 * j)
				var cell_pos = data.get_int_position_from_cell_index(cell)
				var cell_key = "(%d,%d)" % [cell_pos[0], cell_pos[1]]

				if processed_cells.has(cell):
					print("WARNING: Skipping already processed cell %s" % cell_key)
					continue

				# Check if this is a staircase cell
				var is_stairs_down = data.get_cell_meta(cell, data.CellMetaKeys.META_IS_DOWN_STAIRCASE, false)
				var is_stairs_up = data.get_cell_meta(cell, data.CellMetaKeys.META_IS_UP_STAIRCASE, false)

				if is_stairs_down or is_stairs_up:
					print("DEBUG: Skipping staircase cell at %s" % cell_key)
					continue

				# Even dimension room with randomization using shared RNG
				var rnd = rng.randf()
				var selected_floor_tile : int = double_floor_tile
				if rnd < alternative_double_floor_tile_chance and alternative_double_floor_tiles.size() > 0:
					var index : int = rng.randi() % alternative_double_floor_tiles.size()
					selected_floor_tile = alternative_double_floor_tiles[index]

				print("DEBUG: Placing even dimension room double floor tile at %s: tile_id=%d (covers 2x2 area)" % [cell_key, selected_floor_tile])
				data.set_ground_tile_index(cell, selected_floor_tile)

				# Mark all 4 cells of the 2x2 double tile as processed
				for di in 2:
					for dj in 2:
						var sub_cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * i + di, room_rect.position.y + 2 * j + dj)
						processed_cells[sub_cell] = true
						# Set surface type for all cells in the 2x2 group
						data.set_cell_surfacetype(sub_cell, data.SurfaceType.STONE)

	# Finally, handle all remaining cells with regular floor tiles
	for i in data.cell_count:
		if processed_cells.has(i):
			continue

		var cell_type = data.get_cell_type(i)
		var is_stairs_down = data.get_cell_meta(i, data.CellMetaKeys.META_IS_DOWN_STAIRCASE, false)
		var is_stairs_up = data.get_cell_meta(i, data.CellMetaKeys.META_IS_UP_STAIRCASE, false)

		if cell_type != data.CellType.EMPTY and not is_stairs_down and not is_stairs_up:
			var cell_pos = data.get_int_position_from_cell_index(i)
			var cell_key = "(%d,%d)" % [cell_pos[0], cell_pos[1]]

			# Set surface type
			if cell_type == data.CellType.ROOM:
				data.set_cell_surfacetype(i, data.SurfaceType.STONE)
			elif cell_type == data.CellType.CORRIDOR:
				data.set_cell_surfacetype(i, data.SurfaceType.CARPET)

			print("DEBUG: Placing regular floor tile at %s" % cell_key)
			data.set_ground_tile_index(i, floor_tile)


func select_ceiling_tiles(data : WorldData, pillar_rooms : Array, rng : RandomNumberGenerator):
	print("DEBUG: Starting select_ceiling_tiles - FIXED VERSION")

	# Get all rooms to check for even dimensions
	var all_rooms : Array = data.get_all_rooms()
	var even_dimension_rooms : Array = []

	# Find rooms with even dimensions (both width and height divisible by 2)
	for room_data in all_rooms:
		var room : RoomData = room_data as RoomData
		if room and room.rect2.size.x % 2 == 0 and room.rect2.size.y % 2 == 0:
			# Skip pillar rooms as they have their own handling
			if not room.has_pillars:
				even_dimension_rooms.append(room)

	# Track processed cells to prevent double placement
	var processed_cells : Dictionary = {}

	# First, handle even-dimensioned rooms with double ceiling tiles (place only on 2x2 origins)
	for room_data in even_dimension_rooms:
		var room : RoomData = room_data as RoomData
		var room_rect : Rect2 = room.rect2
		print("DEBUG: Processing even dimension room ceiling tiles at %s with size %s" % [room_rect.position, room_rect.size])
		for i in room_rect.size.x / 2:
			for j in room_rect.size.y / 2:
				var cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * i, room_rect.position.y + 2 * j)
				var cell_pos = data.get_int_position_from_cell_index(cell)
				var cell_key = "(%d,%d)" % [cell_pos[0], cell_pos[1]]

				var rnd = rng.randf()
				var selected_ceiling_tile : int = double_ceiling_tile
				if rnd < alternative_double_ceiling_tile_chance and alternative_double_ceiling_tiles.size() > 0:
					var index : int = rng.randi() % alternative_double_ceiling_tiles.size()
					selected_ceiling_tile = alternative_double_ceiling_tiles[index]

				print("DEBUG: Placing even dimension room double ceiling tile at %s: tile_id=%d (covers 2x2 area)" % [cell_key, selected_ceiling_tile])
				data.set_ceiling_tile_index(cell, selected_ceiling_tile)

				# Mark all 4 cells of the 2x2 double tile as processed
				for di in 2:
					for dj in 2:
						var sub_cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * i + di, room_rect.position.y + 2 * j + dj)
						processed_cells[sub_cell] = true

	# Second, handle all remaining non-empty, non-pillar-room cells with regular ceiling tiles
	for i in data.cell_count:
		if processed_cells.has(i):
			continue

		if data.get_cell_type(i) != data.CellType.EMPTY:
			var is_pillar_room = data.get_cell_meta(i, data.CellMetaKeys.META_PILLAR_ROOM, false)
			if not is_pillar_room:
				var cell_pos = data.get_int_position_from_cell_index(i)
				var cell_key = "(%d,%d)" % [cell_pos[0], cell_pos[1]]

				var rnd = rng.randf()
				var selected_ceiling_tile : int = ceiling_tile
				if rnd < alternative_ceiling_tile_chance and alternative_ceiling_tiles.size() > 0:
					var index : int = rng.randi() % alternative_ceiling_tiles.size()
					selected_ceiling_tile = alternative_ceiling_tiles[index]

				print("DEBUG: Placing regular ceiling tile at %s: tile_id=%d" % [cell_key, selected_ceiling_tile])
				data.set_ceiling_tile_index(i, selected_ceiling_tile)

	# Handle pillar rooms (maintain existing behavior)
	for _room in pillar_rooms:
		var room : Rect2 = _room as Rect2
		for i in room.size.x / 2:
			for j in room.size.y / 2:
				var cell = data.get_cell_index_from_int_position(room.position.x + 2 * i, room.position.y + 2 * j)
				data.set_ceiling_tile_index(cell, pillar_room_double_ceiling_tile)


func select_wall_tiles(data : WorldData, rng : RandomNumberGenerator):
	# For each cell id, store the edges that were already populated
	var done_edges : Dictionary = {}
	for i in data.cell_count:
		var type = data.get_cell_type(i)
		if type == data.CellType.EMPTY:
			continue
		var is_pillar_room = data.get_cell_meta(i, data.CellMetaKeys.META_PILLAR_ROOM, false)
		if not is_pillar_room:
			var done_edges_for_cell : Array = done_edges.get(i, [])
			if not done_edges.has(i):
				done_edges[i] = done_edges_for_cell
			for dir in data.Direction.DIRECTION_MAX:
				var neighbour = data.get_neighbour_cell(i, dir)
				var neighbour_is_pillar_room = data.get_cell_meta(neighbour, data.CellMetaKeys.META_PILLAR_ROOM, false)
				match data.get_wall_type(i, dir):
					data.EdgeType.WALL:
						var wall_extension = []
						# check how far the wall extends to the left
						var extension_dir = WorldData.ROTATE_LEFT[dir]
						var extension_cell = i
						while true:
							if not data.get_wall_type(extension_cell, extension_dir) == data.EdgeType.EMPTY:
								break
							extension_cell = data.get_neighbour_cell(extension_cell, extension_dir)
							if not data.get_wall_type(extension_cell, dir) == data.EdgeType.WALL:
								break
							wall_extension.push_back(extension_cell)
						wall_extension.reverse()
						wall_extension.push_back(i)

						# check how far the wall extends to the right
						extension_dir = WorldData.ROTATE_RIGHT[dir]
						extension_cell = i
						while true:
							if not data.get_wall_type(extension_cell, extension_dir) == data.EdgeType.EMPTY:
								break
							extension_cell = data.get_neighbour_cell(extension_cell, extension_dir)
							if not data.get_wall_type(extension_cell, dir) == data.EdgeType.WALL:
								break
							wall_extension.push_back(extension_cell)

						# Even width wall, can use double tiles
						if wall_extension.size() % 2 == 0:
							for _index in wall_extension.size() / 2:
								var cell_left = wall_extension[2 * _index]
								var cell_right = wall_extension[2 * _index + 1]
								var rnd = rng.randf()
								var selected_wall_tile : int = double_wall_tile
								if rnd < alternative_double_wall_tile_chance and alternative_double_wall_tiles.size() > 0:
									var index : int = rng.randi() % alternative_double_wall_tiles.size()
									selected_wall_tile = alternative_double_wall_tiles[index]
								data.set_wall_tile_index(cell_left, dir, selected_wall_tile)
								for _cell in [cell_left, cell_right]:
									var done_edges_for_extension = done_edges.get(_cell, []) as Array
									done_edges_for_extension.push_back(dir)
									if not done_edges.has(_cell):
										done_edges[_cell] = done_edges_for_extension

						else:
							var rnd = rng.randf()
							var selected_wall_tile : int = wall_tile
							if rnd < alternative_wall_tile_chance and alternative_wall_tiles.size() > 0:
								var index : int = rng.randi() % alternative_wall_tiles.size()
								selected_wall_tile = alternative_wall_tiles[index]
							data.set_wall_tile_index(i, dir, selected_wall_tile)
					data.EdgeType.DOOR:
						data.set_wall_tile_index(i, dir, door_tile)
						data.set_wall_meta(i, dir, door_width)
					data.EdgeType.HALFDOOR_P:
						if neighbour_is_pillar_room:
							continue
						if dir == data.Direction.NORTH or dir == data.Direction.EAST:
							data.set_wall_tile_index(i, dir, double_door_tile)
						data.set_wall_meta(i, dir, double_door_width)
					data.EdgeType.HALFDOOR_N:
						if neighbour_is_pillar_room:
							continue
						if dir == data.Direction.SOUTH or dir == data.Direction.WEST:
							data.set_wall_tile_index(i, dir, double_door_tile)
						data.set_wall_meta(i, dir, double_door_width)


## Apply special wall tiles for borders between CORRIDOR and ROOM cell types
## New simplified approach: Find ROOM cells with double walls, check if both neighbors are CORRIDOR cells
func apply_special_border_walls(data : WorldData):
	print("DEBUG: apply_special_border_walls() starting with tile index: %d" % corridor_room_border_wall_tile)
	
	# Skip if no special border wall tile is configured
	if corridor_room_border_wall_tile == -1:
		print("DEBUG: Early exit - no corridor_room_border_wall_tile configured (tile index is -1)")
		return
	
	var room_cells_with_double_walls : int = 0
	var double_walls_checked : int = 0
	var arch_walls_applied : int = 0
	
	# Iterate through all ROOM cells
	for i in data.cell_count:
		var cell_type = data.get_cell_type(i)
		if cell_type != data.CellType.ROOM:
			continue
		
		var cell_pos = data.get_int_position_from_cell_index(i)
		var has_double_walls : bool = false
		
		# Check all 4 directions for double walls placed by select_wall_tiles()
		for dir in data.Direction.DIRECTION_MAX:
			var wall_tile_index = data.get_wall_tile_index(i, dir)
			
			# Check if there's a double wall tile placed (not -1)
			if wall_tile_index != -1:
				# Check if this is actually a double wall tile (including pillar room double walls)
				if (wall_tile_index == double_wall_tile or
					alternative_double_wall_tiles.has(wall_tile_index) or
					wall_tile_index == pillar_room_double_wall_tile):
					has_double_walls = true
					double_walls_checked += 1
					
					var dir_name = ["NORTH", "EAST", "SOUTH", "WEST"][dir]
					print("DEBUG: Found ROOM cell at (%d,%d) with double wall in direction %s (tile_id: %d)" % [cell_pos[0], cell_pos[1], dir_name, wall_tile_index])
					
					# Get the neighbor cell in that direction
					var neighbor_cell = data.get_neighbour_cell(i, dir)
					if neighbor_cell == -1:
						print("DEBUG: Skipping - no neighbor cell (edge of map)")
						continue
					
					var neighbor_type = data.get_cell_type(neighbor_cell)
					var neighbor_pos = data.get_int_position_from_cell_index(neighbor_cell)
					
					# Check if the neighbor is a CORRIDOR cell
					if neighbor_type != data.CellType.CORRIDOR:
						print("DEBUG: Skipping - neighbor at (%d,%d) is not CORRIDOR (type: %d)" % [neighbor_pos[0], neighbor_pos[1], neighbor_type])
						continue
					
					# Check if either the room cell or corridor neighbor is a staircase - skip if so
					# Check room data type instead of metadata
					var room_data = data.get_cell_meta(i, data.CellMetaKeys.META_ROOM_DATA) as RoomData
					var room_is_stairs = room_data != null and room_data.is_staircase_room()
					
					var corridor_room_data = data.get_cell_meta(neighbor_cell, data.CellMetaKeys.META_ROOM_DATA) as RoomData
					var corridor_is_stairs = corridor_room_data != null and corridor_room_data.is_staircase_room()
					
					if room_is_stairs or corridor_is_stairs:
						print("DEBUG: Skipping - staircase room detected (room: %s, corridor: %s)" % [str(room_is_stairs), str(corridor_is_stairs)])
						continue
					
					# For double walls, we need to find the wall extension to determine the second cell
					# Use the same logic as select_wall_tiles() to find the wall extension
					var wall_extension = []
					
					# Check how far the wall extends to the left
					var extension_dir = WorldData.ROTATE_LEFT[dir]
					var extension_cell = i
					while true:
						if not data.get_wall_type(extension_cell, extension_dir) == data.EdgeType.EMPTY:
							break
						extension_cell = data.get_neighbour_cell(extension_cell, extension_dir)
						if not data.get_wall_type(extension_cell, dir) == data.EdgeType.WALL:
							break
						wall_extension.push_back(extension_cell)
					
					wall_extension.reverse()
					wall_extension.push_back(i)
					
					# Check how far the wall extends to the right
					extension_dir = WorldData.ROTATE_RIGHT[dir]
					extension_cell = i
					while true:
						if not data.get_wall_type(extension_cell, extension_dir) == data.EdgeType.EMPTY:
							break
						extension_cell = data.get_neighbour_cell(extension_cell, extension_dir)
						if not data.get_wall_type(extension_cell, dir) == data.EdgeType.WALL:
							break
						wall_extension.push_back(extension_cell)
					
					# Find which pair this cell belongs to in the wall extension
					var current_index = wall_extension.find(i)
					if current_index == -1:
						print("DEBUG: Skipping - current cell not found in wall extension")
						continue
					
					# For even-length walls, double tiles are placed on left cells (even indices)
					# Find the pair index for this cell
					var pair_index = current_index / 2
					var is_left_cell = (current_index % 2 == 0)
					
					if wall_extension.size() % 2 != 0:
						print("DEBUG: Skipping - wall extension has odd length (%d), no double wall pairs" % wall_extension.size())
						continue
					
					# Get both cells in the pair
					var cell_left = wall_extension[2 * pair_index]
					var cell_right = wall_extension[2 * pair_index + 1]
					var second_cell = cell_right if is_left_cell else cell_left
					
					# Get the neighbor of the second cell
					var second_neighbor = data.get_neighbour_cell(second_cell, dir)
					if second_neighbor == -1:
						print("DEBUG: Skipping - no second neighbor cell (edge of map)")
						continue
					
					var second_neighbor_type = data.get_cell_type(second_neighbor)
					var second_neighbor_pos = data.get_int_position_from_cell_index(second_neighbor)
					var second_cell_pos = data.get_int_position_from_cell_index(second_cell)
					
					# Check if the second neighbor is also a CORRIDOR cell
					if second_neighbor_type != data.CellType.CORRIDOR:
						print("DEBUG: Skipping - second neighbor at (%d,%d) is not CORRIDOR (type: %d)" % [second_neighbor_pos[0], second_neighbor_pos[1], second_neighbor_type])
						continue
					
					# Also check if the second corridor neighbor is a staircase
					var second_corridor_room_data = data.get_cell_meta(second_neighbor, data.CellMetaKeys.META_ROOM_DATA) as RoomData
					var second_corridor_is_stairs = second_corridor_room_data != null and second_corridor_room_data.is_staircase_room()
					
					if second_corridor_is_stairs:
						print("DEBUG: Skipping - second corridor neighbor at (%d,%d) is a staircase room" % [second_neighbor_pos[0], second_neighbor_pos[1]])
						continue
					
					print("DEBUG: Both neighbors are CORRIDOR cells - applying arch wall tiles")
					print("  - ROOM cell pair: (%d,%d) and (%d,%d)" % [cell_pos[0], cell_pos[1], second_cell_pos[0], second_cell_pos[1]])
					print("  - First CORRIDOR neighbor: (%d,%d)" % [neighbor_pos[0], neighbor_pos[1]])
					print("  - Second CORRIDOR neighbor: (%d,%d)" % [second_neighbor_pos[0], second_neighbor_pos[1]])
					print("  - Current cell is %s of pair" % ("left" if is_left_cell else "right"))
					
					# Replace the wall tiles with arch wall tiles
					# For double walls, the tile is placed on the left cell of the pair
					# Set the ROOM side double wall to corridor_room_border_wall_tile
					data.set_wall_tile_index(cell_left, dir, corridor_room_border_wall_tile)
					print("DEBUG: Applied arch wall tile to ROOM side at (%d,%d) direction %s (left cell of pair)" % [data.get_int_position_from_cell_index(cell_left)[0], data.get_int_position_from_cell_index(cell_left)[1], dir_name])
					
					# Set the CORRIDOR side double wall to corridor_room_border_wall_tile
					# For double walls, we need to handle both cells in the corridor pair
					var opposite_dir = data.direction_inverse(dir)
					
					# The corridor neighbor that corresponds to the left cell of the room pair
					# should be the second_neighbor (which corresponds to cell_right on room side)
					var corridor_target_cell = second_neighbor
					
					# Apply arch wall to the target corridor cell
					data.set_wall_tile_index(corridor_target_cell, opposite_dir, corridor_room_border_wall_tile)
					print("DEBUG: Applied arch wall tile to CORRIDOR side at (%d,%d) direction %s (matching room pair structure)" % [second_neighbor_pos[0], second_neighbor_pos[1], ["NORTH", "EAST", "SOUTH", "WEST"][opposite_dir]])
					
					# Also clear the wall tile on the first corridor neighbor to prevent overlapping walls
					# This prevents the extra 1*CELL_SIZE wall from spawning on the right side
					data.set_wall_tile_index(neighbor_cell, opposite_dir, -1)
					print("DEBUG: Cleared overlapping wall tile at CORRIDOR cell (%d,%d) direction %s" % [neighbor_pos[0], neighbor_pos[1], ["NORTH", "EAST", "SOUTH", "WEST"][opposite_dir]])
					
					# Use combined arch+grate tile approach instead of spawn system
					# Place arch+grate tile on left cell of room pair, open arch on right cell
					if corridor_room_border_arch_grate_tile != -1:
						# Replace the left cell (where double wall tile is placed) with arch+grate tile
						data.set_wall_tile_index(cell_left, dir, corridor_room_border_arch_grate_tile)
						print("DEBUG: Applied combined arch+grate tile to ROOM side at (%d,%d) direction %s (left cell of pair)" % [data.get_int_position_from_cell_index(cell_left)[0], data.get_int_position_from_cell_index(cell_left)[1], dir_name])
					
					arch_walls_applied += 2  # Count both sides
		
		if has_double_walls:
			room_cells_with_double_walls += 1
	
	# Debug: Print summary
	print("DEBUG: apply_special_border_walls() summary:")
	print("  - ROOM cells with double walls found: %d" % room_cells_with_double_walls)
	print("  - Double walls checked: %d" % double_walls_checked)
	print("  - Arch wall tiles applied: %d" % arch_walls_applied)


func select_pillar_room_walls(data : WorldData, pillar_rooms : Array):
	for _room_rect in pillar_rooms:
		var room_rect : Rect2 = _room_rect as Rect2
		for i in room_rect.size.x / 2:
				# North
				var dir = data.Direction.NORTH
				var side = data.direction_rotate_cw(dir)
				var inv_dir = data.direction_inverse(dir)
				var cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * i, room_rect.position.y)
				var wall_type = data.get_wall_type(cell, dir)
				match wall_type:
					data.EdgeType.WALL:
						data.set_wall_tile_index(cell, dir, pillar_room_double_wall_tile)
					data.EdgeType.HALFDOOR_P:
						data.set_wall_tile_index(cell, dir, pillar_room_double_door_tile)
						data.set_wall_meta(cell, dir, pillar_room_double_door_width)
						var side_cell = data.get_neighbour_cell(cell, side)
						data.set_wall_meta(side_cell, dir, pillar_room_double_door_width)
						var other_cell = data.get_neighbour_cell(side_cell, dir)
						data.set_wall_tile_index(other_cell, inv_dir, pillar_room_double_door_tile)
					_:
						pass
				# South
				dir = data.Direction.SOUTH
				side = data.direction_rotate_cw(dir)
				inv_dir = data.direction_inverse(dir)
				cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * i + 1, room_rect.position.y + room_rect.size.y - 1)
				wall_type = data.get_wall_type(cell, dir)
				match wall_type:
					data.EdgeType.WALL:
						data.set_wall_tile_index(cell, dir, pillar_room_double_wall_tile)
					data.EdgeType.HALFDOOR_N:
						data.set_wall_tile_index(cell, dir, pillar_room_double_door_tile)
						data.set_wall_meta(cell, dir, pillar_room_double_door_width)
						var side_cell = data.get_neighbour_cell(cell, side)
						data.set_wall_meta(side_cell, dir, pillar_room_double_door_width)
						var other_cell = data.get_neighbour_cell(side_cell, dir)
						data.set_wall_tile_index(other_cell, inv_dir, pillar_room_double_door_tile)
					_:
						pass
		for i in room_rect.size.y / 2:
				# West
				var dir = data.Direction.WEST
				var side = data.direction_rotate_cw(dir)
				var inv_dir = data.direction_inverse(dir)
				var cell = data.get_cell_index_from_int_position(room_rect.position.x, room_rect.position.y + 2 * i + 1)
				var wall_type = data.get_wall_type(cell, dir)
				match wall_type:
					data.EdgeType.WALL:
						data.set_wall_tile_index(cell, dir, pillar_room_double_wall_tile)
					data.EdgeType.HALFDOOR_N:
						data.set_wall_tile_index(cell, dir, pillar_room_double_door_tile)
						data.set_wall_meta(cell, dir, pillar_room_double_door_width)
						var side_cell = data.get_neighbour_cell(cell, side)
						data.set_wall_meta(side_cell, dir, pillar_room_double_door_width)
						var other_cell = data.get_neighbour_cell(side_cell, dir)
						data.set_wall_tile_index(other_cell, inv_dir, pillar_room_double_door_tile)
					_:
						pass
				# East
				dir = data.Direction.EAST
				side = data.direction_rotate_cw(dir)
				inv_dir = data.direction_inverse(dir)
				cell = data.get_cell_index_from_int_position(room_rect.position.x + room_rect.size.x - 1 , room_rect.position.y + 2 * i)
				wall_type = data.get_wall_type(cell, dir)
				match wall_type:
					data.EdgeType.WALL:
						data.set_wall_tile_index(cell, dir, pillar_room_double_wall_tile)
					data.EdgeType.HALFDOOR_P:
						data.set_wall_tile_index(cell, dir, pillar_room_double_door_tile)
						data.set_wall_meta(cell, dir, pillar_room_double_door_width)
						var side_cell = data.get_neighbour_cell(cell, side)
						data.set_wall_meta(side_cell, dir, pillar_room_double_door_width)
						var other_cell = data.get_neighbour_cell(side_cell, dir)
						data.set_wall_tile_index(other_cell, inv_dir, pillar_room_double_door_tile)
					_:
						pass


func place_pillars(data : WorldData):
	for x in range(1, data.get_size_x()):
		for z in range(1, data.get_size_z()):
			var i = data.get_cell_index_from_int_position(x, z)
			var n = data.get_neighbour_cell(i, data.Direction.NORTH)
			var w = data.get_neighbour_cell(i, data.Direction.WEST)
			var nw = data.get_neighbour_cell(w, data.Direction.NORTH)
			# walls in a cross around the potential pillar
			var wall_n = data.get_wall_type(n, data.Direction.WEST)
			var wall_e = data.get_wall_type(i, data.Direction.NORTH)
			var wall_s = data.get_wall_type(i, data.Direction.WEST)
			var wall_w = data.get_wall_type(w, data.Direction.NORTH)

			# wether the walls touch the potential pillar spot
			var edge_n = not (wall_n == data.EdgeType.EMPTY or wall_n == data.EdgeType.HALFDOOR_P)
			var edge_e = not (wall_e == data.EdgeType.EMPTY or wall_e == data.EdgeType.HALFDOOR_N)
			var edge_s = not (wall_s == data.EdgeType.EMPTY or wall_s == data.EdgeType.HALFDOOR_N)
			var edge_w = not (wall_w == data.EdgeType.EMPTY or wall_w == data.EdgeType.HALFDOOR_P)

			# place pillar if there's an edge
			var place_pillar = edge_n or edge_e or edge_s or edge_w
			# but not on a straight line
			place_pillar = place_pillar and not (edge_n and edge_s)
			place_pillar = place_pillar and not (edge_e and edge_w)
#			if not place_pillar:
#				if not [
#					data.get_cell_type(i),
#					data.get_cell_type(n),
#					data.get_cell_type(w),
#					data.get_cell_type(nw)
#				].has(data.CellType.EMPTY):
#					place_pillar = randf() < 0.05
			if place_pillar:
				data.set_pillar(i, pillar_tile, 0.3)


func place_pillar_room_pillars(data : WorldData, pillar_rooms : Array):
	for _room_rect in pillar_rooms:
		var room_rect : Rect2 = _room_rect as Rect2
		for i in (room_rect.size.x / 2 - 1):
			for j in (room_rect.size.y / 2 - 1):
				var cell = data.get_cell_index_from_int_position(room_rect.position.x + 2 * (i + 1), room_rect.position.y + 2 * (j+1))
				data.set_pillar(cell, pillar_room_pillar_tile, 0.3)
#	for x in range(1, data.get_size_x()):
#		for z in range(1, data.get_size_z()):
#			var i = data.get_cell_index_from_int_position(x, z)
#			var n = data.get_neighbour_cell(i, data.Direction.NORTH)
#			var w = data.get_neighbour_cell(i, data.Direction.WEST)
#			var nw = data.get_neighbour_cell(w, data.Direction.NORTH)
#			# walls in a cross around the potential pillar
#			var wall_n = data.get_wall_type(n, data.Direction.WEST)
#			var wall_e = data.get_wall_type(i, data.Direction.NORTH)
#			var wall_s = data.get_wall_type(i, data.Direction.WEST)
#			var wall_w = data.get_wall_type(w, data.Direction.NORTH)
#
#			# wether the walls touch the potential pillar spot
#			var edge_n = not (wall_n == data.EdgeType.EMPTY or wall_n == data.EdgeType.HALFDOOR_P)
#			var edge_e = not (wall_e == data.EdgeType.EMPTY or wall_e == data.EdgeType.HALFDOOR_N)
#			var edge_s = not (wall_s == data.EdgeType.EMPTY or wall_s == data.EdgeType.HALFDOOR_N)
#			var edge_w = not (wall_w == data.EdgeType.EMPTY or wall_w == data.EdgeType.HALFDOOR_P)
#
#			# place pillar if there's an edge
#			var place_pillar = edge_n or edge_e or edge_s or edge_w
#			# but not on a straight line
#			place_pillar = place_pillar and not (edge_n and edge_s)
#			place_pillar = place_pillar and not (edge_e and edge_w)
##			if not place_pillar:
##				if not [
##					data.get_cell_type(i),
##					data.get_cell_type(n),
##					data.get_cell_type(w),
##					data.get_cell_type(nw)
##				].has(data.CellType.EMPTY):
##					place_pillar = randf() < 0.05
#			if place_pillar:
#				data.set_pillar(i, pillar_tile, 0.3)
