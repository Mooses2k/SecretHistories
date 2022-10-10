extends Node


onready var character = get_parent()
export var max_placement_distance = 1.5
export var hold_time_to_place = 0.4
export var throw_strength : float = 2

export var hold_time_to_grab : float = 0.4
export var grab_strength : float = 2.0
#export var grab_spring_distance : float = 0.1
#export var grab_damping : float = 0.2

## Determines the real world directions each movement key corresponds to.
## By default, Right corresponds to +X, Left to -X, Up to -Z and Down to +Z
var movement_basis : Basis = Basis.IDENTITY
var interaction_target : Node = null
var target_placement_position : Vector3 = Vector3.ZERO


enum ItemSelection {
	ITEM_PRIMARY,
	ITEM_SECONDARY,
}

enum ThrowState {
	IDLE,
	PRESSING,
	SHOULD_PLACE,
	SHOULD_THROW,
}
var throw_state : int = ThrowState.IDLE
var throw_item : int = ItemSelection.ITEM_PRIMARY
var throw_press_length : float = 0.0

var stamina := 125.0

var active_mode_index = 0
onready var active_mode : ControlMode = get_child(0)


var grab_press_length : float = 0.0
var wanna_grab : bool = false
var is_grabbing : bool = false
var interaction_handled : bool = false
var grab_object : RigidBody = null
var grab_relative_object_position : Vector3
var grab_distance : float = 0.0
func _ready():
	active_mode.set_deferred("is_active", true)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta : float):
	active_mode.update()
	movement_basis = active_mode.get_movement_basis()
	interaction_target = active_mode.get_interaction_target()
	character.character_state.interaction_target = interaction_target
	interaction_handled = false
	handle_movement(delta)
	handle_grab_input(delta)
	handle_grab(delta)
	handle_inventory(delta)
	next_weapon()
	previous_weapon()
#	handle_misc_controls(delta)


func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				BUTTON_WHEEL_UP:
					if character.inventory.current_primary_slot!=0:
						character.inventory.current_primary_slot-=1
				BUTTON_WHEEL_DOWN:
					if character.inventory.current_primary_slot!=9:
						character.inventory.current_primary_slot+=1
#func handle_misc_controls(_delta : float):
#	if Input.is_action_just_pressed("toggle_perspective"):
#		active_mode_index = (active_mode_index + 1)%get_child_count()
#		active_mode.is_active = false
#		active_mode = get_child(active_mode_index)
#		active_mode.is_active = true

func handle_movement(_delta : float):
	var direction : Vector3 = Vector3.ZERO
	direction.x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.z += Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	direction = movement_basis.xform(direction)
	direction = direction.normalized()*min(1.0, direction.length())
	
	
	if Input.is_action_pressed("sprint") and stamina > 0:
		direction *= 0.5;
		change_stamina(-0.3)
	else:
		direction *= 0.2;
		if !Input.is_action_pressed("sprint"):
			change_stamina(0.3)
#	print(stamina)
		
	character.character_state.move_direction = direction

func handle_grab_input(delta : float):
	if Input.is_action_just_released("interact") and is_grabbing:
		is_grabbing = false
		interaction_handled = true
	if Input.is_action_pressed("interact"):
		grab_press_length += delta
	else:
		wanna_grab = false
		if Input.is_action_just_released("interact") and grab_press_length >= hold_time_to_grab:
			wanna_grab = true
			interaction_handled = true
		grab_press_length = 0.0

func handle_grab(delta : float):
	if wanna_grab and not is_grabbing:
#		print(wanna_grab)
		var object = active_mode.get_grab_target()
		if object:
			var grab_position = active_mode.get_grab_global_position()
			grab_relative_object_position = object.to_local(grab_position)
			grab_distance = owner.fps_camera.global_transform.origin.distance_to(grab_position)
			grab_object = object
			is_grabbing = true
	$MeshInstance.visible = is_grabbing
	$MeshInstance2.visible = is_grabbing
	if is_grabbing:
		var direct_state : PhysicsDirectBodyState = PhysicsServer.body_get_direct_state(grab_object.get_rid())
