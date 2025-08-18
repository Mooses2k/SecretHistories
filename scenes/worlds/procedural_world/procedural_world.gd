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
	await get_tree().physics_frame
	player.position = spawn_data.position
	# Set the player's facing direction properly for the new character design
	var facing_basis := Basis(Vector3.UP, spawn_data.y_rotation)
	player.state.facing = facing_basis
	player.model_root.global_basis = facing_basis
	player.linear_velocity = Vector3.ZERO


# May lag everything for some reason
func toggle_directional_light():
	$DirectionalLight3D.visible = !$DirectionalLight3D.visible
