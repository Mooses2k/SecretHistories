extends Node

# There can be multiple types of controller using this, such as an fps_control_mode, top_down, vr, etc
# This script is for things agnostic to the type of player controller


signal is_moving(is_player_moving)

var is_player_moving : bool = false

export var max_placement_distance = 1.5
export var hold_time_to_place = 0.4
export var throw_strength : float = 20
const ON_GRAB_MAX_SPEED : float = 0.1

export var hold_time_to_grab : float = 0.4
export var grab_strength : float = 1000.0

#export var grab_spring_distance : float = 0.1
#export var grab_damping : float = 0.2

# Determines the real world directions each movement key corresponds to.
# By default, Right corresponds to +X, Left to -X, Up to -Z and Down to +Z
var movement_basis : Basis = Basis.IDENTITY
var interaction_target : Node = null
var target_placement_position : Vector3 = Vector3.ZERO

#export var _grabcast : NodePath
#onready var grabcast : RayCast = get_node(_grabcast) as RayCast

#export var _aimcast : NodePath
#onready var aimcast : RayCast = get_node(_aimcast) as RayCast

enum ItemSelection {
	ITEM_MAINHAND,
	ITEM_OFFHAND,
}

enum ThrowState {
	IDLE,
	PRESSING,
	SHOULD_PLACE,
	SHOULD_THROW,
}

var throw_state : int = ThrowState.IDLE
var throw_item_hand : int = ItemSelection.ITEM_MAINHAND
var throw_item : EquipmentItem
var throw_press_length : float = 0.0

export(float, 0.05, 1.0) var crouch_rate = 0.08
export(float, 0.1, 1.0) var crawl_rate = 0.5
export var move_drag : float = 0.2
export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export var interact_distance : float = 0.75
export var head_bob_enabled : bool = true   # TODO: Should be in settings not here

var velocity : Vector3 = Vector3.ZERO

var _clamber_m = null

onready var character = get_parent()
export var _cam_path : NodePath
onready var _camera : ShakeCamera = get_node(_cam_path)
#export var _gun_cam_path : NodePath
#onready var _gun_cam = get_node(_gun_cam_path)
onready var _frob_raycast = get_node("../FPSCamera/GrabCast")
onready var _text = get_node("..//Indication_canvas/Label")
#onready var _player_hitbox = get_node("../CanStandChecker")
onready var _ground_checker = get_node("../Body/GroundChecker")
onready var _screen_filter = get_node("../FPSCamera/ScreenFilter")
onready var _debug_light = get_node("../FPSCamera/DebugLight")

onready var item_drop_sound_flesh : AudioStream = load("res://resources/sounds/impacts/blade_to_flesh/blade_to_flesh.wav")   # doesn't belong here, hack
onready var kick_sound : AudioStream = load("res://resources/sounds/throwing/346373__denao270__throwing-whip-effect.wav")

# Control modes are things like FPS, topdown, VR
var current_control_mode_index = 0
onready var current_control_mode : ControlMode = get_child(0)

var grab_press_length : float = 0.0
var wanna_grab : bool = false
var is_grabbing : bool = false
var interaction_handled : bool = false
var grab_object : RigidBody = null
var grab_relative_object_position : Vector3
var grab_distance : float = 0
#var target
var current_grab_object = null   # Can this be replaced by just grab_object?
var wants_to_drop = false
var _click_timer : float = 0.0
var _throw_wait_time : float = 400
var drag_object : RigidBody = null

var is_movement_key1_held = false
var is_movement_key2_held = false
var is_movement_key3_held = false
var is_movement_key4_held = false
var movement_press_length = 0

var has_moved_after_pressing_sprint = false

var crouch_target_pos = -0.55

var clamberable_obj : RigidBody
var item_up = false
var camera_movement_resistance : float = 1.0

# For tracking short or long press of cycle_offhand_slot
var _cycle_offhand_timer : float = 0.0
var _swap_hands_wait_time : float = 500

# For tracking whether to reload or unload mainhand item
var _reload_press_timer : float = 0.0
var _unload_wait_time : float = 500

var no_click_after_load_period : bool = false

# Screen filter section
enum ScreenFilter {
	NONE,
	OLD_FILM,
	PIXELATE,
	DITHER,
	REDUCE_COLOR,
	PSX,
	DEBUG_LIGHT
}

