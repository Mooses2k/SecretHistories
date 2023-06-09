# Helper class for spawning objects
tool
class_name SpawnData
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CENTER_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

#--- public variables - order: export > normal var > onready --------------------------------------

export var scene_path: String = ""
export var amount: int = 1 setget _set_amount

#--- private variables - order: export > normal var > onready -------------------------------------

export var _transforms: Array

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _to_string() -> String:
	var msg := "[SpawnData:%s | amount: %s scene_path: %s]"%[get_instance_id(), amount, scene_path]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func spawn_item_in(node: Node, should_log := false) -> void:
	var item_scene : PackedScene = load(scene_path)
	for index in amount:
		var item = item_scene.instance()
		if item is Spatial:
			item.transform = _transforms[index]
		
		node.add_child(item, true)
		if should_log:
			print("item spawned: %s | at: %s | rotated by: %s"%[
					scene_path, _transforms[index].origin, _transforms[index].basis.get_euler()
			])


func set_center_position_in_cell(cell_position: Vector3, instance_index := INF) -> void:
	if amount > 1 and instance_index == INF:
		push_warning("Setting the smae position for multiple item instances")
	
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform := Transform.IDENTITY.translated(cell_position + CENTER_POSITION_OFFSET)
		_transforms[i] = transform


# This calculates the center position of the cell and then tries to find a random position 
# around it, inside a range from min_radius to max_radius away from center
func set_random_position_in_cell(
		rng: RandomNumberGenerator,
		cell_position: Vector3, 
		min_radius: float, 
		max_radius: float, 
		p_angle := INF,
		instance_index := INF
) -> void:
	if p_angle != INF and instance_index == INF:
		push_warning("Setting the same position for multiple item instances")
	
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform := _transforms[i] as Transform
		var angle := p_angle
		var center_position := cell_position + CENTER_POSITION_OFFSET
		
		if angle == INF:
			angle = rng.randf_range(0.0, TAU)
			print("angle #%s: %s"%[i, angle])
		
		var radius := rng.randf_range(min_radius, max_radius)
		var random_direction := Vector3(cos(angle), 0.0, sin(angle)).normalized()
		var polar_coordinate := random_direction * radius
		var random_position := center_position + polar_coordinate
		transform = transform.translated(random_position)
		transform.basis = transform.basis.rotated(Vector3.UP, angle)
		_transforms[i] = transform


func set_random_rotation_in_all_axis(rng: RandomNumberGenerator, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform
		var random_rotation = Quat(Vector3(
			rng.randf_range(0, TAU),
			rng.randf_range(0, TAU),
			rng.randf_range(0, TAU)
		))
		transform.basis = Basis(random_rotation)
		_transforms[i] = transform


func set_y_rotation(angle_rad: float, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform
		transform.basis = transform.basis.rotated(Vector3.UP, angle_rad)
		_transforms[i] = transform

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _set_amount(value: int) -> void:
	amount = max(1, value)
	var old_tranforms = _transforms.duplicate()
	_transforms.resize(amount)
	_transforms.fill(Transform.IDENTITY)
	
	for index in _transforms.size():
		if index < old_tranforms.size() and _transforms[index] != old_tranforms[index]:
			_transforms[index] = old_tranforms[index]

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
