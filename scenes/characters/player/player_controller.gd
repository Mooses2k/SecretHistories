extends Node
class_name PlayerController


const CAMERA_STANDING_HEIGHT = 1.6
const CAMERA_CROUCHING_HEIGHT = 1.1

# Constants for auto-switch weapon setting
const SETTING_AUTO_SWITCH_WEAPON: String = "Auto-switch weapons on throw"

@onready var state: HumanoidCharacterState = $"../State"
@onready var input: HumanoidCharacterInput = $"../Input"
@onready var main_camera: Camera3D = $"../ModelRoot/MainCamera"

var camera_pitch : float = 0.0
var drag_speed_modifier : float = 1.0

var moved_since_sprint : bool = false
var dodge_performed : bool = false




func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var sens = InputSettings.setting_mouse_sensitivity * 0.001
		camera_pitch -= sens*event.relative.y
		camera_pitch = clamp(camera_pitch, - PI * 0.5, PI * 0.5)
		state.facing = state.facing.rotated(Vector3.UP, -sens*event.relative.x)


func _process(_delta : float) -> void:
	main_camera.rotation.x = camera_pitch
	main_camera.position.y = lerp(CAMERA_STANDING_HEIGHT, CAMERA_CROUCHING_HEIGHT, state.current_crouch_ratio)


func _physics_process(delta: float) -> void:
	var input_vector_2d := Input.get_vector(&"movement|move_left", &"movement|move_right", &"movement|move_up", &"movement|move_down")
	var input_vector = Vector3(input_vector_2d.x, 0.0, input_vector_2d.y)
	
	# Apply drag speed modifier to movement
	input.movement_vector = state.facing * input_vector * drag_speed_modifier
	
	input.jump = Input.is_action_just_pressed(&"player|jump")
	input.sprint = Input.is_action_pressed(&"player|sprint")
	var is_sprinting := input.sprint and not input.movement_vector.is_zero_approx()
	input.crouch = Input.is_action_pressed(&"player|crouch") and not is_sprinting  # can't crouch if sprinting
	
	# Dodge detection
	if input.sprint and not dodge_performed:
		# Check for left, right, or down movement (not forward)
		var movement_direction = input.movement_vector.normalized()
		var forward_direction = -state.facing.z
		var dot_product = movement_direction.dot(forward_direction)
		
		# If moving sideways or backward (not forward)
		if not is_equal_approx(dot_product, 1.0) and not input.movement_vector.is_zero_approx():
			# Check if moving left, right, or down specifically AND move_up is NOT pressed
			# input_vector_2d.y < 0 means move_up is pressed
			if (input_vector_2d.x != 0 or input_vector_2d.y > 0) and input_vector_2d.y >= 0:
				owner.dodge()
				dodge_performed = true
	
	# If pressed sprint without moving, kick
	if Input.is_action_just_released(&"player|sprint") and not moved_since_sprint:
		kick()
	# moved is true if sprinting and either already moved or is moving, false otherwise
	moved_since_sprint = input.sprint and (moved_since_sprint or is_sprinting)


func set_drag_speed_modifier(modifier: float) -> void:
	drag_speed_modifier = max(modifier, 0.1)  # Ensure minimum 10% speed
	
	# Reset dodge_performed when sprint is released
	if not input.sprint:
		dodge_performed = false


func set_ads(value : bool):
	print("toggling ADS: ", value)
	pass


func throw_object(object : RigidBody3D):
	print("throwing item")
	var inv : Inventory = (owner as HumanoidCharacter).inventory
	
	# Check if the thrown object is from mainhand or offhand (hotbar)
	var is_mainhand = object == inv.get_mainhand_item()
	var is_offhand = object == inv.get_offhand_item()
	var thrown_from_hotbar = is_mainhand or is_offhand
	
	# Store the type of item being thrown for same-type search
	var thrown_item_type = null
	if object is MeleeItem:
		thrown_item_type = object.get_script()  # Get the script type for comparison
	
	# Determine which slot was thrown from
	var thrown_slot = -1
	if is_mainhand:
		inv.drop_mainhand_item()
		thrown_slot = inv.current_mainhand_slot
	elif is_offhand:
		inv.drop_offhand_item()
		thrown_slot = inv.current_offhand_slot
	
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
	
	# Auto weapon switching logic (only for hotbar throws, not grabbed items)
	if thrown_from_hotbar and GameSettings.get_auto_switch_weapon() != 2 and object is MeleeItem:  # 2 = "None"
		_auto_switch_weapon(inv, thrown_item_type, is_mainhand, is_offhand, thrown_slot, object)


