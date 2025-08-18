extends Node
@onready var input: HumanoidCharacterInput = $"../Input"

func _physics_process(delta: float) -> void:
	var input_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forwards", "move_backwards")
	input.movement_vector = Vector3(input_vector.x, 0.0, input_vector.y)
	input.jump = Input.is_action_pressed("jump")
	input.crouch = Input.is_action_pressed("crouch")
	input.sprint = Input.is_action_pressed("sprint")
