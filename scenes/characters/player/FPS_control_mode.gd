extends ControlMode


const rad_deg = rad2deg(1.0);

export var _aimcast : NodePath
onready var aimcast : RayCast = get_node(_aimcast) as RayCast

export var _grabcast : NodePath
onready var grabcast : RayCast = get_node(_grabcast) as RayCast

var pitch_yaw : Vector2 = Vector2.ZERO


func set_active(value : bool):
	.set_active(value)
	if value:
		pitch_yaw.x = 0.0
		pitch_yaw.y = 0.0 # owner.body.rotation.y
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _notification(what):
	if is_active:
		if what == NOTIFICATION_PAUSED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif what == NOTIFICATION_UNPAUSED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		pitch_yaw.x -= event.relative.y * GlobalSettings.mouse_sensitivity * 0.01
		pitch_yaw.y -= event.relative.x * GlobalSettings.mouse_sensitivity * 0.01
		pitch_yaw.x = clamp(pitch_yaw.x, -PI * 0.5, PI * 0.5)
		pitch_yaw.y = wrapf(pitch_yaw.y, -PI, PI)


func update():
	owner.body.rotation.y = pitch_yaw.y # horizontal
	camera.rotation.x = pitch_yaw.x # vertical, you don't want to rotate the whole scene, just camera
	if aimcast.is_colliding():
		owner.mainhand_equipment_root.look_at(aimcast.get_collision_point(), Vector3.UP)
		owner.offhand_equipment_root.look_at(aimcast.get_collision_point(), Vector3.UP)
	else:
		owner.mainhand_equipment_root.global_transform.basis = camera.global_transform.basis
		owner.offhand_equipment_root.global_transform.basis = camera.global_transform.basis
	pass


func get_movement_basis() -> Basis:
	return Basis.IDENTITY.rotated(Vector3.UP, pitch_yaw.y)


func get_interaction_target() -> Node:
	return aimcast.get_collider() as Node


func get_target_placement_position() -> Vector3:
	if aimcast.is_colliding():
		return aimcast.get_collision_point()
	else:
		return aimcast.to_global(aimcast.cast_to)


func get_aim_direction() -> Vector3:
	return -camera.global_transform.basis.z


func get_grab_target() -> RigidBody:
	return grabcast.get_collider() as RigidBody


func get_grab_global_position() -> Vector3:
	return grabcast.get_collision_point()


func get_grab_target_position(distance : float) -> Vector3:
	return camera.global_transform.origin - camera.global_transform.basis.z*distance
