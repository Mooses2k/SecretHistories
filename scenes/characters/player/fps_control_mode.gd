extends ControlMode


#const RAD_DEG = rad2deg(1.0)

export var _aimcast : NodePath
onready var aimcast : RayCast = get_node(_aimcast) as RayCast

export var _grabcast : NodePath
onready var grabcast : RayCast = get_node(_grabcast) as RayCast

var pitch_yaw : Vector2 = Vector2.ZERO

var up_recoil = 0.0
var side_recoil = 0.0


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
		# Vertical
		pitch_yaw.x -= event.relative.y * GlobalSettings.mouse_sensitivity * 0.01   # if this is anything 0.01, even if same as below, vertical speed is diff than horizontal - why?
		# Horizontal
		pitch_yaw.y -= event.relative.x * GlobalSettings.mouse_sensitivity * 0.01
		pitch_yaw.x = clamp(pitch_yaw.x, -PI * 0.5, PI * 0.5)
		pitch_yaw.y = wrapf(pitch_yaw.y, -PI, PI)


func recoil(item, damage, handling):
	side_recoil = rand_range(-5, 5)
#    var recoil = rand_range(250 - item.handling, 500 - item.handling)
#    up_recoil += recoil * delta
#    up_recoil += 1 
	#compensate for delta application
	up_recoil += 60 * damage / (handling)

const MAX_RECOIL = 35 * 60
const DAMPENING_FACTOR = 6 * 60
const DAMPENING_POWER = 0.0

func update(delta):
	if up_recoil > 0:
		### Recoil
		# Horiztontal recoil
		pitch_yaw.y = lerp(pitch_yaw.y, deg2rad(side_recoil), delta)
		# Vertical recoil
	
#        if up_recoil >= 35:
#            up_recoil = 35
		up_recoil = min(up_recoil, MAX_RECOIL)
		if camera:   # For now, no vertical recoil for cultists
			pitch_yaw.x += deg2rad(up_recoil) * delta
			pitch_yaw.x = min(pitch_yaw.x, PI * 0.5)
#            pitch_yaw.x = lerp(pitch_yaw.x, deg2rad(pitch_yaw.x + up_recoil), delta)
		up_recoil -= DAMPENING_FACTOR * pow(up_recoil, DAMPENING_POWER)*delta

	owner.body.rotation.y = pitch_yaw.y   # Horizontal
	camera.rotation.x = pitch_yaw.x   # Vertical, you don't want to rotate the whole scene, just camera


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
