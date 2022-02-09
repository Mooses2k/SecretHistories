extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var character = get_parent()

func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	handle_movement()
	handle_equipment()
	handle_inventory()

func handle_movement():
	var direction : Vector3 = Vector3.ZERO
	direction.x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.z += Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
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
		if character.pickup_area.get_item_list().size() > 0:
			character.inventory.add_item(character.pickup_area.get_item_list()[0])
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
