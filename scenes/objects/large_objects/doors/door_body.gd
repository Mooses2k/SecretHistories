extends RigidBody
class_name Door_body


var min_angle = 0.0
var max_angle = 90.0
export var restitution = 0.5
export var _hinge_node : NodePath
onready var hinge_node : Spatial

var sound_vol = 20


func _integrate_forces(state):
#	state.angular_velocity = Vector3.ZERO
#	return
	if not hinge_node or not is_instance_valid(hinge_node):
		hinge_node = get_node(_hinge_node)
		if not hinge_node or not is_instance_valid(hinge_node):
			return
	var angle = wrapf(rotation.y, -PI, PI)
	var target_angle = clamp(angle, deg2rad(min_angle), deg2rad(max_angle))
	var angle_diff = wrapf(target_angle - angle, -PI, PI)
	
	if (state.angular_velocity.abs().length() > 0.03):
		sound_vol = state.angular_velocity.abs().length() 
		if sound_vol < 1.5:
			sound_vol = -(2 / sound_vol)
			
		$AudioStreamPlayer3D.unit_db = clamp(sound_vol, -5.0, 2.0)
		
		if not $AudioStreamPlayer3D.playing:
			$AudioStreamPlayer3D.play()
	else:
		$AudioStreamPlayer3D.stop()
	
	if not is_zero_approx(angle_diff):
		var hinge_arm : Vector3 = state.transform.origin - hinge_node.global_transform.origin
		hinge_arm.y = 0.0
		var ang_vel : Vector3 = state.angular_velocity
		if sign(ang_vel.y) != sign(angle_diff):
			ang_vel.y *= -restitution
		state.angular_velocity = ang_vel
		state.linear_velocity = ang_vel.cross(hinge_arm)
		state.transform.basis = get_parent().global_transform.basis.rotated(Vector3.UP, target_angle)