var current_screen_filter : int = GameManager.ScreenFilter.NONE
#export var pixelated_material : Material
#export var dither_material : Material
#export var reduce_color_material : Material
var changed_to_reduce_color = false   # Have we changed to reduce color filter on DLvl5?

onready var noise_timer = $"../Audio/NoiseTimer"   # Because instant noises sometimes aren't detected


func _ready():
	owner.is_to_move = false
	_clamber_m = ClamberManager.new(owner, _camera, owner.get_world())
	
	current_control_mode.set_deferred("is_active", true)
	
#	_screen_filter.visible = false
	
	if OS.has_feature("editor"):
		Events.connect_to("debug_filter_forced", self, "_set_screen_filter_to")


func _physics_process(delta : float):
	current_control_mode.update(delta)   # Added delta when doing programming recoil
	movement_basis = current_control_mode.get_movement_basis()
	interaction_target = current_control_mode.get_interaction_target()
	character.character_state.interaction_target = interaction_target
	interaction_handled = false
	throw_item = null
	current_grab_object = current_control_mode.get_grab_target()
	
	### TODO: many of these shouldn't be here and probably shouldn't be checked every _physics_process (moved in _input()?)
	_walk(delta)
	_crouch()
	_handle_grab_input(delta)
	handle_grab(delta)
	_handle_inventory(delta)
	handle_screen_filters()
	handle_binocs()
	next_item()
	previous_item()
	drop_grabable()
	empty_slot()
	_clamber()


func _input(event):
	if event is InputEventMouseButton and owner.is_reloading == false:
		if event.pressed:
			match event.button_index:
				BUTTON_WHEEL_UP:
					item_up = true
					if item_up:
						if character.inventory.current_mainhand_slot != 0:
							var total_inventory
							if  character.inventory.bulky_equipment:
								total_inventory = 10
							else:
								total_inventory = character.inventory.current_mainhand_slot - 1
							if total_inventory != character.inventory.current_offhand_slot:
								character.inventory.current_mainhand_slot = total_inventory
							else:
								var plus_inventory
								if  character.inventory.bulky_equipment:
									plus_inventory = 10
								else:
									plus_inventory = total_inventory - 1
								if plus_inventory != -1:
									character.inventory.current_mainhand_slot = plus_inventory
								else:
									character.inventory.current_mainhand_slot = 10
						elif character.inventory.current_mainhand_slot == 0:
							character.inventory.current_mainhand_slot = 10
				
				BUTTON_WHEEL_DOWN:
					item_up = false
					if !item_up:
						if character.inventory.current_mainhand_slot != 10:
							var total_inventory
							if  character.inventory.bulky_equipment:
								total_inventory = 0
							else:
								total_inventory = character.inventory.current_mainhand_slot + 1
							if total_inventory != character.inventory.current_offhand_slot:
								character.inventory.current_mainhand_slot = total_inventory
							else:
								var plus_inventory = total_inventory + 1
								if character.inventory.current_offhand_slot != 10:
									character.inventory.current_mainhand_slot = plus_inventory
								else:
									character.inventory.current_mainhand_slot = 10
						elif character.inventory.current_mainhand_slot == 10:
							if character.inventory.current_offhand_slot != 0:
								character.inventory.current_mainhand_slot = 0
							else:
								character.inventory.current_mainhand_slot = 1


