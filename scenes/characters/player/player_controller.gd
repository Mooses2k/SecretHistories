extends Node
class_name PlayerController

const CAMERA_STANDING_HEIGHT = 1.6
const CAMERA_CROUCHING_HEIGHT = 1.1

@onready var state: HumanoidCharacterState = $"../State"
@onready var input: HumanoidCharacterInput = $"../Input"
@onready var main_camera: Camera3D = $"../ModelRoot/MainCamera"

var camera_pitch : float = 0.0

var moved_since_sprint : bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var sens = InputSettings.setting_mouse_sensitivity*0.01
		camera_pitch -= sens*event.relative.y
		camera_pitch = clamp(camera_pitch, - PI*0.5, PI*0.5)
		state.facing = state.facing.rotated(Vector3.UP, -sens*event.relative.x)

func _process(_delta : float) -> void:
	main_camera.rotation.x = camera_pitch
	main_camera.position.y = lerp(CAMERA_STANDING_HEIGHT, CAMERA_CROUCHING_HEIGHT, state.current_crouch_ratio)

func _physics_process(delta: float) -> void:
	var input_vector_2d := Input.get_vector(&"movement|move_left", &"movement|move_right", &"movement|move_up", &"movement|move_down")
	var input_vector = Vector3(input_vector_2d.x, 0.0, input_vector_2d.y)
	input.movement_vector = state.facing * input_vector
	input.jump = Input.is_action_just_pressed(&"player|jump")
	input.sprint = Input.is_action_pressed(&"player|sprint")
	var is_sprinting := input.sprint and not input.movement_vector.is_zero_approx()
	input.crouch = Input.is_action_pressed(&"player|crouch") and not is_sprinting # can't crouch if sprinting
	
	# If pressed kick without moving, kick
	if Input.is_action_just_released(&"player|sprint") and not moved_since_sprint:
		kick()
	# moved is true if sprinting and either already moved or is moving, false otherwise
	moved_since_sprint = input.sprint and (moved_since_sprint or is_sprinting)
	
func set_ads(value : bool):
	print("toggling ADS: ", value)
	pass

func throw_object(object : RigidBody3D):
	print("throwing item")
	var inv : Inventory = (owner as HumanoidCharacter).inventory
	if object == inv.get_mainhand_item():
		inv.drop_mainhand_item()
	elif object == inv.get_offhand_item():
		inv.drop_offhand_item()
	var impulse := 100.0
	if (object is PickableItem) and object.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
		impulse = 50.0 * object.mass
	var impulse_vector := - main_camera.global_basis.z * impulse
	object.apply_central_impulse(impulse_vector)
	if object is PickableItem:
		object.set_item_state(GlobalConsts.ItemState.DAMAGING)
		if object is EquipmentItem:
			object.apply_throw_logic(impulse_vector)
	
	object.add_collision_exception_with(owner)
	if object.has_method(&"play_throw_sound"):
		object.play_throw_sound()

func place_object(object : RigidBody3D, at : Transform3D):
	var inv : Inventory = (owner as HumanoidCharacter).inventory
	if object == inv.get_mainhand_item():
		inv.drop_mainhand_item()
	elif object == inv.get_offhand_item():
		inv.drop_offhand_item()
	object.global_transform = at
	object.linear_velocity = Vector3.ZERO
	object.angular_velocity = Vector3.ZERO
	pass

func kick():
	owner.kick()