#		print("mass : ", direct_state.inverse_mass)
#		print("inertia : ", direct_state.inverse_inertia)
		
		# The position to drag the grabbed spot to, in global space
		var grab_target_global : Vector3 = active_mode.get_grab_target_position(grab_distance)
		
		# The position the object was grabbed at, in object local space
		var grab_object_local : Vector3 = grab_relative_object_position
		
		# The position the object was grabbed at, in global space
		var grab_object_global : Vector3 = direct_state.transform.xform(grab_object_local)
		
		# The offset from the center of the object to where it is being grabbed, in global space
		# this is required by some physics functions
		var grab_object_offset : Vector3  = grab_object_global - direct_state.transform.origin
		
		# Some visualization stuff
		$MeshInstance.global_transform.origin = grab_target_global
		$MeshInstance2.global_transform.origin = grab_object_global
		
		#local velocity of the object at the grabbing point, used to cancel the objects movement
		var local_velocity : Vector3 = direct_state.get_velocity_at_local_position(grab_object_local)
		
		# Desired velocity scales with distance to target, to a maximum of 2.0 m/s
		var desired_velocity : Vector3 = 32.0*(grab_target_global - grab_object_global)
		desired_velocity = desired_velocity.normalized()*min(desired_velocity.length(), 2.0)
		
		# Desired velocity follows the player character
		desired_velocity += owner.linear_velocity
		
		# Impulse is based on how much the velocity needs to change
		var velocity_delta = desired_velocity - local_velocity
		var impulse_velocity = velocity_delta*grab_object.mass
		
		# Counteract gravity on the grabbed object (and other 
		var impulse_forces = -(direct_state.total_gravity*grab_object.mass*delta)
		var total_impulse : Vector3 = impulse_velocity + impulse_forces
		total_impulse = total_impulse.normalized()*min(total_impulse.length(), grab_strength)
		
		# Applying torque separately, to make it less effective
		direct_state.apply_central_impulse(total_impulse)
		direct_state.apply_torque_impulse(0.2*(grab_object_offset.cross(total_impulse)))
		
		# Limits the angular velocity to prevent some issues
		direct_state.angular_velocity = direct_state.angular_velocity.normalized()*min(direct_state.angular_velocity.length(), 4.0)
		
		

func update_throw_state(delta : float):
	match throw_state:
		ThrowState.IDLE:
			if Input.is_action_just_pressed("main_throw") and owner.inventory.get_primary_item():
				throw_item = ItemSelection.ITEM_PRIMARY
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
			elif Input.is_action_just_pressed("offhand_throw") and owner.inventory.get_secondary_item():
				throw_item = ItemSelection.ITEM_SECONDARY
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
		ThrowState.PRESSING:
			if Input.is_action_pressed("main_throw" if throw_item == ItemSelection.ITEM_PRIMARY else "offhand_throw"):
				throw_press_length += delta
			else:
				throw_state = ThrowState.SHOULD_PLACE if throw_press_length > hold_time_to_grab else ThrowState.SHOULD_THROW
		ThrowState.SHOULD_PLACE, ThrowState.SHOULD_THROW:
			throw_state = ThrowState.IDLE
	pass

