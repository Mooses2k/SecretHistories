extends GenerationStep


export var floor_tile : int = -1
export var wall_tile : int = -1
export var double_wall_tile : int = -1
export var door_tile : int = -1
export var double_door_tile : int = -1
export var pillar_tile : int = -1
export var ceiling_tile : int = -1


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	select_floor_tiles(data)
	select_ceiling_tiles(data)
	select_wall_tiles(data)
	place_pillars(data)
	pass


func select_floor_tiles(data : WorldData):
	for i in data.cell_count:
		if data.get_cell_type(i) != data.CellType.EMPTY:
			data.set_ground_tile_index(i, floor_tile)


func select_ceiling_tiles(data : WorldData):
	for i in data.cell_count:
		if data.get_cell_type(i) != data.CellType.EMPTY:
			data.set_ceiling_tile_index(i, ceiling_tile)


func select_wall_tiles(data : WorldData):
	for i in data.cell_count:
		for dir in data.Direction.DIRECTION_MAX:
			match data.get_wall_type(i, dir):
				data.EdgeType.WALL:
					data.set_wall_tile_index(i, dir, wall_tile)
				data.EdgeType.DOOR:
					data.set_wall_tile_index(i, dir, door_tile)
					data.set_wall_meta(i, dir, 0.8)
				data.EdgeType.HALFDOOR_P:
					if dir == data.Direction.NORTH or dir == data.Direction.EAST:
						data.set_wall_tile_index(i, dir, double_door_tile)
					data.set_wall_meta(i, dir, 0.8)
				data.EdgeType.HALFDOOR_N:
					if dir == data.Direction.SOUTH or dir == data.Direction.WEST:
						data.set_wall_tile_index(i, dir, double_door_tile)
					data.set_wall_meta(i, dir, 0.8)


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