func _walk(delta) -> void:
	var move_dir = Vector3()
	if !character.kick_timer.is_stopped():   # So you can't move while kicking
		if character.grounded:   # So you can do jumpkicks
			character.character_state.move_direction = Vector3.ZERO
		return
	
	if Input.is_action_just_pressed("movement|move_right"):
		is_movement_key1_held = true
	if Input.is_action_just_pressed("movement|move_left"):
		is_movement_key2_held = true
	if Input.is_action_just_pressed("movement|move_down"):
		is_movement_key3_held = true
	if Input.is_action_just_pressed("movement|move_up"):
		is_movement_key4_held = true
		owner.is_moving_forward = true
	
	_check_movement_key(delta)
	
	move_dir.x = (Input.get_action_strength("movement|move_right") - Input.get_action_strength("movement|move_left"))
	move_dir.z = (Input.get_action_strength("movement|move_down") - Input.get_action_strength("movement|move_up"))
	character.character_state.move_direction = move_dir.normalized()
	
	# This logic has the player kick if they hit sprint and release it without moving
	if Input.is_action_pressed("player|sprint"):
		has_moved_after_pressing_sprint = false
		if is_movement_key1_held or is_movement_key2_held or is_movement_key3_held or is_movement_key4_held:
			has_moved_after_pressing_sprint = true
			owner.do_sprint = true
			$"../Stamina".tired(owner.stamina)   # TODO: get this working for character too
			# Lower the stamina, higher the noise, from 1 to 7 given 600 stamina
			# This does make noise_level a float not an int and is the only place this happens as of 6/11/2023
			owner.noise_level = 7 - owner.stamina * 0.01   # It's 7 so extremely acute hearing can hear you breathe at rest
	
	if Input.is_action_just_released("player|sprint"):
		owner.do_sprint = false
		if !has_moved_after_pressing_sprint:
			character.kick()
	
	if Input.is_action_just_released("movement|move_right"):
		is_movement_key1_held = false
	if Input.is_action_just_released("movement|move_left"):
		is_movement_key2_held = false
	if Input.is_action_just_released("movement|move_down"):
		is_movement_key3_held = false
	if Input.is_action_just_released("movement|move_up"):
		is_movement_key4_held = false
		owner.is_moving_forward = false
	
	_check_movement_key(delta)
	
	if Input.is_action_just_pressed("player|jump"):
		owner.do_jump = true
	
	if current_control_mode.has_method("head_bob") and head_bob_enabled and owner.grounded and owner.state == owner.State.STATE_WALKING:
		current_control_mode.head_bob(delta)


func _check_movement_key(delta):
	if is_movement_key1_held or is_movement_key2_held or is_movement_key3_held or is_movement_key4_held:
		movement_press_length += delta
		if movement_press_length >= 0.25:
			owner.is_to_move = true
			if !owner.is_crouching:
				if owner.do_sprint and is_movement_key4_held == true:   # Only if sprinting forward
					if owner.noise_level < 10 + (character.inventory.encumbrance):
						owner.noise_level = 10 + (character.inventory.encumbrance)
						noise_timer.start()
				else:
					if owner.noise_level < 5 + (character.inventory.encumbrance):
						owner.noise_level = 5 + (character.inventory.encumbrance)
						noise_timer.start()
			else:
				if owner.noise_level < 3 + (character.inventory.encumbrance):
					owner.noise_level = 3 + (character.inventory.encumbrance)
					noise_timer.start()
	
	if !is_movement_key1_held and !is_movement_key2_held and !is_movement_key3_held and !is_movement_key4_held:
		movement_press_length = 0.0
		owner.is_to_move = false


func _crouch() -> void:
	if GameSettings.crouch_hold_enabled:
		if Input.is_action_pressed("player|crouch"):
			if owner.do_sprint:
				owner.do_crouch = false
				return
				
			owner.do_crouch = true
			owner.state = owner.State.STATE_CROUCHING
			
			if current_control_mode.has_method("crouch_cam"):
				current_control_mode.crouch_cam()
			
		if !Input.is_action_pressed("player|crouch"):
			owner.do_crouch = false
		
	else:
		if owner.do_sprint:
			owner.do_crouch = false
			return
		if Input.is_action_just_pressed("player|crouch"):
			owner.do_crouch = !owner.do_crouch
			if owner.do_crouch:
				owner.state = owner.State.STATE_CROUCHING
		if owner.do_crouch:
			if current_control_mode.has_method("crouch_cam"):
				current_control_mode.crouch_cam()


func _handle_grab_input(delta : float):
	if is_grabbing:
		wanna_grab = true
	else:
		wanna_grab = false
	if Input.is_action_pressed("player|interact"):   # TODO: when RigidBody doors are back, reinclude:  or Input.is_action_pressed("playerhand|main_use_secondary"):
		if is_grabbing == false:
			grab_press_length += delta
			if grab_press_length >= 0.15:
				wanna_grab = true
				interaction_handled = true
	
	if Input.is_action_just_released("player|interact"):   # TODO: when RigidBody doors are back, reinclude:  or Input.is_action_pressed("playerhand|main_use_secondary"):
		grab_press_length = 0.0
		if is_grabbing == true:
			is_grabbing = false
			print("Grab broken by letting go of grab key")
			if grab_object is PickableItem:   # So no plain RigidBodies or large objects
				grab_object.set_item_state(GlobalConsts.ItemState.DAMAGING)    # This allows dropped items to hit cultists
			wanna_grab = false
			interaction_handled = true
		camera_movement_resistance = 1.0   # In case of a grab-throw, make sure the camera turning still isn't slowed


