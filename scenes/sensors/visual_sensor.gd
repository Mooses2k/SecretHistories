@tool
class_name VisualSensor extends CharacterSense

# Whatever you do, for the love of Cthulhu, please don't set Mask 1 for the DirectSightArea
# You will lag so hard
# Don't remove this comment :)


signal player_detected(player, position)
signal light_detected(light, position)

@export var light_source_interest := 75
@export var player_interest := 300

@export var light_sensitivity_level := 0.003

@export var _ik_target: NodePath
var ik_target: Node3D

#--------------------------------------------------------------------------#
#                 Programmatically sets the vision frustrum.               #
#--------------------------------------------------------------------------#
@export var distance := 32.0: set = set_distance
@export var fov := 120.0: set = set_fov

var line_of_sight : bool = false

var _mesh : CylinderMesh = CylinderMesh.new()

@onready var _collision_shape := CollisionShape3D.new()
@onready var _mesh_instance := MeshInstance3D.new()


func add_area_nodes() -> void:
	add_child(_collision_shape)
	add_child(_mesh_instance)
	_mesh_instance.mesh = _mesh
	_mesh_instance.visible = false
	_mesh_instance.rotation_degrees.x = 90
	_collision_shape.rotation_degrees.x = 90
	_collision_shape.global_transform.origin.z = -16
	update_mesh_and_collision()


func set_distance(value : float) -> void:
	distance = value
	call_deferred("update_mesh_and_collision")


func set_fov(value : float) -> void:
	fov = value
	call_deferred("update_mesh_and_collision")


func update_mesh_and_collision() -> void:
	if !is_inside_tree():
		return
	
	_mesh.rings = 0
	_mesh.radial_segments = 4
	_mesh.height = distance
	_mesh.top_radius = 0.0
	_mesh.bottom_radius = distance * tan(deg_to_rad(fov / 2)) / (sqrt(2) * 0.5)
	_mesh_instance.transform.origin.z = -distance * 0.5
	call_deferred("update_collision")


func update_collision() -> void:
	_collision_shape.shape = _mesh.create_convex_shape()
	_collision_shape.transform.origin.z = -distance * 0.5


func get_aabb() -> AABB:
	if is_instance_valid(_mesh_instance):
		return _mesh_instance.get_aabb()
	return AABB()

#---------------------------------------------------------------------------#


func _ready() -> void:
	ik_target = get_node(_ik_target)
	
	add_area_nodes()
	connect_signals()
	set_collision_layers()
	call_deferred("update_mesh_and_collision")


func set_collision_layers() -> void:
	collision_mask = 1 << 1 | 1 << 4 | 1 << 10


func connect_signals() -> void:
	connect("area_entered", Callable(self, "on_area_entered"))
	connect("area_exited", Callable(self, "on_area_exited"))


func on_area_entered(area: Area3D) -> void:
	if area is LightArea: light_area_entered(area)


func on_area_exited(area: Area3D) -> void:
	if area is LightArea: light_area_exited(area)


func tick(character: Character, _delta: float) -> int:
	line_of_sight = false
	if is_instance_valid(ik_target): look_at(ik_target.global_transform.origin, Vector3.UP)
	if process_player_detection(character): return OK
	if process_light_detection(character): return OK
	return FAILED

#--------------------------------------------------------------------------#
#                         Player detection related.                        #
#--------------------------------------------------------------------------#
func get_player() -> Player:
	for body in get_overlapping_bodies():
		if body is Player: return body
	return null


func process_player_detection(character: Character) -> bool:
	var player := can_see_player(character)
	if is_instance_valid(player):
		emit_signal\
		(
			"player_detected",
			player,
			player.global_transform.origin
		)
		emit_signal\
		(
			"event",
			player_interest,
			player.global_transform.origin,
			player,
			self
		)
		return true
	return false


func can_see_player(character: Character) -> Player:
	var player := get_player()
	
	if is_instance_valid(player) and player.light_level > light_sensitivity_level:
		var target := player.global_transform.origin
