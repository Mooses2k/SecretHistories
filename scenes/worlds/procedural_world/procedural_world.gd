extends GameWorld


func _ready():
	set_brightness()


func set_brightness():
	# Set game brightness/gamma
	$WorldEnvironment.environment.tonemap_exposure = VideoSettings.brightness


func get_player_spawn_position() -> Vector3:
	if world_data.is_spawn_position_valid():
		# TODO For now using UP_STAIRCASE directly works, because it's always as if we came down 
		# from the level above, but once we can actually navigate between dungeon levels this
		# has to change
		return world_data.player_spawn_positions[RoomData.OriginalPurpose.UP_STAIRCASE]
	else:
		return Vector3(world_data.world_size_x, 0.0, world_data.world_size_z) * world_data.CELL_SIZE * 0.5


# May lag everything for some reason
func toggle_directional_light():
	$DirectionalLight.visible = !$DirectionalLight.visible
