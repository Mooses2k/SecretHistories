extends Camera3D
class_name CameraStressShake


## Minimal stress-driven camera shake (3.x ShakeCamera parity, issue #747).
## The 3.x camera (scenes/characters/player_old/player_camera.gd) rotated on
## all three axes from one decaying stress value fed by add_stress(0.25) on
## every kick. The active controller owns the pitch here (player_controller
## writes rotation.x every frame), so this shake drives only the free roll
## axis with the same stress math: shake = stress^2, roll noise scaled by
## max_roll, stress decaying shake_reduction / 100 per frame.

@export var max_roll : float = 25.0
@export var shake_reduction : float = 1.0

var stress : float = 0.0

var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.fractal_octaves = 4
	_noise.frequency = 1.0 / 20.0
	_noise.fractal_gain = 0.8


func _process(delta: float) -> void:
	if stress == 0.0:
		rotation.z = 0.0
		return
	var shake := stress * stress
	rotation.z = deg_to_rad(max_roll * shake * _get_noise(delta))
	stress -= shake_reduction / 100.0
	stress = maxf(stress, 0.0)


func _get_noise(time : float) -> float:
	_noise.seed = randi()
	return _noise.get_noise_1d(time)


func add_stress(amount : float) -> void:
	stress = clampf(stress + amount, 0.0, 1.0)
