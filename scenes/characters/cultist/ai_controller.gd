extends Node

var ai_state : CharacterState

@onready var character_state: HumanoidCharacterState = $"../State"
@onready var character_input: HumanoidCharacterInput = $"../Input"

@onready var bt_root: BTRoot = $BTRoot
@onready var look_target: Marker3D = $"../ModelRoot/LookTarget"


func _ready() -> void:
	ai_state = CharacterState.new(owner)
	bt_root.tick_delta = 0.1

func _physics_process(delta: float) -> void:
	character_input.movement_vector = ai_state.move_direction
	character_state.set_facing_vector(ai_state.face_direction)
	if ai_state.target != null:
		look_target.global_position = ai_state.target.position + Vector3.UP*1.5


func _on_tick_timer_timeout() -> void:
	bt_root.run_tick(ai_state)
	pass # Replace with function body.
