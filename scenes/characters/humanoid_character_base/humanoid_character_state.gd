extends Node
class_name HumanoidCharacterState
var is_on_ground : bool = false
var was_on_ground : bool = false
# 0.0 means fully standing, 1.0 means fully crouching
var current_crouch_ratio : float = 0.0
var facing : Basis = Basis.IDENTITY
var sprinting : bool = false
var is_reloading : bool = false

# Things like being stunned, or ragdolled
enum CurrentState {
	NORMAL, # Normal state, can move around freely and do whatever
}
@onready var parameters: HumanoidCharacterParameters = $"../Parameters"
@onready var input: HumanoidCharacterInput = $"../Input"


func set_facing_vector(forward : Vector3) -> void:
	facing = Basis.looking_at(forward, Vector3.UP, true)

func should_jump():
	return is_on_ground and input.jump
func get_target_speed() -> float:
	var crouch_multiplier = lerp(1.0, parameters.crouch_speed_multiplier, current_crouch_ratio)
	var sprint_multiplier = parameters.sprint_speed_multiplier if sprinting else 1.0
	return parameters.base_speed*crouch_multiplier*sprint_multiplier
