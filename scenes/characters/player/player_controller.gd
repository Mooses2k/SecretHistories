extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var character = get_parent()

## Determines the real world directions each movement key corresponds to.
## By default, Right corresponds to +X, Left to -X, Up to -Z and Down to +Z
var movement_basis : Basis = Basis.IDENTITY
var interaction_target : Node = null

var active_mode_index = 0
onready var active_mode : ControlMode = get_child(0)

func _ready():
	active_mode.set_deferred("is_active", true)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	active_mode.update()
	movement_basis = active_mode.get_movement_basis()
	interaction_target = active_mode.get_interaction_target()
	handle_movement()
	handle_equipment()
	handle_inventory()
	handle_misc_controls()

func handle_misc_controls():
	if Input.is_action_just_pressed("toggle_perspective"):
		active_mode_index = (active_mode_index + 1)%get_child_count()
		active_mode.is_active = false
		active_mode = get_child(active_mode_index)
		active_mode.is_active = true

func handle_movement():
	var direction : Vector3 = Vector3.ZERO
	direction.x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.z += Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	direction = movement_basis.xform(direction)
	direction = direction.normalized()*min(1.0, direction.length())
	if not Input.is_action_pressed("sprint"):
		direction *= 0.5;
	character.character_state.move_direction = direction

func handle_equipment():
	if Input.is_action_just_pressed("attack"):
		if character.inventory.current_equipment:
			character.inventory.current_equipment.use()

func handle_inventory():
	if Input.is_action_just_pressed("interact"):
		if interaction_target != null:
			if interaction_target is PickableItem:
				character.inventory.add_item(interaction_target)
				interaction_target = null
	if Input.is_action_just_pressed("throw"):
		character.inventory.drop_current_item()
	for i in range(character.inventory.HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]):
			character.inventory.current_slot = i
	if Input.is_action_just_pressed("reload"):
		if character.inventory.current_equipment.has_method("reload"):
			print("Trying to reload")
			character.inventory.current_equipment.reload()
	pass
