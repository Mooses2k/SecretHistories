extends GenerationStep

# Generates walls based on certain adjacency rules

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	contour_walls(data)
	pass

func contour_walls(data : WorldData):
	for x in range(1, data.world_size_x - 1):
		for y in range(1, data.world_size_z - 1):
			var this = data.get_cell_index_from_int_position(x, y)
			if data.get_cell_type(this) == data.CellType.EMPTY:
				continue
			for dir in data.Direction.DIRECTION_MAX:
				var other = data.get_cell_type(data.get_neighbour_cell(this, dir))
				match data.get_cell_type(this):
					data.CellType.ROOM:
						match other:
							data.CellType.EMPTY, data.CellType.CORRIDOR, data.CellType.HALL:
								data.set_wall(this, dir, data.EdgeType.WALL)
							_:
								pass
					data.CellType.CORRIDOR, data.CellType.HALL:
						match other:
							data.CellType.EMPTY, data.CellType.ROOM:
								data.set_wall(this, dir, data.EdgeType.WALL)
							_:
								pass
					data.CellType.DOOR:
						var n = data.get_neighbour_cell(this, data.Direction.NORTH)
						var e = data.get_neighbour_cell(this, data.Direction.EAST)
						var s = data.get_neighbour_cell(this, data.Direction.SOUTH)
						var w = data.get_neighbour_cell(this, data.Direction.WEST)
						match other:
							data.CellType.ROOM:
								if data.get_cell_meta(this).has(dir):
									var extends_right = false
									var extends_left = false
									var r = data.get_neighbour_cell(this, data.direction_rotate_cw(dir))
									var l = data.get_neighbour_cell(this, data.direction_rotate_ccw(dir))
									if data.get_cell_type(r) == data.CellType.DOOR:
										if data.get_cell_meta(r).has(dir):
											extends_right = true
									if data.get_cell_type(l) == data.CellType.DOOR:
										if data.get_cell_meta(l).has(dir):
											extends_left = true
									if extends_right and extends_left:
										extends_right = r < l
										extends_left = not extends_right
										var remove_door = max(r, l)
										(data.get_cell_meta(remove_door) as Array).erase(dir)
										if (data.get_cell_meta(remove_door) as Array).empty():
											data.set_cell_meta(remove_door, null)
											data.set_cell_type(remove_door, data.CellType.CORRIDOR)
									if not extends_right and not extends_left:
										data.set_wall(this, dir, data.EdgeType.DOOR)
									else:
										if dir == data.Direction.NORTH or dir == data.Direction.EAST:
											data.set_wall(this, dir, data.EdgeType.HALFDOOR_P if extends_right else data.EdgeType.HALFDOOR_N)
										else:
											data.set_wall(this, dir, data.EdgeType.HALFDOOR_P if extends_left else data.EdgeType.HALFDOOR_N)
								else:
									data.set_wall(this, dir, data.EdgeType.WALL)
							data.CellType.EMPTY:
								data.set_wall(this, dir, data.EdgeType.WALL)
							_:
								pass
