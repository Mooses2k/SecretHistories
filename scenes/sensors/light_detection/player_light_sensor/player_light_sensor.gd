class_name PlayerLightSensor extends LightArea


#|============================================================================|#
#| For optimization purposes if needed, make an EnemyFOVServer singleton      |#
#| So the number of enemy fovs processed per frame can be capped.             |#
#|============================================================================|#


signal sensory_input(position, id, interest)
signal detected_light_source(light_source)


export var grid_size := 1.0


var light_sources: Array
var light_idx := 0
var voxel_idx := 0


func _ready() -> void:
	._ready() # Call inherited `_ready()`.


func _process(_delta: float) -> void:
	light_sources = get_overlapping_areas()
	
	if !light_sources.empty():
		var light_source := check_light_with_player_light_area()
		
		if is_instance_valid(light_source):
			emit_signal("detected_light_source", light_source)
			emit_signal\
			(
				"detected_light_source",
				light_source.global_transform.origin,
				light_source,
				75
			)


func check_light() -> bool:
	var player_light_area := get_player_light_area()
	if !is_instance_valid(player_light_area): return false
	
	# Get valid position on a grid inside the intersection area between the enemy's fov area and player's light area.
	var point := get_position_in_grid(get_aabb().intersection(player_light_area.get_aabb()))
	return player_light_area.check_point(point) and check_point(point)
	# Return `true` if both player's light area and enemy's fov area can reach that point.


func check_light_with_player_light_area() -> PlayerLightArea:
	var player_light_area := get_player_light_area()
	if !is_instance_valid(player_light_area): return null
	
	# Get valid position on a grid inside the intersection area between the enemy's fov area and player's light area.
	var point := get_position_in_grid(get_aabb().intersection(player_light_area.get_aabb()))
	if player_light_area.check_point(point) and check_point(point): return player_light_area
	# Return `player_light_area` if both player's light area and enemy's fov area can reach that point.
	return null


# Return's a `PlayerLightArea` from `light_sources`, automatically shuffling if multiple sources are available.
func get_player_light_area() -> PlayerLightArea:
	while !light_sources.empty():
		light_idx = wrapi(light_idx + 1, 0, light_sources.size() - 1)
		
		if !is_instance_valid(light_sources[light_idx]):
			light_sources.remove(light_idx) ; continue
		
		return light_sources[light_idx]
	return null


func get_player_light_aabb() -> AABB:
	var player_light_area := get_player_light_area()
	if is_instance_valid(player_light_area):
		return player_light_area.get_aabb()
	return AABB()


# Function to get a position within an AABB, based on an index.
# Calculates only the precise position it needs to be based on an index instead of generating an Array of possible positions.
func get_position_in_grid(aabb: AABB) -> Vector3:
	# Calculate grid dimensions - How many points in each direction.
	var grid_dims :=\
		Vector3\
		(
			floor(aabb.size.x / grid_size),
			floor(aabb.size.y / grid_size),
			floor(aabb.size.z / grid_size)
		)
	
	if grid_dims.x == 0 or grid_dims.y == 0:
		push_warning("Warning: grid_dims contains a zero value!")
		return Vector3(0, 0, 0)
	
	var total_points := int(grid_dims.x * grid_dims.y * grid_dims.z)
	voxel_idx = wrapi(voxel_idx + 1, 0, total_points)
	
	var grid_area = grid_dims.x * grid_dims.y
	var world_pos :=\
		aabb.position +\
		Vector3\
		(
			fmod(fmod(voxel_idx, grid_area), grid_dims.x),
			floor(fmod(voxel_idx, grid_area) / grid_dims.x),
			floor(voxel_idx / grid_area)
		) * grid_size
	return world_pos
