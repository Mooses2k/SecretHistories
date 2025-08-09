extends Node
class_name HumanoidCharacterState


# Things like being stunned, or ragdolled
enum CurrentState {
	NORMAL, # Normal state, can move around freely and do whatever
}

var stamina_ratio : float:
	get():
		return stamina / parameters.max_stamina

var is_on_ground : bool = false
var was_on_ground : bool = false
# 0.0 means fully standing, 1.0 means fully crouching
var current_crouch_ratio : float = 0.0
var facing : Basis = Basis.IDENTITY
var sprinting : bool = false
var is_reloading : bool = false
var time_since_kick : float = INF
var time_since_dodge : float = INF
var noclip_enabled : bool = false

@onready var parameters: HumanoidCharacterParameters = $"../Parameters" as HumanoidCharacterParameters
@onready var input: HumanoidCharacterInput = $"../Input" as HumanoidCharacterInput
@onready var stamina : float = parameters.max_stamina:
	set(value):
		stamina = clampf(value, 0.0, parameters.max_stamina)


func set_facing_vector(forward : Vector3) -> void:
	facing = Basis.looking_at(forward, Vector3.UP, true)


func should_jump():
	return is_on_ground and input.jump


func get_target_speed() -> float:
	var crouch_multiplier = lerpf(1.0, parameters.crouch_speed_multiplier, current_crouch_ratio)
	var sprint_multiplier = lerpf(
		parameters.sprint_speed_multiplier_min, 
		parameters.sprint_speed_multiplier_max, 
		stamina_ratio
	)
	sprint_multiplier = sprint_multiplier if sprinting else 1.0
	return parameters.base_speed*crouch_multiplier*sprint_multiplier


func _physics_process(delta: float) -> void:
	time_since_kick += delta
	time_since_dodge += delta