func handle_grab(delta : float):
	if wants_to_drop == false:
		if wanna_grab and not is_grabbing:
			
			var object = current_control_mode.get_grab_target()
			
			if object:
				var grab_position = current_control_mode.get_grab_global_position()
				grab_relative_object_position = object.to_local(grab_position)
				grab_distance = _camera.global_transform.origin.distance_to(grab_position)
				grab_object = object
				is_grabbing = true
				print("Just grabbed: ", grab_object)
				if grab_object is PickableItem:   # So no plain RigidBodies or large objects
					grab_object.set_item_state(GlobalConsts.ItemState.DAMAGING)   # This is so any pickable_item collides with cultists
					grab_object.check_item_state()
	
	# These are debug indicators for initial and current grab points
	$GrabInitial.visible = false
	$GrabCurrent.visible = false
	
	if is_grabbing:
		var direct_state : PhysicsDirectBodyState = PhysicsServer.body_get_direct_state(grab_object.get_rid())
#		print("mass : ", direct_state.inverse_mass)
#		print("inertia : ", direct_state.inverse_inertia)
		
		# The position to drag the grabbed spot to, in global space
		var grab_target_global : Vector3 = current_control_mode.get_grab_target_position(grab_distance)
		
		# The position the object was grabbed at, in object local space
		var grab_object_local : Vector3 = grab_relative_object_position
		
		# The position the object was grabbed at, in global space
		var grab_object_global : Vector3 = direct_state.transform.xform(grab_object_local)
		
		# The offset from the center of the object to where it is being grabbed, in global space
		# this is required by some physics functions
		var grab_object_offset : Vector3  = grab_object_global - direct_state.transform.origin
		
		# Some debug visualization stuff for grabbing
		$GrabInitial.global_transform.origin = grab_target_global
		$GrabCurrent.global_transform.origin = grab_object_global
		
		# Slows down camera turn sensitivity to simulate moving something heavy
		camera_movement_resistance = min(5 / grab_object.mass, 1)   # Camera goes nuts if you don't do this
		
		if $GrabInitial.global_transform.origin.distance_to($GrabCurrent.global_transform.origin) >= 0.3 and !grab_object is PickableItem:
			is_grabbing = false
			print("Grab broken by distance")
			if grab_object is PickableItem:   # So not for plain RigidBodies or otherwise large objects
				grab_object.set_item_state(GlobalConsts.ItemState.DROPPED)
			interaction_handled = true
			camera_movement_resistance = 1.0
		
		var local_velocity : Vector3 = direct_state.get_velocity_at_local_position(grab_object_local)
		
		# Desired velocity scales with distance to target, to a maximum of 2.0 m/s
		var desired_velocity : Vector3 = 32.0 * (grab_target_global - grab_object_global)
		desired_velocity = desired_velocity.normalized() * min(desired_velocity.length(), 2.0)
		
		# Desired velocity follows the player character
		desired_velocity += velocity
		
		# Impulse is based on how much the velocity needs to change
		var velocity_delta = desired_velocity - local_velocity
		var impulse_velocity = velocity_delta * grab_object.mass
		
		# Counteract gravity on the grabbed object (and other
		var impulse_forces = -(direct_state.total_gravity * grab_object.mass*delta)
		var total_impulse : Vector3 = impulse_velocity + impulse_forces
		total_impulse = total_impulse.normalized() * min(total_impulse.length(), grab_strength)
		
		# Applying torque separately, to make it less effective
		direct_state.apply_central_impulse(total_impulse)
		direct_state.apply_torque_impulse(2.5 * (grab_object_offset.cross(total_impulse))) #0.2
		
		# Calculate additional force based on the weight of the object
		var additional_force = Vector3.ZERO
		if grab_object.mass > 80:
			additional_force = owner.velocity * ((1 / grab_object.mass) * 50)
		
		# Modify player's movement based on additional force
			if owner.is_player_moving:
				owner.velocity.x = additional_force.x * delta
				owner.velocity.z = additional_force.z * delta
		
		# Limits the angular velocity to prevent some issues
		direct_state.angular_velocity = direct_state.angular_velocity.normalized() * min(direct_state.angular_velocity.length(), 4.0)


