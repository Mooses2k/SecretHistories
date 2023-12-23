extends RigidBody
class_name Door_body


var min_angle = 0.0
var max_angle = 90.0
export var restitution = 0.5
export var _hinge_node : NodePath
var hinge_node : Spatial
var base_angle : float = 0.0

var sound_vol = 20
onready var debug_draw = $DebugDraw

var last_torque_constraint : Vector3 = Vector3.ZERO
var last_impulse_constraint : Vector3 = Vector3.ZERO

func _ready():
	hinge_node = get_node(_hinge_node)
	var door_to_hinge : Transform = hinge_node.global_transform*global_transform.inverse()
	var base_vector : Vector3 = door_to_hinge*Vector3.ZERO
	base_vector.y = 0.0
	base_angle = -base_vector.angle_to(Vector3.RIGHT)*sign(base_vector.cross(Vector3.RIGHT).y)

func __integrate_forces(state):
#	state.angular_velocity = Vector3.ZERO
#	return

	var angle = wrapf(rotation.y, -PI, PI)
	var hinge_to_door = global_transform.inverse()*hinge_node.global_transform
	
	var target_angle = clamp(angle, deg2rad(min_angle), deg2rad(max_angle))
	var angle_diff = wrapf(target_angle - angle, -PI, PI)
	
	if (state.angular_velocity.abs().length() > 0.03):
		sound_vol = state.angular_velocity.abs().length() 
		if sound_vol < 1.5:
			sound_vol = -(2 / sound_vol)
			
		$AudioStreamPlayer3D.unit_db = clamp(sound_vol, 00.0, 40.0)
		
		if not $AudioStreamPlayer3D.playing:
			$AudioStreamPlayer3D.play()
	else:
		$AudioStreamPlayer3D.stop()
	
	var torque_constraint = Vector3.UP*angle_diff/(state.inverse_inertia*state.step)
	state.apply_torque_impulse(torque_constraint)
	last_torque_constraint = torque_constraint