#		target.y = global_transform.origin.y
		target.y += 0.5
		
		var world := get_world_3d()
		
		if is_instance_valid(world):
			var raycast_parameters := PhysicsRayQueryParameters3D.new()
			raycast_parameters.from = global_transform.origin
			raycast_parameters.to = target
			raycast_parameters.exclude = [character]
			raycast_parameters.collision_mask = 0b11
			raycast_parameters.collide_with_bodies = true
			raycast_parameters.collide_with_areas = false
			var result := world.direct_space_state.intersect_ray(raycast_parameters)
			if !result.is_empty() and result.collider is Player:
				line_of_sight = true
				return player
	
	return null

#--------------------------------------------------------------------------#


#--------------------------------------------------------------------------#
#                         Light detection related.                         #
#--------------------------------------------------------------------------#
@export var light_points_grid_size := 1.0


var light_sources: Array
var light_idx := 0
var voxel_idx := 0


func get_overlapping_lights() -> Array:
	var result := []
	for area in get_overlapping_areas():
		if area is PlayerLightArea:
			result.append(area)
	return result


func process_light_detection(_character: Character) -> bool:
	# [ Evil hack in case of `on_light_entered` misbehaving ]
	light_sources = get_overlapping_lights()
	
	if !light_sources.is_empty():
		var light_area := check_light()
		if is_instance_valid(light_area):
			emit_signal\
			(
				"light_detected",
				light_area,
				light_area.global_transform.origin
			)
			emit_signal\
			(
				"event",
				light_source_interest,
				light_area.global_transform.origin,
				light_area,
				self
			)
			print(light_area, " light area detected")
			return true
	return false


func light_area_entered(light_area: LightArea) -> void:
	if light_area is PlayerLightArea:
		if !light_sources.has(light_area):
			light_sources.append(light_area)


func light_area_exited(light_area: LightArea) -> void:
	if light_area is PlayerLightArea:
		if light_sources.has(light_area):
			light_sources.erase(light_area)


func check_light() -> PlayerLightArea:
	var player_light_area := get_player_light_area()
	
	if !is_instance_valid(player_light_area) or !(player_light_area is PlayerLightArea):
		return null
	
	if !(player_light_area.parent_item is CandelabraItem or
		player_light_area.parent_item is CandleItem or
		player_light_area.parent_item is LanternItem
		or player_light_area.parent_item.owner_character is Player):
		return null
	
	if !player_light_area.parent_item.is_lit: return null
	
	# Get valid position on a grid inside the intersection area between the enemy's fov area and player's light area.
	var point := get_position_in_grid(get_aabb().intersection(player_light_area.get_aabb()))
	if player_light_area.check_point(point) and check_point(point): return player_light_area.parent_item.owner_character
	# Return `player_light_area` if both player's light area and enemy's fov area can reach that point.
	return null


# Returns `true` if the raycast towards the point doesn't collide.
func check_point(point: Vector3) -> bool: 
	var world := get_world_3d()
	if !is_instance_valid(world): return false
	var raycast_parameters := PhysicsRayQueryParameters3D.new()
	raycast_parameters.from = global_transform.origin
	raycast_parameters.to = point
	raycast_parameters.exclude = []
	raycast_parameters.collision_mask = 0b1
	raycast_parameters.collide_with_bodies = true
	raycast_parameters.collide_with_areas = false
	return world.direct_space_state.intersect_ray(raycast_parameters).is_empty()


# Return's a `PlayerLightArea` from `light_sources`, automatically shuffling if multiple sources are available.
func get_player_light_area() -> PlayerLightArea:
	while !light_sources.is_empty():
		light_idx = wrapi(light_idx + 1, 0, light_sources.size() - 1)
		
		if !is_instance_valid(light_sources[light_idx]):
			light_sources.remove_at(light_idx) ; continue   # manually changed from remove() during migration
		
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
			floor(aabb.size.x / light_points_grid_size),
			floor(aabb.size.y / light_points_grid_size),
			floor(aabb.size.z / light_points_grid_size)
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
		) * light_points_grid_size
	return world_pos

#---------------------------------------------------------------------------#
