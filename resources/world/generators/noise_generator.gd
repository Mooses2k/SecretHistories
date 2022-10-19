extends WorldGenerator

export var world_size : int = 4
export var lower_threshold : float = 0.3
export var higher_threshold : float = 0.7
export var noise : OpenSimplexNoise
export var pillar_try_count : int = 32
export var ground_index : int
export var wall_index : int
export var doorway_index : int
export var cover_index : int
export var corner_index : int

func get_data() -> WorldData:
	var data = WorldData.new()
	var world_x = world_size
	var world_z = world_x
	data.world_size_x = world_x
	data.world_size_z = world_z

	#clear data
	for x in world_x:
		for z in world_z:
			var i = data.get_cell_index_from_int_position(x, z)
			data.is_cell_free[i] = 0
			data.ground_tile_index[i] = cover_index
			for dir in WorldData.Direction.DIRECTION_MAX:
				data.set_wall_type(i, dir, WorldData.EdgeType.EMPTY)
				data.set_wall_tile_index(i, dir, GridMap.INVALID_CELL_ITEM)
			data.ceiling_tile_index[i] = GridMap.INVALID_CELL_ITEM
	for x in world_x + 1:
		for z in world_z + 1:
			var i = data.get_pillar_index_from_int_position(x, z)
			data.pillar_tile_index[i] = GridMap.INVALID_CELL_ITEM
	#generate world
	for x in range(1, world_x - 1):
		for z in range(1, world_z - 1):
			var value = noise.get_noise_2d(x, z)
			if value > lower_threshold and value < higher_threshold:
				var cell = data.get_cell_index_from_int_position(x, z)
				data.is_cell_free[cell] = 1
				data.ground_tile_index[cell] = ground_index
	for x in world_x:
		for z in world_z:
			var cell = data.get_cell_index_from_int_position(x, z)
			if data.is_cell_free[cell] == 1:
				for dir in WorldData.Direction.DIRECTION_MAX:
					var neighbour = data.get_neighbour_cell(cell, dir)
					if data.is_cell_free[neighbour] == 0:
						data.set_wall(cell, dir, WorldData.EdgeType.WALL, wall_index)
	#add corner pillars
	for x in world_x:
		for z in world_z:
			var i = data.get_cell_index_from_int_position(x, z)
			var mirror_x = world_x - x - 1
			var mirror_z = world_z - z - 1
			var min_x = min(x, mirror_x)
			var min_z = min(z, mirror_z)
			var n = data.get_wall_type(i, WorldData.Direction.NORTH)
			var s = data.get_wall_type(i, WorldData.Direction.SOUTH)
			var e = data.get_wall_type(i, WorldData.Direction.EAST)
			var w = data.get_wall_type(i, WorldData.Direction.WEST)
			if n != WorldData.EdgeType.EMPTY and w != WorldData.EdgeType.EMPTY:
				var p = data.get_pillar_index_from_int_position(x, z)
				data.pillar_tile_index[p] = corner_index
				data.pillar_radius[p] = 0.2
			if w != WorldData.EdgeType.EMPTY and s != WorldData.EdgeType.EMPTY:
				var p = data.get_pillar_index_from_int_position(x, z + 1)
				data.pillar_tile_index[p] = corner_index
				data.pillar_radius[p] = 0.2
			if s != WorldData.EdgeType.EMPTY and e != WorldData.EdgeType.EMPTY:
				var p = data.get_pillar_index_from_int_position(x + 1, z + 1)
				data.pillar_tile_index[p] = corner_index
				data.pillar_radius[p] = 0.2
			if e != WorldData.EdgeType.EMPTY and n != WorldData.EdgeType.EMPTY:
				var p = data.get_pillar_index_from_int_position(x + 1, z)
				data.pillar_tile_index[p] = corner_index
				data.pillar_radius[p] = 0.2
	#add random pillars
	var rand = RandomNumberGenerator.new()
	rand.seed = noise.seed
	for i in pillar_try_count:
		var x = randi()%data.world_size_x
		var z = randi()%data.world_size_z
		var cell = data.get_cell_index_from_int_position(x, z)
		if data.is_cell_free[cell]:
			#cell to the north_west
			var nw = data.get_neighbour_cell(data.get_neighbour_cell(cell, WorldData.Direction.NORTH), WorldData.Direction.WEST)
			#walls around the potential pillar
			var n_wall = data.get_wall_type(nw, WorldData.Direction.EAST)
			var s_wall = data.get_wall_type(cell, WorldData.Direction.WEST)
			var e_wall = data.get_wall_type(cell, WorldData.Direction.NORTH)
			var w_wall = data.get_wall_type(nw, WorldData.Direction.SOUTH)
			var empty = WorldData.EdgeType.EMPTY
			if n_wall == s_wall and s_wall == e_wall and e_wall == w_wall and w_wall == empty:
				data.set_pillar(data.get_pillar_index_from_int_position(x,z), corner_index, 0.2)
	return data