func _handle_inventory(delta : float):
	# Main-hand slot selection
	for i in range(character.inventory.HOTBAR_SIZE - 1):
		# hotbar_%d is a nasty hack which prevents renaming hotbar_11 to holster_offhand in Input Map
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]) and owner.is_reloading == false:
			# Don't select current offhand slot and don't select 10 because it's hotbar_11, used for holstering offhand item, below
			if i != character.inventory.current_offhand_slot and i != 10:
				character.inventory.drop_bulky_item()
				character.inventory.current_mainhand_slot = i
				throw_state = ThrowState.IDLE
	
	# Off-hand slot selection or swap items in hands based on length of press of cycle_offhand_slot
	if Input.is_action_just_pressed("playerhand|cycle_offhand_slot") and owner.is_reloading == false:
		_cycle_offhand_timer = Time.get_ticks_msec()
	
	if Input.is_action_just_released("playerhand|cycle_offhand_slot") and owner.is_reloading == false:
		# If it's a long press, swap hands, if not, cycle slot
		if _cycle_offhand_timer + _swap_hands_wait_time < Time.get_ticks_msec():
			if _cycle_offhand_timer == 0.0:
				return
			# Player intends to swap
			character.inventory.swap_hands()
			_cycle_offhand_timer = 0.0
			return
		
		# Player intends to cycle slot instead of swapping hands
		else:
			_cycle_offhand_timer = 0.0
			
		var start_slot = character.inventory.current_offhand_slot
		var new_slot = (start_slot + 1) % character.inventory.hotbar.size()
		while new_slot != start_slot \
			and (
				(
					character.inventory.hotbar[new_slot] != null \
					and character.inventory.hotbar[new_slot].item_size != GlobalConsts.ItemSize.SIZE_SMALL\
				)\
				or new_slot == character.inventory.current_mainhand_slot \
				or character.inventory.hotbar[new_slot] == null \
				):
				
				new_slot = (new_slot + 1) % character.inventory.hotbar.size()
				
		if start_slot != new_slot:
			character.inventory.current_offhand_slot = new_slot
			print("Offhand slot cycled to ", new_slot)
			throw_state = ThrowState.IDLE
	
	if Input.is_action_just_pressed("itm|holster_offhand"):
		if character.inventory.current_offhand_slot != 10:
			character.inventory.current_offhand_slot = 10
	
	# Item Usage
	# temporary hack (issue #409)
	if is_instance_valid(character.inventory.get_mainhand_item()):
		if Input.is_action_just_pressed("playerhand|main_use_primary"):
			# Check if grace period has elapsed since loadscreen removed to avoid accidentally shooting after load
			if no_click_after_load_period == false:
				if character.inventory.get_mainhand_item():
					character.inventory.get_mainhand_item().use_primary()
					if character.inventory.get_mainhand_item() is MeleeItem:
						$"%AnimationTree".set("parameters/MeleeSpeed/scale", character.inventory.get_mainhand_item().melee_attack_speed)
						$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 1)
						$"%AnimationTree".set("parameters/MeleeThrust/active", true)
						owner.noise_level = 8
					throw_state = ThrowState.IDLE

		if Input.is_action_just_pressed("playerhand|main_use_secondary"):
			# This means R-Click can be used to interact when pointing at an interactable
			if character.inventory.get_mainhand_item(): # and interaction_target == null:   # TODO: put this back in when we have RClick also as interact after RigidBody doors
				character.inventory.get_mainhand_item().use_secondary()
				if character.inventory.get_mainhand_item() is MeleeItem:
					$"%AnimationTree".set("parameters/MeleeSpeed/scale", character.inventory.get_mainhand_item().melee_attack_speed)
					$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 1)
					$"%AnimationTree".set("parameters/MeleeChop1/active", true)
					owner.noise_level = 10
				throw_state = ThrowState.IDLE
			
		if Input.is_action_just_released("playerhand|main_use_primary"):
			$"%AnimationTree".set("parameters/MeleeSpeed/scale", 1)
		
		if Input.is_action_just_released("playerhand|main_use_secondary"):
			$"%AnimationTree".set("parameters/MeleeSpeed/scale", 1)
	# Start timer to check if want to reload or unload
	if Input.is_action_just_pressed("player|reload"):
		if character.inventory.get_mainhand_item():
			_reload_press_timer = Time.get_ticks_msec()
			
	if Input.is_action_just_released("player|reload"):
		if character.inventory.get_mainhand_item():
			
			if _reload_press_timer + _unload_wait_time < Time.get_ticks_msec():
				if _reload_press_timer == 0.0:
					return
				# Player intends to unload not reload
				character.inventory.get_mainhand_item().use_unload()
				throw_state = ThrowState.IDLE
				_reload_press_timer = 0.0
				return
			
			else:
				_reload_press_timer = 0.0
				
			character.inventory.get_mainhand_item().use_reload()
			throw_state = ThrowState.IDLE
		
	if Input.is_action_just_pressed("playerhand|offhand_use") and owner.is_reloading == false:
		if character.inventory.get_offhand_item():
			character.inventory.get_offhand_item().use_primary()
			if character.inventory.get_offhand_item() is MeleeItem:
				$"%AnimationTree".set("parameters/MeleeSpeed/scale", character.inventory.get_offhand_item().melee_attack_speed)
				$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
				$"%AnimationTree".set("parameters/MeleeThrustL/active", true)
			throw_state = ThrowState.IDLE
	
	update_throw_state(throw_item, delta)
	
	if Input.is_action_just_released("player|interact"): # Later, when we have RigidBody doors, add this back for convenience and deal with edge cases with ADS and melee:  or Input.is_action_just_released("playerhand|main_use_secondary"):
		if !(wanna_grab or is_grabbing or interaction_handled):
			if interaction_target != null:
				if interaction_target is PickableItem:   # and character.inventory.current_mainhand_slot != 10:
					character.inventory.add_item(interaction_target)
					interaction_target = null
				elif interaction_target is Interactable:
					interaction_target.interact(owner)
	
	#Block light sources control


