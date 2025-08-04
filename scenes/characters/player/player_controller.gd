extends Node

const CAMERA_STANDING_HEIGHT = 1.6
const CAMERA_CROUCHING_HEIGHT = 1.1

@onready var state: HumanoidCharacterState = $"../State"
@onready var input: HumanoidCharacterInput = $"../Input"
@onready var main_camera: Camera3D = $"../ModelRoot/MainCamera"

var camera_pitch : float = 0.0

@onready var interaction_cast: RayCast3D = $"../ModelRoot/MainCamera/InteractionCast"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and input.mouse_captured:
		var sens = InputSettings.setting_mouse_sensitivity*0.01
		camera_pitch -= sens*event.relative.y
		camera_pitch = clamp(camera_pitch, - PI*0.5, PI*0.5)
		state.facing = state.facing.rotated(Vector3.UP, -sens*event.relative.x)
	
	if Input.is_action_just_pressed("debug_switch_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			input.set_input_capture_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			input.set_input_capture_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta : float) -> void:
	main_camera.rotation.x = camera_pitch
	main_camera.position.y = lerp(CAMERA_STANDING_HEIGHT, CAMERA_CROUCHING_HEIGHT, state.current_crouch_ratio)

func _physics_process(delta: float) -> void:
	var input_vector_2d := Input.get_vector(&"movement|move_right", &"movement|move_left", &"movement|move_down", &"movement|move_up")
	var input_vector = Vector3(input_vector_2d.x, 0.0, input_vector_2d.y)
	input.movement_vector = state.facing * input_vector
	input.jump = Input.is_action_just_pressed(&"player|jump")
	input.crouch = Input.is_action_pressed(&"player|crouch")
	input.sprint = Input.is_action_pressed(&"player|sprint")
