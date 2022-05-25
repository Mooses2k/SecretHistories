extends Node


onready var character = get_parent()
export var max_placement_distance = 1.5
export var hold_time_to_place = 0.4
export var throw_strength : float = 2
## Determines the real world directions each movement key corresponds to.
## By default, Right corresponds to +X, Left to -X, Up to -Z and Down to +Z
var movement_basis : Basis = Basis.IDENTITY
var interaction_target : Node = null
var target_placement_position : Vector3 = Vector3.ZERO

var throw_press_length : float = 0.0
var throw_state : bool = false

var stamina := 100.0
var active_mode_index = 0
onready var active_mode : ControlMode = get_child(0)


func _ready():
	active_mode.set_deferred("is_active", true)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta : float):
	active_mode.update()
	movement_basis = active_mode.get_movement_basis()
	interaction_target = active_mode.get_interaction_target()
	handle_movement(delta)
	handle_equipment(delta)
	handle_inventory(delta)
	handle_misc_controls(delta)

func handle_misc_controls(_delta : float):
	if Input.is_action_just_pressed("toggle_perspective"):
		active_mode_index = (active_mode_index + 1)%get_child_count()
		active_mode.is_active = false
		active_mode = get_child(active_mode_index)
		active_mode.is_active = true

func handle_movement(_delta : float):
	var direction : Vector3 = Vector3.ZERO
	direction.x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.z += Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	direction = movement_basis.xform(direction)
	direction = direction.normalized()*min(1.0, direction.length())
	
	
	if Input.is_action_pressed("sprint") and stamina > 0:
		direction *= 0.5;
		change_stamina(-0.5)
	else:
		direction *= 0.3;
		if !Input.is_action_pressed("sprint"):
			change_stamina(0.5)
	print(stamina)
		
		
	character.character_state.move_direction = direction


func handle_equipment(_delta : float):
	if Input.is_action_just_pressed("attack"):
		if throw_state:
			throw_state = false
		elif character.inventory.current_equipment:
			character.inventory.current_equipment.use()


func handle_inventory(delta : float):
	for i in range(character.inventory.HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]):
			character.inventory.current_slot = i
			throw_state = false
	if Input.is_action_just_pressed("reload"):
		if character.inventory.current_equipment and character.inventory.current_equipment.has_method("reload"):
			print("Trying to reload")
			character.inventory.current_equipment.reload()
			throw_state = false
	
	
	if Input.is_action_just_released("throw") and throw_state:
		throw_state = false
		if character.inventory.current_equipment:
			if throw_press_length < hold_time_to_place:
				var item = yield(character.inventory.drop_current_item(), "completed") as RigidBody
				if item:
					item.apply_central_impulse(active_mode.get_aim_direction()*throw_strength)
			else:
				var item = character.inventory.current_equipment as RigidBody
				var origin : Vector3 = owner.inventory.drop_position_node.global_transform.origin
				var end : Vector3 = active_mode.get_target_placement_position()
				var dir : Vector3 = end - origin
				dir = dir.normalized()*min(dir.length(), max_placement_distance)
				var result = PhysicsTestMotionResult.new()
				var layers = item.collision_layer
				var mask = item.collision_mask
				item.collision_layer = item.dropped_layers
				item.collision_mask = item.dropped_mask
				assert(PhysicsServer.body_test_motion(item.get_rid(), owner.inventory.drop_position_node.global_transform, dir, false, result, true))
				item.collision_layer = layers
				item.collision_mask = mask
				if result.motion.length() > 0.1:
					item = yield(character.inventory.drop_current_item(), "completed") as RigidBody
					if item:
						item.call_deferred("global_translate", result.motion)
	
	if Input.is_action_just_pressed("interact"):
		if interaction_target != null:
			if interaction_target is PickableItem:
				character.inventory.add_item(interaction_target)
				interaction_target = null
			elif interaction_target is Interactable:
				interaction_target.interact(owner)
	
	if Input.is_action_pressed("throw") and throw_state:
		throw_press_length += delta
	else:
		throw_press_length = 0.0
	if Input.is_action_just_pressed("throw"):
		throw_state = true

func change_stamina(amount: float) -> void:
	stamina = min(500, max(0, stamina + amount));
	HUDS.tired(stamina);
