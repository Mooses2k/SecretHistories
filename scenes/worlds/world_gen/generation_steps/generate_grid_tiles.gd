extends GenerationStep


export var floor_tile : int = -1
export var wall_tile : int = -1
export(Array, int) var alternative_wall_tiles : Array = []
export var alternative_wall_tile_chance : float = 0.05
export var double_wall_tile : int = -1
export(Array, int) var alternative_double_wall_tiles : Array = []
export var alternative_double_wall_tile_chance : float = 0.05
export var door_tile : int = -1
export var door_width : float = 0.0
export var double_door_tile : int = -1
export var double_door_width : float = 0.0
export var ceiling_tile : int = -1

export var pillar_room_double_wall_tile : int = -1
export var pillar_room_double_door_tile : int = -1
export var pillar_room_double_door_width : float = 0.0
export var pillar_room_double_ceiling_tile : int = -1
export var pillar_room_double_floor_tile : int = -1
export var pillar_room_pillar_tile : int = -1
export var pillar_tile : int = -1

const PillarRoomGenerator = preload("res://scenes/worlds/world_gen/generation_steps/generate_room_pillars.gd")


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var pillar_rooms = gen_data.get(PillarRoomGenerator.PILLAR_ROOMS_KEY, Array())
	print(pillar_rooms)
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = generation_seed
	select_floor_tiles(data, pillar_rooms)
	select_ceiling_tiles(data, pillar_rooms)
	select_wall_tiles(data, rng)
	select_pillar_room_walls(data, pillar_rooms)
	place_pillars(data)
	place_pillar_room_pillars(data, pillar_rooms)


func select_floor_tiles(data : WorldData, pillar_rooms : Array):
	for i in data.cell_count:
		var cell_type = data.get_cell_type(i)
		var is_pillar_room = data.get_cell_meta(i, data.CellMetaKeys.META_PILLAR_ROOM, false)
		var is_stairs_down = data.get_cell_meta(i, data.CellMetaKeys.META_IS_DOWN_STAIRCASE, false)
		if cell_type != data.CellType.EMPTY and not is_pillar_room and not is_stairs_down:
			if cell_type == data.CellType.ROOM:
				data.set_cell_surfacetype(i, data.SurfaceType.STONE)
			elif cell_type == data.CellType.CORRIDOR:
				data.set_cell_surfacetype(i, data.SurfaceType.CARPET)
			data.set_ground_tile_index(i, floor_tile)
	for _room in pillar_rooms:
		var room : Rect2 = _room as Rect2
		print("pillar_room: %s"%[room])
		for i in room.size.x / 2:
			for j in room.size.y / 2:
				var cell = data.get_cell_index_from_int_position(room.position.x + 2 * i, room.position.y + 2 * j)
				data.set_ground_tile_index(cell, pillar_room_double_floor_tile)


func select_ceiling_tiles(data : WorldData, pillar_rooms : Array):
	for i in data.cell_count:
		if data.get_cell_type(i) != data.CellType.EMPTY:
			var is_pillar_room = data.get_cell_meta(i, data.CellMetaKeys.META_PILLAR_ROOM, false)
			if not is_pillar_room:
				data.set_ceiling_tile_index(i, ceiling_tile)
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
						wall_extension.invert()
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
						if wall_extension.size()%2 == 0:
							for _index in wall_extension.size()/2:
								var cell_left = wall_extension[2*_index]
								var cell_right = wall_extension[2*_index + 1]
								var rnd = fposmod(rng.randf(), 1.0)
								var selected_wall_tile : int = double_wall_tile
								if rnd < alternative_double_wall_tile_chance and alternative_double_wall_tiles.size() > 0:
									var index : int = rng.randi()%alternative_double_wall_tiles.size()
									selected_wall_tile = alternative_double_wall_tiles[index]
									print("Selected wall ", index)
								data.set_wall_tile_index(cell_left, dir, selected_wall_tile)
								for _cell in [cell_left, cell_right]:
									var done_edges_for_extension = done_edges.get(_cell, []) as Array
									done_edges_for_extension.push_back(dir)
									if not done_edges.has(_cell):
										done_edges[_cell] = done_edges_for_extension
								
						else:
							var rnd = fposmod(rng.randf(), 1.0)
							var selected_wall_tile : int = wall_tile
							if rnd < alternative_wall_tile_chance and alternative_wall_tiles.size() > 0:
									var index : int = rng.randi()%alternative_wall_tiles.size()
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
						data.set_wall_meta(cell, dir, 0.8)
						var side_cell = data.get_neighbour_cell(cell, side)
						data.set_wall_meta(side_cell, dir, 0.8)
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
						data.set_wall_meta(cell, dir, 0.8)
						var side_cell = data.get_neighbour_cell(cell, side)
						data.set_wall_meta(side_cell, dir, 0.8)
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