# Add the auto switch weapon helper function
func _auto_switch_weapon(inv: Inventory, thrown_item_type, is_mainhand: bool, is_offhand: bool, thrown_slot: int, thrown_item):
	var auto_switch_mode = GameSettings.get_auto_switch_weapon()  # 0 = "Next same type then all", 1 = "Next same type only"
	
	# First check if the thrown item is from a stackable resource
	var stackable_resource = thrown_item.stackable_resource
	
	if stackable_resource != null:
		# Try to find the hotbar slot that contains this stackable resource
		for i in range(inv.hotbar.size()):
			var hotbar_item = inv.hotbar[i]
			if hotbar_item != null and hotbar_item.stackable_resource == stackable_resource:
				if stackable_resource.items_stacked.size() > 0:
					if is_mainhand:
						inv.current_mainhand_slot = i
						inv.equip_mainhand_item()
					elif is_offhand:
						inv.current_offhand_slot = i
						inv.equip_offhand_item()
					return
	
	# Variables to store found items for each priority level
	var same_type_item = null
	var same_type_slot = -1
	var small_item = null
	var small_slot = -1
	var medium_item = null
	var medium_slot = -1
	
	# Search through hotbar from lowest to highest (0 to size-1)
	# This ensures we follow the "lowest to highest" requirement
	
	# Safety check: Ensure hotbar is valid
	if inv.hotbar == null:
		print("[ERROR] _auto_switch_weapon: hotbar is null!")
		return
	if inv.hotbar.size() == 0:
		print("[ERROR] _auto_switch_weapon: hotbar is empty!")
		return
	
	# First priority: Check for same type items across all slots
	for i in range(inv.hotbar.size()):
		# Skip the slot that just had an item thrown
		if i == thrown_slot:
			continue
		
		# Safety check: Ensure index is valid
		if i < 0 or i >= inv.hotbar.size():
			print("[ERROR] _auto_switch_weapon: Invalid index ", i, " for hotbar size ", inv.hotbar.size())
			continue
			
		var item = inv.hotbar[i]
		if item == null:
			continue
			
		# Check if this is a melee item of the same type
		if item is MeleeItem and thrown_item_type != null and item.get_script() == thrown_item_type:
			same_type_item = item
			same_type_slot = i
			# If we only want same type, we can break early
			if auto_switch_mode == 1:  # "Next same type only"
				break
	
	# If we found a same type item and we're in "same type only" mode, equip it and return
	if same_type_item != null and auto_switch_mode == 1:
		if is_mainhand:
			inv.current_mainhand_slot = same_type_slot
			inv.equip_mainhand_item()
		elif is_offhand:
			inv.current_offhand_slot = same_type_slot
			inv.equip_offhand_item()
		return
	
	# Second priority: Check for SIZE_SMALL MeleeItems (only if we're not in "same type only" mode)
	if auto_switch_mode == 0:  # "Next same type then all"
		for i in range(inv.hotbar.size()):
			# Skip the slot that just had an item thrown
			if i == thrown_slot:
				continue
			
			# Safety check: Ensure index is valid
			if i < 0 or i >= inv.hotbar.size():
				print("[ERROR] _auto_switch_weapon: SIZE_SMALL search - Invalid index ", i, " for hotbar size ", inv.hotbar.size())
				continue
				
			var item = inv.hotbar[i]
			if item == null:
				continue
				
			# Check if this is a SIZE_SMALL MeleeItem
			if item is MeleeItem and item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
				small_item = item
				small_slot = i
				break  # Take the first one found (lowest slot)
	
	# Third priority: Check for SIZE_MEDIUM MeleeItems (only if we're not in "same type only" mode)
	if auto_switch_mode == 0 and small_item == null:  # Only check if we haven't found a small item
		for i in range(inv.hotbar.size()):
			# Skip the slot that just had an item thrown
			if i == thrown_slot:
				continue
			
			# Safety check: Ensure index is valid
			if i < 0 or i >= inv.hotbar.size():
				print("[ERROR] _auto_switch_weapon: SIZE_MEDIUM search - Invalid index ", i, " for hotbar size ", inv.hotbar.size())
				continue
				
			var item = inv.hotbar[i]
			if item == null:
				continue
				
			# Check if this is a SIZE_MEDIUM MeleeItem
			if item is MeleeItem and item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
				medium_item = item
				medium_slot = i
				break  # Take the first one found (lowest slot)
	
	# Equip the appropriate item based on priority and settings
	var item_to_equip = null
	var slot_to_equip = -1
	
	if same_type_item != null:
		# Found same type item
		item_to_equip = same_type_item
		slot_to_equip = same_type_slot
	elif auto_switch_mode == 0:  # "Next same type then all"
		# Look for SIZE_SMALL first, then SIZE_MEDIUM
		if small_item != null:
			item_to_equip = small_item
			slot_to_equip = small_slot
		elif medium_item != null:
			item_to_equip = medium_item
			slot_to_equip = medium_slot
	
	# Equip the found item to the appropriate hand
	if item_to_equip != null and slot_to_equip != -1:
		if is_mainhand:
			inv.current_mainhand_slot = slot_to_equip
			inv.equip_mainhand_item()
		elif is_offhand:
			inv.current_offhand_slot = slot_to_equip
			inv.equip_offhand_item()




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
