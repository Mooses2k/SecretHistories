# Helper class for spawning objects
class_name SpawnData
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CENTER_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

#--- public variables - order: export > normal var > onready --------------------------------------

export var scene_path: String = ""
export var amount: int = 1
export var transform := Transform.IDENTITY

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _to_string() -> String:
	var msg := "[SpawnData:%s | amount: %s scene_path: %s]"%[get_instance_id(), amount, scene_path]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func spawn_item_in(node: Node, should_log := false) -> void:
	var item
	var item_scene : PackedScene = load(scene_path)
	item = item_scene.instance()
	if item is Spatial:
		item.transform = transform
	
	node.add_child(item, true)
	if should_log:
		print("item spawned: %s | at: %s | rotated by: %s"%[
				scene_path, transform.origin, transform.basis.get_euler()
		])


func set_center_position_in_cell(cell_position: Vector3) -> void:
	transform = transform.translated(cell_position + CENTER_POSITION_OFFSET)


# This calculates the center position of the cell and then tries to find a random position 
# around it, inside a range from min_radius to max_radius away from center
func set_random_position_in_cell(
		rng: RandomNumberGenerator,
		cell_position: Vector3, 
		min_radius: float, 
		max_radius: float, 
		angle := INF
) -> void:
	var center_position := cell_position + CENTER_POSITION_OFFSET
	if angle == INF:
		angle = rng.randf_range(0.0, TAU)
	
	var radius := rng.randf_range(min_radius, max_radius)
	var random_direction := Vector3(cos(angle), 0.0, sin(angle)).normalized()
	var polar_coordinate := random_direction * radius
	
	var random_position := center_position + polar_coordinate
	transform = transform.translated(random_position)


func set_random_rotation_in_all_axis(rng: RandomNumberGenerator) -> void:
	var random_rotation = Quat(Vector3(
		rng.randf_range(0, TAU),
		rng.randf_range(0, TAU),
		rng.randf_range(0, TAU)
	))
	transform.basis = Basis(random_rotation)


func set_y_rotation(angle_rad: float) -> void:
	transform.basis = transform.basis.rotated(Vector3.UP, angle_rad)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