func previous_item():
	if Input.is_action_just_pressed("itm|previous_hotbar_item") and character.inventory.current_mainhand_slot != 0 and !Input.is_key_pressed(KEY_SHIFT):
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot -=1
	
	elif Input.is_action_just_pressed("itm|previous_hotbar_item") and character.inventory.current_mainhand_slot == 0 and !Input.is_key_pressed(KEY_SHIFT):
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot = 10


func next_item():
	if Input.is_action_just_pressed("itm|next_hotbar_item") and character.inventory.current_mainhand_slot != 10 and !Input.is_key_pressed(KEY_SHIFT):
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot += 1
	
	elif Input.is_action_just_pressed("itm|next_hotbar_item") and character.inventory.current_mainhand_slot == 10 and !Input.is_key_pressed(KEY_SHIFT):
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot = 0


func drop_grabable():
	# When the drop button or keys are pressed, grabable objects are released
	if Input.is_action_just_pressed("playerhand|main_throw") or Input.is_action_just_pressed("playerhand|offhand_throw"):
		if is_grabbing == true:
			wants_to_drop = true
			if grab_object != null:
				is_grabbing = false
				print("Grab broken by throw")
				interaction_handled = true
				
				# TODO: This duplicates code in update_throw_state(); fix that
				throw_strength = 20 * grab_object.mass
				print(throw_strength, " is throw_strength before 55 cap")
				if throw_strength > 55:
					throw_strength = 55
				
				throw_impulse_and_damage(grab_object)
				
				wanna_grab = false
	if Input.is_action_just_released("playerhand|main_throw") or Input.is_action_just_released("playerhand|offhand_throw"):
		wants_to_drop = false


func empty_slot():
	if character.inventory.hotbar != null and not is_instance_valid(character.inventory.hotbar[10]):
		var empty_hand = preload("res://scenes/objects/pickable_items/equipment/empty_slot/_empty_hand.tscn").instance()
		character.inventory.hotbar[10] = empty_hand


