extends ControlMode

export(float, 0.0, 1.0) var shift_intensity : float = 0.5
export var _aim : NodePath
onready var aim : Spatial = get_node(_aim) as Spatial;

func set_active(value : bool):
	.set_active(value)
	if value:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if aim:
		aim.visible = value

func update():
	update_aim_position()
	var local_aim = owner.to_local(aim.global_transform.origin)*shift_intensity
	camera.translation.x = local_aim.x/2
	camera.translation.z = local_aim.z/2

func update_aim_position():
	var mouse_pos : Vector2 = get_viewport().get_mouse_position()
	var ro : Vector3 = camera.project_ray_origin(mouse_pos)
	var rd : Vector3 = camera.project_ray_normal(mouse_pos)
	var aim_plane = Plane(Vector3.UP, owner.equipment_root.global_transform.origin.y)
	var intersection_result = aim_plane.intersects_ray(ro, rd)
	if intersection_result:
		aim.visible = true
		aim.global_transform.origin = intersection_result
		var dir : Vector3 = intersection_result - owner.body.global_transform.origin
		dir.y = 0.0
		dir = dir.normalized()
		if not dir.is_equal_approx(Vector3.ZERO):
			var normal_dir = Vector3(-dir.z, 0.0, dir.x)
			owner.body.global_transform.basis = Basis(normal_dir, Vector3.UP, -dir)
			aim.global_transform.basis = Basis(-normal_dir, Vector3.UP, dir)
			owner.equipment_root.look_at(intersection_result, Vector3.UP)
	else:
		self.visible = false

func get_interaction_target() -> Node:
	if owner.pickup_area.get_item_list().size() > 0:
		return owner.pickup_area.get_item_list()[0]
	return null

func _ready():
	aim.visible = false
	aim.set_as_toplevel(true)
	pass
