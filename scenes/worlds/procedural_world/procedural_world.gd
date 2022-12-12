extends GameWorld


func get_player_spawn_position() -> Vector3:
	for i in world_data.world_size_x:
		for j in world_data.world_size_z:
			var cell = world_data.get_cell_index_from_int_position(i, j)
			if world_data.is_cell_free[cell] == 1:
				return self.grid_to_world(Vector3(i, 0, j))
	return Vector3(world_data.world_size_x, 0.0, world_data.world_size_z)*world_data.CELL_SIZE*0.5

