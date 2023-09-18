extends ControlMode


#const RAD_DEG = rad2deg(1.0)

export var _aimcast : NodePath
onready var aimcast : RayCast = get_node(_aimcast) as RayCast

export var _grabcast : NodePath
onready var grabcast : RayCast = get_node(_grabcast) as RayCast

var _camera_orig_pos : Vector3
var _camera_orig_rotation : Vector3

var pitch_yaw : Vector2 = Vector2.ZERO

const MAX_RECOIL = 35 * 60
const DAMPENING_FACTOR = 6 * 60
const DAMPENING_POWER = 0.0

var up_recoil = 0.0
var side_recoil = 0.0

var _bob_time : float = 0.0
var _bob_reset : float = 0.0

var crouch_cam_target_pos = 0.98

export var _gun_camera : NodePath
onready var gun_camera : Camera = get_node(_gun_camera) as Camera


func _ready():
	_camera_orig_pos = _camera.transform.origin
	_camera_orig_rotation = _camera.rotation_degrees
	
	_bob_reset = _camera.global_transform.origin.y - owner.global_transform.origin.y


func _physics_process(delta):
	_try_to_stand()


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


func _input(event):
	if event is InputEventMouseMotion:
		if (owner.state == owner.State.STATE_CLAMBERING_LEDGE
			or owner.state == owner.State.STATE_CLAMBERING_RISE
			or owner.state == owner.State.STATE_CLAMBERING_VENT):
			return
		
		var m = 1.0
		
		if _camera.state == _camera.CameraState.STATE_ZOOM:
			m = _camera.zoom_camera_sens_mod
		
		owner.rotation_degrees.y -= (event.relative.x * InputSettings.setting_mouse_sensitivity * m ) * get_parent().camera_movement_resistance
		
	#		if owner.state != owner.State.STATE_CRAWLING:
	#			_camera.rotation_degrees.x -= event.relative.y * InputSettings.setting_mouse_sensitivity * m
	#			_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -90, 90)
	_camera._camera_rotation_reset = _camera.rotation_degrees


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Vertical
		pitch_yaw.x -= (event.relative.y * InputSettings.setting_mouse_sensitivity * 0.01) * get_parent().camera_movement_resistance   # if this is anything 0.01, even if same as below, vertical speed is diff than horizontal - why?
		# Horizontal
		pitch_yaw.y -= (event.relative.x * InputSettings.setting_mouse_sensitivity * 0.01) * get_parent().camera_movement_resistance
		pitch_yaw.x = clamp(pitch_yaw.x, -PI * 0.5, PI * 0.5)
		pitch_yaw.y = wrapf(pitch_yaw.y, -PI, PI)


# Called from gun_item to add recoil
func recoil(item, damage, handling):
	side_recoil = rand_range(-5, 5)
#    var recoil = rand_range(250 - item.handling, 500 - item.handling)
#    up_recoil += recoil * delta
#    up_recoil += 1 
	#compensate for delta application
	up_recoil += 60 * damage / (handling)


func update(delta):
	_camera.rotation_degrees = _camera_orig_rotation
	
	if up_recoil > 0:
		### Recoil
		# Horiztontal recoil
		pitch_yaw.y = lerp(pitch_yaw.y, deg2rad(side_recoil), delta)
		# Vertical recoil
	
#        if up_recoil >= 35:
#            up_recoil = 35
		up_recoil = min(up_recoil, MAX_RECOIL)
		if _camera:   # For now, no vertical recoil for cultists
			pitch_yaw.x += deg2rad(up_recoil) * delta
			pitch_yaw.x = min(pitch_yaw.x, PI * 0.5)
#            pitch_yaw.x = lerp(pitch_yaw.x, deg2rad(pitch_yaw.x + up_recoil), delta)
		up_recoil -= DAMPENING_FACTOR * pow(up_recoil, DAMPENING_POWER)*delta

	# Finally, apply rotations
	owner.character_body.rotation.y = pitch_yaw.y   # Horizontal
	_camera.rotation.x = pitch_yaw.x   # Vertical, you don't want to rotate the whole scene, just camera

	# Guncam too - MUST BE DONE HERE OR WEIRD JITTERY HANDS BUG DEVELOPS
	gun_camera.global_transform = _camera.global_transform


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
	return -_camera.global_transform.basis.z


func get_grab_target() -> RigidBody:
	return grabcast.get_collider() as RigidBody


func get_grab_global_position() -> Vector3:
	return grabcast.get_collision_point()


func get_grab_target_position(distance : float) -> Vector3:
	return _camera.global_transform.origin - _camera.global_transform.basis.z * distance


func head_bob(delta : float) -> void:
	if owner.velocity.length() == 0.0:
		var br = Vector3(0, _bob_reset, 0)
		_camera.global_transform.origin = owner.global_transform.origin + br
	
	_bob_time += delta
	var y_bob = sin(_bob_time * (2 * PI)) * owner.velocity.length() * (0.5 / 1000.0)
	_camera.global_transform.origin.y += y_bob
	
	# Removed since it's not good to do head rotation unless take camera control away from player 
	# because of risk of simulation sickness
#	var z_bob = sin(_bob_time * (PI)) * owner.velocity.length() * 0.2
#	_camera.rotation_degrees.z = z_bob


func crouch_cam():
	var from = _camera.transform.origin.y
	_camera.transform.origin.y = lerp(from, crouch_cam_target_pos, 0.08)


func _try_to_stand():
	if owner.wanna_stand:
		var from = _camera.transform.origin.y
		_camera.transform.origin.y = lerp(from, _camera_orig_pos.y, 0.08)
		var d1 = _camera.transform.origin.y - _camera_orig_pos.y
		if d1 > -0.02:
			_camera.transform.origin.y = _camera_orig_pos.y
			owner.is_crouching = false
			owner.wanna_stand = false