func update_throw_state(throw_item : EquipmentItem, delta : float):
	# Place item upright on pointed-at surface or, if no surface in range, simply drop in front of player
	if throw_state == ThrowState.SHOULD_PLACE:
		print("Should place rather than throw item")
		throw_item = character.inventory.get_mainhand_item() if throw_item_hand == ItemSelection.ITEM_MAINHAND else character.inventory.get_offhand_item()
		throw_item.set_item_state(GlobalConsts.ItemState.DROPPED)
		if throw_item:
			# Calculates where to place the item
			var origin : Vector3 = owner.drop_position_node.global_transform.origin
			var end : Vector3 = current_control_mode.get_target_placement_position()
			var dir : Vector3 = end - origin
			dir = dir.normalized() * min(dir.length(), max_placement_distance)
			var layers = throw_item.collision_layer
			var mask = throw_item.collision_mask
			throw_item.collision_layer = throw_item.dropped_layers
			throw_item.collision_mask = throw_item.dropped_mask
			var result = PhysicsTestMotionResult.new()
			# The return value can be ignored, since extra information is put into the 'result' variable
			PhysicsServer.body_test_motion(throw_item.get_rid(), owner.drop_position_node.global_transform, dir, false, result, true)
			throw_item.collision_layer = layers
			throw_item.collision_mask = mask
			if result.motion.length() > 0.1:
				if throw_item_hand == ItemSelection.ITEM_MAINHAND:
					character.inventory.drop_mainhand_item()
				else:
					character.inventory.drop_offhand_item()
				throw_item.call_deferred("global_translate", result.motion)
	
	# Always test Left-Clicking twice with a bomb in main hand after changing anything here. Bomb throws are an edge case of throw as they don't have to happen with the usual throw keys.
	elif throw_state == ThrowState.SHOULD_THROW:
		print("Should throw")
		if throw_item:   # This is a lit bomb that has already set itself as throw_item
			if throw_item == character.inventory.get_mainhand_item():
				throw_item_hand = ItemSelection.ITEM_MAINHAND
			else: 
				throw_item_hand = ItemSelection.ITEM_OFFHAND
		
		if !throw_item:   # If the throw item hasn't already been selected, which should be all cases except use_primary of a lit bomb.
			if throw_item_hand == ItemSelection.ITEM_MAINHAND:
				throw_item = character.inventory.get_mainhand_item()
			else:
				throw_item = character.inventory.get_offhand_item()
				
		# At this point, throw_item_hand is determined, whether this is a throw-button throw or a use_primary bomb throw
		if throw_item:
			throw_item.set_item_state(GlobalConsts.ItemState.DAMAGING)
			if throw_item_hand == ItemSelection.ITEM_MAINHAND:
				character.inventory.drop_mainhand_item()
			else:
				character.inventory.drop_offhand_item()
				
			if throw_item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
				throw_strength = 30 * throw_item.mass
			else:
				throw_strength = 40 * throw_item.mass
			print(throw_strength, " is throw_strength before 55 cap")
			if throw_strength > 55:
				throw_strength = 55
				
			# At this point, the item is still equipped, so we wait until
			# it exits the tree and is re inserted in the world
#			var x_pos = throw_item.global_transform.origin.x
			# Applies unique throw  logic to item if its a melee item
			throw_impulse_and_damage(throw_item)
	
	# throw_state defined here, will this get wiped by the physics_process nulling of throw_item?
	match throw_state:
		ThrowState.IDLE:
			if Input.is_action_just_pressed("playerhand|main_throw") and owner.inventory.get_mainhand_item() and is_grabbing == false and owner.is_reloading == false:
				throw_item_hand = ItemSelection.ITEM_MAINHAND
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
			elif Input.is_action_just_pressed("playerhand|offhand_throw") and owner.inventory.get_offhand_item() and is_grabbing == false and owner.is_reloading == false:
				throw_item_hand = ItemSelection.ITEM_OFFHAND
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
		ThrowState.PRESSING:
			if Input.is_action_pressed("playerhand|main_throw" if throw_item_hand == ItemSelection.ITEM_MAINHAND else "playerhand|offhand_throw"):
				throw_press_length += delta
			else:
				throw_state = ThrowState.SHOULD_PLACE if throw_press_length > hold_time_to_grab else ThrowState.SHOULD_THROW
		ThrowState.SHOULD_PLACE, ThrowState.SHOULD_THROW:
			throw_state = ThrowState.IDLE


func throw_impulse_and_damage(item):
	var impulse = current_control_mode.get_aim_direction() * throw_strength
	
	if item is MeleeItem:
		item.set_item_state(GlobalConsts.ItemState.DAMAGING)
		item.apply_throw_logic()
		item.apply_central_impulse(impulse)
	elif item is EquipmentItem:   # Non-Melee equipment item
		item.set_item_state(GlobalConsts.ItemState.DAMAGING)
		item.apply_central_impulse(impulse)
	elif item is PickableItem:   # It's a tiny item
		item.set_item_state(GlobalConsts.ItemState.DAMAGING)
		item.apply_central_impulse(impulse)
	elif item is RigidBody:   # It's a large object or broken door piece
		item.apply_central_impulse(impulse)
	else:   # It's a static?
		pass
	
	item.add_collision_exception_with(character)
	if item.has_method("play_throw_sound"):
		item.play_throw_sound()


