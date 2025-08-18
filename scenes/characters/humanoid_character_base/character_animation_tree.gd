extends AnimationTree

#TODO : crouch walk forwards right and forwards left are flipped.
# so we have to fix that when the animation names get fixed

@onready var parameters: HumanoidCharacterParameters = $"../Parameters"
@onready var state: HumanoidCharacterState = $"../State"

const ADS = "parameters/ads/blend_amount"
const CROUCH = "parameters/crouch/blend_amount"
const GROUNDED = "parameters/grounded/blend_amount"
const GUN_READY = "parameters/gun_ready/blend_amount"
const MOVEMENT = "parameters/movement/blend_position"
const MOVEMENT_CROUCHED = "parameters/movement_crouch/blend_position"
const RUN = "parameters/run/blend_amount"
const VERTICAL_DIRECTION = "parameters/vertical_direction/blend_position"
@onready var humanoid_character_base: HumanoidCharacter = owner as HumanoidCharacter

@onready var ads : float = 0.0:
	set(value):
		set(ADS, value)
	get:
		return get(ADS)
@onready var crouch : float = 0.0:
	set(value):
		set(CROUCH, value)
	get:
		return get(CROUCH)
@onready var grounded : float = 1.0:
	set(value):
		set(GROUNDED, value)
	get:
		return get(GROUNDED)
@onready var gun_ready : float = 0.0:
	set(value):
		set(GUN_READY, value)
	get:
		return get(GUN_READY)

@onready var movement : Vector2 = Vector2.ZERO:
	set(value):
		set(MOVEMENT, value)
		set(MOVEMENT_CROUCHED, value)
	get:
		return get(MOVEMENT)
@onready var run : float = 0.0:
	set(value):
		set(RUN, value)
	get:
		return get(RUN)

@onready var vertical_direction : float = 0.0:
	set(value):
		set(VERTICAL_DIRECTION, value)
	get:
		return get(VERTICAL_DIRECTION)

@onready var model_root: Node3D = $"../ModelRoot"

func _ready() -> void:
	await owner.ready
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var target_movement_3d : Vector3 = owner.linear_velocity/parameters.base_speed
	target_movement_3d.y = 0.0
	target_movement_3d *= model_root.basis
	var target_movement : Vector2 = Vector2(-target_movement_3d.x, target_movement_3d.z)
	movement = movement.move_toward(target_movement, 6.0*delta)

	crouch = state.current_crouch_ratio

	var target_grounded = 1.0 if state.is_on_ground else 0.0
	var grounded_speed = 6.0 if target_grounded > grounded else 2.0
	grounded = move_toward(grounded, target_grounded, grounded_speed*delta)

	vertical_direction = clampf(owner.linear_velocity.y*0.1, -1.0, 1.0)

	var target_run = owner.linear_velocity.length()/state.get_target_speed() if state.sprinting else 0.0
	run = move_toward(run, target_run, 10.0*delta)
	pass
