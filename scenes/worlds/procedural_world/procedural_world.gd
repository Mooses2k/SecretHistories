extends GameWorld


func set_player_on_spawn_position(player: Player) -> void:
	var spawn_data := {}
	if world_data.is_spawn_position_valid():
		# TODO For now using UP_STAIRCASE directly works, because it's always as if we came down 
		# from the level above, but once we can actually navigate between dungeon levels this
		# has to change
		spawn_data = world_data.player_spawn_positions[RoomData.OriginalPurpose.UP_STAIRCASE]
	else:
		spawn_data = {
			"position": \
					Vector3(world_data.world_size_x, 0.0, world_data.world_size_z) \
					* world_data.CELL_SIZE * 0.5,
			"y_rotation": 0.0,
		}
	
	player.translation = spawn_data.position
	player.rotation.y = spawn_data.y_rotation


# May lag everything for some reason
func toggle_directional_light():
	$DirectionalLight.visible = !$DirectionalLight.visible
