class_name ShakeCamera
extends Camera


enum CameraState {
	STATE_NORMAL,
	STATE_ZOOM
}

export var max_yaw : float = 25.0
export var max_pitch : float = 25.0
export var max_roll : float = 25.0
export var shakeReduction : float = 1.0

export(int, 1, 179) var normal_fov : int = 70
export(int, 1, 179) var zoom_fov : int = 30
export(float, 0.1, 1.0, 0.05) var zoom_camera_sens_mod = 0.25
var mod = 1.0

var stress : float = 0.0
var shake : float = 0.0
var state = CameraState.STATE_NORMAL

var _camera_rotation_reset : Vector3 = Vector3()
#var _crosshair_textures : Dictionary = {}


# TODO: Add in some sort of rotation reset.
func _physics_process(_delta):
	if stress == 0.0:
		_camera_rotation_reset = rotation_degrees
		
	if state == CameraState.STATE_ZOOM:
		mod = zoom_camera_sens_mod
		fov = lerp(fov, zoom_fov, 0.25)
#		zoom_overlay.visible = true
	else:
		mod = 1.0
		fov = lerp(fov, normal_fov, 0.1)
#		zoom_overlay.visible = false
		
	# Should be optional since can bug some people
	rotation_degrees = _process_shake(_camera_rotation_reset, _delta)


func _process_shake(angle_center : Vector3, delta : float) -> Vector3:
	shake = stress * stress
	
	stress -= (shakeReduction / 100.0)
	stress = clamp(stress, 0.0, 1.0)
	
	var new_rotate = Vector3()
	new_rotate.x = max_yaw * mod * shake * _get_noise(randi(), delta)
	new_rotate.y = max_pitch * mod  * shake * _get_noise(randi(), delta + 1.0)
	new_rotate.z = max_roll * mod * shake * _get_noise(randi(), delta + 2.0)
	
	return angle_center + new_rotate


func _get_noise(noise_seed : float, time : float) -> float:
	var n = OpenSimplexNoise.new()
	
	n.seed = noise_seed
	n.octaves = 4
	n.period = 20.0
	n.persistence = 0.8
	
	return n.get_noise_1d(time)


func add_stress(amount : float) -> void:
	stress += amount
	stress = clamp(stress, 0.0, 1.0)
