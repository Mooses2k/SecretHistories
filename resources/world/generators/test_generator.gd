extends WorldGenerator

export var room_size : int = 4
export var corridor_length : int = 3

export var ground_index : int
export var wall_index : int
export var doorway_index : int
export var cover_index : int
export var corner_index : int

# Generates a world in this format, with doorways connecting the corridor do the rooms
# ┌─────┐    ┌─────┐ ┌─
# │     │    │     │ │ ROOM SIZE
# │     ├────┤     │ │
# └───┬─┼────┼─┬───┘ ├─
#     │ │    │ │     │ CORRIDOR SIZE
#     │ │    │ │     │
# ┌───┴─┼────┼─┴───┐ └─
# │     ├────┤     │
# │     │    │     │
# └─────┘    └─────┘

func get_data() -> WorldData:
	var data = WorldData.new()
	var world_x = room_size*2 + corridor_length + 2
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
				data.set_wall(i, dir)
			data.ceiling_tile_index[i] = GridMap.INVALID_CELL_ITEM
	for x in world_x + 1:
		for z in world_z + 1:
			var i = data.get_pillar_index_from_int_position(x, z)
			data.pillar_tile_index[i] = GridMap.INVALID_CELL_ITEM
	#generate world
	for x in world_x:
		for z in world_z:
			var i = data.get_cell_index_from_int_position(x, z)
			var mirror_x = world_x - x - 1
			var mirror_z = world_z - z - 1
			var min_x = min(x, mirror_x)
			var min_z = min(z, mirror_z)
			#make rooms
			if min_x > 0 and min_x <= room_size and min_z > 0 and min_z <= room_size:
				data.is_cell_free[i] = 1
				data.ground_tile_index[i] = ground_index
				for dir in WorldData.Direction.DIRECTION_MAX:
					var needs_wall
					match dir:
						WorldData.Direction.NORTH:
							needs_wall = z == 1 or mirror_z == room_size
						WorldData.Direction.SOUTH:
							needs_wall = mirror_z == 1 or z == room_size
						WorldData.Direction.WEST:
							needs_wall = x == 1 or mirror_x == room_size
						WorldData.Direction.EAST:
							needs_wall = mirror_x == 1 or x == room_size
					if needs_wall:
						data.set_wall(i, dir, WorldData.EdgeType.WALL, wall_index)
	for x in world_x:
		for z in world_z:
			var i = data.get_cell_index_from_int_position(x, z)
			var mirror_x = world_x - x - 1
			var mirror_z = world_z - z - 1
			var min_x = min(x, mirror_x)
			var min_z = min(z, mirror_z)
			#make corridors (NS)
			if min_x == room_size and z > room_size and mirror_z > room_size:
				data.is_cell_free[i] = 1
				data.ground_tile_index[i] = ground_index
				data.set_wall(i, WorldData.Direction.EAST, WorldData.EdgeType.WALL, wall_index)
				data.set_wall(i, WorldData.Direction.WEST, WorldData.EdgeType.WALL, wall_index)
				if z == room_size + 1:
					data.set_wall(i, WorldData.Direction.NORTH, WorldData.EdgeType.DOOR, doorway_index, 0.8)
					var n = data.get_neighbour_cell(i, WorldData.Direction.NORTH)
					data.set_wall_tile_index(n, WorldData.Direction.SOUTH, doorway_index)
				if mirror_z == room_size + 1:
					data.set_wall(i, WorldData.Direction.SOUTH, WorldData.EdgeType.DOOR, doorway_index, 0.8)
					var s = data.get_neighbour_cell(i, WorldData.Direction.SOUTH)
					data.set_wall_tile_index(s, WorldData.Direction.NORTH, doorway_index)
			if min_z == room_size and x > room_size and mirror_x > room_size:
				data.is_cell_free[i] = 1
				data.ground_tile_index[i] = ground_index
				data.set_wall(i, WorldData.Direction.NORTH, WorldData.EdgeType.WALL, wall_index)
				data.set_wall(i, WorldData.Direction.SOUTH, WorldData.EdgeType.WALL, wall_index)
				if x == room_size + 1:
					data.set_wall(i, WorldData.Direction.WEST, WorldData.EdgeType.DOOR, doorway_index, 0.8)
					var w = data.get_neighbour_cell(i, WorldData.Direction.WEST)
					data.set_wall_tile_index(w, WorldData.Direction.EAST, doorway_index)
				if mirror_x == room_size + 1:
					data.set_wall(i, WorldData.Direction.EAST, WorldData.EdgeType.DOOR, doorway_index, 0.8)
					var e = data.get_neighbour_cell(i, WorldData.Direction.EAST)
					data.set_wall_tile_index(e, WorldData.Direction.WEST, doorway_index)
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
	return data
