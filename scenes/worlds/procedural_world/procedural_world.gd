extends GameWorld


func set_player_on_spawn_position(player: Player, is_going_downstairs: bool) -> void:
	var spawn_data := {}
	if world_data.is_spawn_position_valid():
		if is_going_downstairs:
			spawn_data = world_data.player_spawn_positions[RoomData.OriginalPurpose.UP_STAIRCASE]
		else:
			spawn_data = world_data.player_spawn_positions[RoomData.OriginalPurpose.DOWN_STAIRCASE]
	else:
		spawn_data = {
			"position": \
					Vector3(world_data.world_size_x, 0.0, world_data.world_size_z) \
					* world_data.CELL_SIZE * 0.5,
			"y_rotation": 0.0,
		}
	
	player.position = spawn_data.position
	player.rotation.y = spawn_data.y_rotation
	player.velocity = Vector3.ZERO


# May lag everything for some reason
func toggle_directional_light():
	$DirectionalLight3D.visible = !$DirectionalLight3D.visible