func handle_screen_filters():
	if is_instance_valid(GameManager.game):
		if GameManager.game.current_floor_level == GameManager.game.LOWEST_FLOOR_LEVEL:
			if current_screen_filter != GameManager.ScreenFilter.REDUCE_COLOR and !changed_to_reduce_color:
				_set_screen_filter_to(GameManager.ScreenFilter.NONE)
				_set_screen_filter_to(GameManager.ScreenFilter.REDUCE_COLOR)
				changed_to_reduce_color = true
		# Change the visual filter to change art style of game, such as dither, pixelation, VHS, etc
		if Input.is_action_just_pressed("misc|change_screen_filter"):
			# Cycle to next filter
			_set_screen_filter_to()


# function this out maybe to a screen_filters.gd attached to ScreenFilter
func _set_screen_filter_to(filter_value: int = -1) -> void:
	if filter_value == -1:
		current_screen_filter = posmod(current_screen_filter + 1, GameManager.ScreenFilter.size())
	else:
		current_screen_filter = filter_value
	
	# Check which filter is current and implement it
	if current_screen_filter == GameManager.ScreenFilter.NONE:
		print("Screen Filter: NONE")
#		GameManager.game.level.toggle_directional_light()
		_screen_filter.visible = false
		_debug_light.visible = false
	if current_screen_filter == GameManager.ScreenFilter.OLD_FILM:
		print("Screen Filter: OLD_FILM")
		_screen_filter.visible = true
		_screen_filter.set_surface_material(
				0, preload("res://resources/shaders/old_film/old_film.tres")
		)
	if current_screen_filter == GameManager.ScreenFilter.PIXELATE:
		print("Screen Filter: PIXELATE")
		_screen_filter.visible = true
		_screen_filter.set_surface_material(
				0, preload("res://resources/shaders/pixelate/pixelate.tres")
		)
	if current_screen_filter == GameManager.ScreenFilter.DITHER:
		print("Screen Filter: DITHER")
		_screen_filter.visible = true
		_screen_filter.set_surface_material(
				0, preload("res://resources/shaders/dither/dither.tres")
		)
	if current_screen_filter == GameManager.ScreenFilter.REDUCE_COLOR:
		print("Screen Filter: REDUCE_COLOR")
		_screen_filter.visible = true
		_screen_filter.set_surface_material(
				0, preload("res://resources/shaders/psx/just_color_reduce.tres")
		)
	# We're haven't implemented the mesh shader yet
	if current_screen_filter == GameManager.ScreenFilter.PSX:
		print("Screen Filter: PSX")
		_screen_filter.visible = true
		_screen_filter.set_surface_material(
				0, preload("res://resources/shaders/psx/psx_material.tres")
		)
	if current_screen_filter == GameManager.ScreenFilter.DEBUG_LIGHT:
		print("Screen Filter: DEBUG_LIGHT")
#		GameManager.game.level.toggle_directional_light()   # At one point, this lagged everything
		_screen_filter.visible = false
		_debug_light.visible = true


func handle_binocs():
	# Zoom in/out like binoculars or spyglass
	if Input.is_action_just_pressed("ablty|binocs_spyglass"):
		if character.inventory.tiny_items.has(load("res://resources/tiny_items/spyglass.tres")):
			_camera.state = _camera.CameraState.STATE_ZOOM
	if Input.is_action_just_released("ablty|binocs_spyglass"):
		if character.inventory.tiny_items.has(load("res://resources/tiny_items/spyglass.tres")):
			_camera.state = _camera.CameraState.STATE_NORMAL


func _clamber():
	pass
# TODO: FIX CLAMBERING RIGID BODIES (possibly involving switching player to a RigidBody rather than Kinematic) THEN RENABLE HERE, Issue #419
#	var c = _clamber_m.attempt_clamber(owner.is_crouching, owner.is_jumping)
#	if c != Vector3.ZERO:
#		_text.show()
#	else:
#		_text.hide()


func _on_Player_player_landed():
	if !owner.is_crouching:
		if owner.noise_level < 8 + (character.inventory.encumbrance):
			owner.noise_level = 8 + (character.inventory.encumbrance)
			noise_timer.start()
	else:
		if owner.noise_level < 5 + (character.inventory.encumbrance):
			owner.noise_level = 5 + (character.inventory.encumbrance)
			noise_timer.start()


func _on_NoiseTimer_timeout():
	# The only reset of noise_level - should probably go in character
	# This is here instead of _process because instant sounds like jump won't get caught by sensors otherwise
	owner.noise_level = 0
