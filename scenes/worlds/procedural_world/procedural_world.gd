extends GameWorld


func get_player_spawn_position() -> Vector3:
	if world_data.is_spawn_position_valid():
		var grid_position = Vector3(
				world_data.player_spawn_position.x, 
				0, 
				world_data.player_spawn_position.y
		)
		return grid_to_world(grid_position)
	else:
		return Vector3(world_data.world_size_x, 0.0, world_data.world_size_z) * world_data.CELL_SIZE * 0.5

func toggle_directional_light():
	$DirectionalLight.visible = !$DirectionalLight.visible