func handle_inventory(delta : float):
	var inv = character.inventory
	
	# Primary slot selection
	for i in range(character.inventory.HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]):
			inv.current_primary_slot = i
			throw_state = ThrowState.IDLE
	
	# Secondary slot selection
	if Input.is_action_just_pressed("cycle_offhand_slot"):
		var start_slot = inv.current_secondary_slot
		var new_slot = (start_slot + 1)%inv.hotbar.size()
		while new_slot != start_slot \
			and (
					(
						inv.hotbar[new_slot] != null \
						and inv.hotbar[new_slot].item_size != GlobalConsts.ItemSize.SIZE_SMALL\
					)\
					or new_slot == inv.current_primary_slot \
				):
				
				new_slot = (new_slot + 1)%inv.hotbar.size()
		if start_slot != new_slot:
			inv.current_secondary_slot = new_slot
			print("Offhand slot cycled to ", new_slot)
			throw_state = ThrowState.IDLE
	
	## Item Usage
	if Input.is_action_just_pressed("main_use_primary"):
		if inv.get_primary_item():
			inv.get_primary_item().use_primary()
			throw_state = ThrowState.IDLE
	
	if Input.is_action_just_pressed("main_use_secondary"):
		if inv.get_primary_item():
			inv.get_primary_item().use_secondary()
			throw_state = ThrowState.IDLE
	
	if Input.is_action_just_pressed("reload"):
		if inv.get_primary_item():
			inv.get_primary_item().use_reload()
			throw_state = ThrowState.IDLE
	
	if Input.is_action_just_pressed("offhand_use"):
		if inv.get_secondary_item():
			inv.get_secondary_item().use_primary()
			throw_state = ThrowState.IDLE
	
	
	
	
	if throw_state == ThrowState.SHOULD_PLACE:
		var item : EquipmentItem = inv.get_primary_item() if throw_item == ItemSelection.ITEM_PRIMARY else inv.get_secondary_item()
		if item:
			# Calculates where to place the item
			var origin : Vector3 = owner.drop_position_node.global_transform.origin
			var end : Vector3 = active_mode.get_target_placement_position()
			var dir : Vector3 = end - origin
			dir = dir.normalized()*min(dir.length(), max_placement_distance)
			var layers = item.collision_layer
			var mask = item.collision_mask
			item.collision_layer = item.dropped_layers
			item.collision_mask = item.dropped_mask
			var result = PhysicsTestMotionResult.new()
			# The return value can be ignored, since extra information is put into the 'result' variable
			PhysicsServer.body_test_motion(item.get_rid(), owner.inventory.drop_position_node.global_transform, dir, false, result, true)
			item.collision_layer = layers
			item.collision_mask = mask
			if result.motion.length() > 0.1:
				if throw_item == ItemSelection.ITEM_PRIMARY:
					inv.drop_primary_item()
				else:
					inv.drop_secondary_item()
				item.call_deferred("global_translate", result.motion)
		
	elif throw_state == ThrowState.SHOULD_THROW:
		var item : EquipmentItem = null
		if throw_item == ItemSelection.ITEM_PRIMARY:
			item = inv.get_primary_item()
			inv.drop_primary_item()
		else:
			item = inv.get_secondary_item()
			inv.drop_secondary_item()
		if item:
			var impulse = active_mode.get_aim_direction()*throw_strength
			# At this point, the item is still equipped, so we wait until
			# it exits the tree and is re inserted in the world
			item.apply_central_impulse(impulse)
	
	update_throw_state(delta)
	
#	if Input.is_action_just_released("throw") and throw_state:
#		throw_state = false
#		var item = inv.get_primary_item()
#		if item:
#			if throw_press_length < hold_time_to_place:
#				inv.drop_primary_item()
#				item.apply_central_impulse(active_mode.get_aim_direction()*throw_strength)
#			else:
#				var origin : Vector3 = owner.inventory.drop_position_node.global_transform.origin
#				var end : Vector3 = active_mode.get_target_placement_position()
#				var dir : Vector3 = end - origin
#				dir = dir.normalized()*min(dir.length(), max_placement_distance)
#				var layers = item.collision_layer
#				var mask = item.collision_mask
#				item.collision_layer = item.dropped_layers
#				item.collision_mask = item.dropped_mask
#				var result = PhysicsTestMotionResult.new()
#				# The return value can be ignored, since extra information is put into the 'result' variable
#				PhysicsServer.body_test_motion(item.get_rid(), owner.inventory.drop_position_node.global_transform, dir, false, result, true)
#				item.collision_layer = layers
#				item.collision_mask = mask
#				if result.motion.length() > 0.1:
#					item = yield(character.inventory.drop_current_item(), "completed") as RigidBody
#					if item:
#						item.call_deferred("global_translate", result.motion)
#
	if Input.is_action_just_released("interact") and not (wanna_grab or is_grabbing or interaction_handled):
		if interaction_target != null:
			if interaction_target is PickableItem:
				character.inventory.add_item(interaction_target)
				interaction_target = null
			elif interaction_target is Interactable:
				interaction_target.interact(owner)
	
#	if Input.is_action_pressed("throw") and throw_state:
#		throw_press_length += delta
#	else:
#		throw_press_length = 0.0
#	if Input.is_action_just_pressed("throw"):
#		throw_state = true

func change_stamina(amount: float) -> void:
	stamina = min(125, max(0, stamina + amount));
	HUDS.tired(stamina);
func previous_weapon():
	if Input.is_action_just_pressed("Previous_weapon") and character.inventory.current_primary_slot!=0:
			character.inventory.current_primary_slot-=1

func next_weapon():
	if Input.is_action_just_pressed("Next_weapon") and character.inventory.current_primary_slot!=9:
			character.inventory.current_primary_slot+=1
