extends Node


signal is_moving(is_player_moving)

var is_player_moving : bool = false

onready var character = get_parent()
export var max_placement_distance = 1.5
export var hold_time_to_place = 0.4
export var throw_strength : float = 2

export var hold_time_to_grab : float = 0.4
export var grab_strength : float = 2.0
export var kick_impulse : float = 100
#export var grab_spring_distance : float = 0.1
#export var grab_damping : float = 0.2

## Determines the real world directions each movement key corresponds to.
## By default, Right corresponds to +X, Left to -X, Up to -Z and Down to +Z
var movement_basis : Basis = Basis.IDENTITY
var interaction_target : Node = null
var target_placement_position : Vector3 = Vector3.ZERO

export var _grabcast : NodePath
onready var grabcast : RayCast = get_node(_grabcast) as RayCast

export var _aimcast : NodePath
onready var aimcast : RayCast = get_node(_aimcast) as RayCast

export var _legcast : NodePath
onready var legcast : RayCast = get_node(_legcast) as RayCast

export(AttackTypes.Types) var kick_damage_type : int = 0

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

export(float, 0.05, 1.0) var crouch_rate = 0.08
export(float, 0.1, 1.0) var crawl_rate = 0.5
export var move_drag : float = 0.2
export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export var interact_distance : float = 0.75
export var lock_mouse : bool = true
export var head_bob_enabled : bool = true

var velocity : Vector3 = Vector3.ZERO
var _bob_time : float = 0.0
var _clamber_m = null
var _bob_reset : float = 0.0

export var _cam_path : NodePath
onready var _camera : ShakeCamera = get_node(_cam_path)
export var _gun_cam_path : NodePath
onready var _gun_cam = get_node(_gun_cam_path)
onready var _frob_raycast = get_node("../FPSCamera/GrabCast")
onready var _text = get_node("..//Indication_canvas/Label")
onready var _player_hitbox = get_node("../CanStandChecker")
onready var _ground_checker = get_node("../Body/GroundChecker")

var _camera_orig_pos : Vector3
var _camera_orig_rotation : Vector3

var throw_state : int = ThrowState.IDLE
var throw_item : int = ItemSelection.ITEM_MAINHAND
var throw_press_length : float = 0.0
var active_mode_index = 0
onready var active_mode : ControlMode = get_child(0)

var grab_press_length : float = 0.0
var wanna_grab : bool = false
var is_grabbing : bool = false
var interaction_handled : bool = false
var grab_object : RigidBody = null
var grab_relative_object_position : Vector3
var grab_distance : float = 0
var target
var current_object = null
var wants_to_drop = false
var _click_timer : float = 0.0
var _throw_wait_time : float = 400
var drag_object : RigidBody = null

var is_movement_key1_held = false
var is_movement_key2_held = false
var is_movement_key3_held = false
var is_movement_key4_held = false
var movement_press_length = 0
var crouch_target_pos = -0.55
var crouch_cam_target_pos = 0.98
var clamberable_obj : RigidBody
var item_up = false

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
var current_screen_filter : int = ScreenFilter.NONE
#export var pixelated_material : Material
#export var dither_material : Material
#export var reduce_color_material : Material

onready var noise_timer = $"../Audio/NoiseTimer"


func _ready():
	owner.is_to_move = false
	_bob_reset = _camera.global_transform.origin.y - owner.global_transform.origin.y
	_clamber_m = ClamberManager.new(owner, _camera, owner.get_world())
	_camera_orig_pos = _camera.transform.origin
	_camera_orig_rotation = _camera.rotation_degrees
	
	active_mode.set_deferred("is_active", true)
	
	$"../FPSCamera/ScreenFilter".visible = false


func _physics_process(delta : float):
	_camera.rotation_degrees = _camera_orig_rotation

	active_mode.update(delta)   # added delta when doing programming recoil
	movement_basis = active_mode.get_movement_basis()
	interaction_target = active_mode.get_interaction_target()
	character.character_state.interaction_target = interaction_target
	interaction_handled = false
	current_object = active_mode.get_grab_target()
	_walk(delta)
	_crouch()
	handle_grab_input(delta)
	handle_grab(delta)
	handle_inventory(delta)
	next_item()
	previous_item()
	drop_grabbable()
	empty_slot()
	kick()

	var c = _clamber_m.attempt_clamber(owner.is_crouching, owner.is_jumping)
	if c != Vector3.ZERO:
		_text.show()
	else:
		_text.hide()

	if owner.wanna_stand:
		var from = _camera.transform.origin.y
		_camera.transform.origin.y = lerp(from, _camera_orig_pos.y, 0.08)
		var d1 = _camera.transform.origin.y - _camera_orig_pos.y
		if d1 > -0.02:
			_camera.transform.origin.y = _camera_orig_pos.y
			owner.is_crouching = false
			owner.wanna_stand = false


func _input(event):
	if event is InputEventMouseButton and owner.is_reloading == false:
		if event.pressed:
			match event.button_index:
				BUTTON_WHEEL_UP:
					item_up = true
					owner.change_equipment_out(true)
					yield(owner, "change_main_equipment_out_done")

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
								if plus_inventory != -1  :
									character.inventory.current_mainhand_slot = plus_inventory
								else:
									character.inventory.current_mainhand_slot = 10
						elif character.inventory.current_mainhand_slot == 0:
							character.inventory.current_mainhand_slot = 10

						owner.change_equipment_in(true)

				BUTTON_WHEEL_DOWN:
					item_up = false
					owner.change_equipment_out(true)
					yield(owner, "change_main_equipment_out_done")

					if !item_up:
						if character.inventory.current_mainhand_slot != 10 :
							var total_inventory
							if  character.inventory.bulky_equipment:
								total_inventory = 0
							else:
								total_inventory = character.inventory.current_mainhand_slot + 1
							if total_inventory != character.inventory.current_offhand_slot :
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

						owner.change_equipment_in(true)

	if event is InputEventMouseMotion:
		if (owner.state == owner.State.STATE_CLAMBERING_LEDGE
			or owner.state == owner.State.STATE_CLAMBERING_RISE
			or owner.state == owner.State.STATE_CLAMBERING_VENT):
			return

		var m = 1.0

		if _camera.state == _camera.CameraState.STATE_ZOOM:
			m = _camera.zoom_camera_sens_mod

		owner.rotation_degrees.y -= event.relative.x * GlobalSettings.mouse_sensitivity * m

#		if owner.state != owner.State.STATE_CRAWLING:
#			_camera.rotation_degrees.x -= event.relative.y * GlobalSettings.mouse_sensitivity * m
#			_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -90, 90)

		_camera._camera_rotation_reset = _camera.rotation_degrees


func _walk(delta) -> void:
	if Input.is_action_just_pressed("move_right"):
		is_movement_key1_held = true
	if Input.is_action_just_pressed("move_left"):
		is_movement_key2_held = true
	if Input.is_action_just_pressed("move_down"):
		is_movement_key3_held = true
	if Input.is_action_just_pressed("move_up"):
		is_movement_key4_held = true
		owner.is_moving_forward = true
	
	_check_movement_key(delta)

	var move_dir = Vector3()
	move_dir.x = (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	move_dir.z = (Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	character.character_state.move_direction = move_dir.normalized()

	if Input.is_action_pressed("sprint"):
		owner.do_sprint = true
	else:
		owner.do_sprint = false
	HUDS.tired(owner.stamina)
	# Lower the stamina, higher the noise, from 1 to 7 given 600 stamina
	# This does make noise_level a float not an int and is the only place this happens as of 6/11/2023
	owner.noise_level = 7 - owner.stamina * 0.01   # It's 7 so extremely acute hearing can hear you breathe at rest

	if Input.is_action_just_released("move_right"):
		is_movement_key1_held = false
	if Input.is_action_just_released("move_left"):
		is_movement_key2_held = false
	if Input.is_action_just_released("move_down"):
		is_movement_key3_held = false
	if Input.is_action_just_released("move_up"):
		is_movement_key4_held = false
		owner.is_moving_forward = false
	
	_check_movement_key(delta)

	if Input.is_action_just_pressed("jump"):
		owner.do_jump = true

	if head_bob_enabled and owner.grounded and owner.state == owner.State.STATE_WALKING:
		_head_bob(delta)


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


func _head_bob(delta : float) -> void:
	if owner.velocity.length() == 0.0:
		var br = Vector3(0, _bob_reset, 0)
		_camera.global_transform.origin = owner.global_transform.origin + br

	_bob_time += delta
	var y_bob = sin(_bob_time * (2 * PI)) * owner.velocity.length() * (0.5 / 1000.0)
	_camera.global_transform.origin.y += y_bob

	# Removed since it's not good to do head rotation unless take camera control away from player (simulation sickness)
#	var z_bob = sin(_bob_time * (PI)) * owner.velocity.length() * 0.2
#	_camera.rotation_degrees.z = z_bob


func _crouch() -> void:
	if owner.is_player_crouch_toggle:
		if owner.do_sprint:
			owner.do_crouch = false
			return

		if Input.is_action_just_pressed("crouch"):
			owner.do_crouch = !owner.do_crouch
			if owner.do_crouch:
				owner.state = owner.State.STATE_CROUCHING

		if owner.do_crouch:
			var from = _camera.transform.origin.y
			_camera.transform.origin.y = lerp(from, crouch_cam_target_pos, 0.08)

	else:
		if Input.is_action_pressed("crouch"):
			if owner.do_sprint:
				owner.do_crouch = false
				return

			owner.do_crouch = true
			owner.state = owner.State.STATE_CROUCHING

			var from = _camera.transform.origin.y
			_camera.transform.origin.y = lerp(from, crouch_cam_target_pos, 0.08)

		if !Input.is_action_pressed("crouch"):
			owner.do_crouch = false


func handle_grab_input(delta : float):
	if is_grabbing:
		wanna_grab = true
	else:
		wanna_grab = false
	if Input.is_action_pressed("interact") or Input.is_action_pressed("main_use_secondary") and is_grabbing == false:
		grab_press_length += delta
		if grab_press_length >= 0.15 :
			wanna_grab = true
			interaction_handled = true

	if Input.is_action_just_released("interact") or Input.is_action_just_released("main_use_secondary") :
		grab_press_length = 0.0
		if is_grabbing == true:
			is_grabbing = false
			wanna_grab = false
			interaction_handled = true


func handle_grab(delta : float):
	if wants_to_drop == false :
		if wanna_grab and not is_grabbing:

			var object = active_mode.get_grab_target()

			if object:
				var grab_position = active_mode.get_grab_global_position()
				grab_relative_object_position = object.to_local(grab_position)
				grab_distance = owner.fps_camera.global_transform.origin.distance_to(grab_position)
				grab_object = object
				is_grabbing = true

	# These are debug indicators for initial and current grab points
	$MeshInstance.visible = false
	$MeshInstance2.visible = false

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

		# Some debug visualization stuff for grabbing
		$MeshInstance.global_transform.origin = grab_target_global
		$MeshInstance2.global_transform.origin = grab_object_global
		if $MeshInstance.global_transform.origin.distance_to($MeshInstance2.global_transform.origin) >= 1.0 and !grab_object is PickableItem:
			is_grabbing = false
			interaction_handled = true
		
		# Local velocity of the object at the grabbing point, used to cancel the objects movement
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
		direct_state.apply_torque_impulse(0.2 * (grab_object_offset.cross(total_impulse)))

		# Limits the angular velocity to prevent some issues
		direct_state.angular_velocity = direct_state.angular_velocity.normalized() * min(direct_state.angular_velocity.length(), 4.0)


func update_throw_state(delta : float):
	match throw_state:
		ThrowState.IDLE:
			if Input.is_action_just_pressed("main_throw") and owner.inventory.get_mainhand_item() and is_grabbing == false and owner.is_reloading == false:
				throw_item = ItemSelection.ITEM_MAINHAND
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
			elif Input.is_action_just_pressed("offhand_throw") and owner.inventory.get_offhand_item() and is_grabbing == false and owner.is_reloading == false:
				throw_item = ItemSelection.ITEM_OFFHAND
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
		ThrowState.PRESSING:
			if Input.is_action_pressed("main_throw" if throw_item == ItemSelection.ITEM_MAINHAND else "offhand_throw"):
				throw_press_length += delta
			else:
				throw_state = ThrowState.SHOULD_PLACE if throw_press_length > hold_time_to_grab else ThrowState.SHOULD_THROW
		ThrowState.SHOULD_PLACE, ThrowState.SHOULD_THROW:
			throw_state = ThrowState.IDLE


func empty_slot():
	if character.inventory.hotbar != null and not is_instance_valid(character.inventory.hotbar[10]):
		var empty_hand = preload("res://scenes/objects/pickable_items/equipment/empty_slot/_empty_hand.tscn").instance()
		character.inventory.hotbar[10] = empty_hand


func throw_consumable(item):
#	var item : EquipmentItem = null
	if throw_item == ItemSelection.ITEM_MAINHAND:
#		item = character.inventory.get_mainhand_item()
		character.inventory.drop_mainhand_item()
	else:
#		item = character.inventory.get_offhand_item()
		character.inventory.drop_offhand_item()
	if item:
		var impulse = active_mode.get_aim_direction() * throw_strength
		# At this point, the item is still equipped, so we wait until
		# it exits the tree and is re inserted in the world
		item.apply_central_impulse(impulse)


func handle_inventory(delta : float):
	# Main-hand slot selection
	for i in range(character.inventory.HOTBAR_SIZE):
		# hotbar_%d is a nasty hack which prevents renaming hotbar_11 to holster_offhand in Input Map
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]) and owner.is_reloading == false:
			# Don't select current offhand slot and don't select 10 because it's hotbar_11, used for holstering offhand item, below
			if i != character.inventory.current_offhand_slot and i != 10:
				owner.change_equipment_out(true)
				yield(owner, "change_main_equipment_out_done")
				character.inventory.current_mainhand_slot = i
				throw_state = ThrowState.IDLE
				owner.change_equipment_in(true)

	# Off-hand slot selection
	if Input.is_action_just_pressed("cycle_offhand_slot") and owner.is_reloading == false:
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
			owner.change_equipment_out(false)
			yield(owner, "change_off_equipment_out_done")
			character.inventory.current_offhand_slot = new_slot
			print("Offhand slot cycled to ", new_slot)
			throw_state = ThrowState.IDLE
			owner.change_equipment_in(false)

	if Input.is_action_just_pressed("hotbar_11"):
		if character.inventory.current_offhand_slot != 10:
			character.inventory.current_offhand_slot = 10

	# Item Usage
	# temporary hack (issue #409)
	if is_instance_valid(character.inventory.get_mainhand_item()):
		
#		# Recoil
#		if inv.get_mainhand_item() is GunItem and !inv.get_mainhand_item().on_cooldown:
#			active_mode.up_recoil = 0
#		if inv.get_offhand_item() is GunItem and !inv.get_offhand_item().on_cooldown:
#			active_mode.up_recoil = 0
			
		if Input.is_action_just_pressed("main_use_primary"):
			if character.inventory.get_mainhand_item():
				character.inventory.get_mainhand_item().use_primary()
				throw_state = ThrowState.IDLE

		if Input.is_action_just_pressed("main_use_secondary"):
			# This means R-Click can be used to interact when pointing at an interactable
			if character.inventory.get_mainhand_item() and interaction_target == null:
				character.inventory.get_mainhand_item().use_secondary()
				throw_state = ThrowState.IDLE

		if Input.is_action_just_pressed("reload"):
			if character.inventory.get_mainhand_item():
				character.inventory.get_mainhand_item().use_reload()
				throw_state = ThrowState.IDLE

	if Input.is_action_just_pressed("offhand_use"):
		if character.inventory.get_offhand_item():
			character.inventory.get_offhand_item().use_primary()
			throw_state = ThrowState.IDLE

	# Change the visual filter to change art style of game, such as dither, pixelation, VHS, etc
	if Input.is_action_just_pressed("change_screen_filter"):
		# Cycle to next filter
		current_screen_filter += 1

		# Cycle through list of filters, starting with 0
		if current_screen_filter > (ScreenFilter.size() - 1):
				current_screen_filter = 0

		# Check which filter is current and implement it
		if current_screen_filter == ScreenFilter.NONE:
			print("Screen Flter: NONE")
#			GameManager.game.level.toggle_directional_light()
			$"../FPSCamera/ScreenFilter".visible = false
			$"../FPSCamera/DebugLight".visible = false
		if current_screen_filter == ScreenFilter.OLD_FILM:
			print("Screen Flter: OLD_FILM")
			$"../FPSCamera/ScreenFilter".visible = true
			$"../FPSCamera/ScreenFilter".set_surface_material(0, preload("res://resources/shaders/old_film/old_film.tres"))
		if current_screen_filter == ScreenFilter.PIXELATE:
			print("Screen Flter: PIXELATE")
			$"../FPSCamera/ScreenFilter".visible = true
			$"../FPSCamera/ScreenFilter".set_surface_material(0, preload("res://resources/shaders/pixelate/pixelate.tres"))
		if current_screen_filter == ScreenFilter.DITHER:
			print("Screen Flter: DITHER")
			$"../FPSCamera/ScreenFilter".visible = true
			$"../FPSCamera/ScreenFilter".set_surface_material(0, preload("res://resources/shaders/dither/dither.tres"))
		if current_screen_filter == ScreenFilter.REDUCE_COLOR:
			print("Screen Flter: REDUCE_COLOR")
			$"../FPSCamera/ScreenFilter".visible = true
			$"../FPSCamera/ScreenFilter".set_surface_material(0, preload("res://resources/shaders/reduce_color/reduce_color.tres"))
		# This one doesn't play well with stuff that's too dark, also we're not implementing the mesh shader yet
		if current_screen_filter == ScreenFilter.PSX:
			print("Screen Flter: PSX")
			$"../FPSCamera/ScreenFilter".visible = true
			$"../FPSCamera/ScreenFilter".set_surface_material(0, preload("res://resources/shaders/psx/psx_material.tres"))
		if current_screen_filter == ScreenFilter.DEBUG_LIGHT:
			print("Screen Flter: DEBUG_LIGHT")
#			GameManager.game.level.toggle_directional_light()
			$"../FPSCamera/ScreenFilter".visible = false
			$"../FPSCamera/DebugLight".visible = true

	# Zoom in/out like binoculars or spyglass
	if character.inventory.tiny_items.has(load("res://resources/tiny_items/spyglass.tres")):
		if Input.is_action_just_pressed("binocs_spyglass"):
			_camera.state = _camera.CameraState.STATE_ZOOM
		if Input.is_action_just_released("binocs_spyglass"):
			_camera.state = _camera.CameraState.STATE_NORMAL
		
	if throw_state == ThrowState.SHOULD_PLACE:
		var item : EquipmentItem = character.inventory.get_mainhand_item() if throw_item == ItemSelection.ITEM_MAINHAND else character.inventory.get_offhand_item()
		if item:
			# Calculates where to place the item
			var origin : Vector3 = owner.drop_position_node.global_transform.origin
			var end : Vector3 = active_mode.get_target_placement_position()
			var dir : Vector3 = end - origin
			dir = dir.normalized() * min(dir.length(), max_placement_distance)
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
				if throw_item == ItemSelection.ITEM_MAINHAND:
					character.inventory.drop_mainhand_item()
				else:
					character.inventory.drop_offhand_item()
				item.call_deferred("global_translate", result.motion)

	elif throw_state == ThrowState.SHOULD_THROW:
		var item : EquipmentItem = null
		if throw_item == ItemSelection.ITEM_MAINHAND:
			item = character.inventory.get_mainhand_item()
			character.inventory.drop_mainhand_item()
		else:
			item = character.inventory.get_offhand_item()
			character.inventory.drop_offhand_item()
		if item:
			var impulse = active_mode.get_aim_direction()*throw_strength
			# At this point, the item is still equipped, so we wait until
			# it exits the tree and is re inserted in the world
			var x_pos = item.global_transform.origin.x
			#Applies unique throw  logic to item if its a melee item
			if item is MeleeItem :
				item.apply_throw_logic(impulse)
			else:
				item.apply_central_impulse(impulse)

	update_throw_state(delta)

	if Input.is_action_just_released("interact") or Input.is_action_just_released("main_use_secondary") and not (wanna_grab or is_grabbing or interaction_handled):
		if interaction_target != null:
			if interaction_target is PickableItem:   # and character.inventory.current_mainhand_slot != 10:
				character.inventory.add_item(interaction_target)
				interaction_target = null
			elif interaction_target is Interactable:
				interaction_target.interact(owner)


func kick():
	var kick_object = legcast.get_collider()
	
	if character.kick_timer.is_stopped():
		
		if legcast.is_colliding() and kick_object.is_in_group("Door_hitbox"):
			if is_grabbing == false:
				if Input.is_action_just_pressed("kick"):
					kick_object.get_parent().damage(-character.global_transform.basis.z , character.kick_damage)
					character.kick_timer.start(1)
		
		elif legcast.is_colliding() and kick_object.is_in_group("CHARACTER"):
			if Input.is_action_just_pressed("kick"):
				kick_object.get_parent().damage(character.kick_damage , kick_damage_type , kick_object)
				character.kick_timer.start(1)
		
		elif legcast.is_colliding() and (kick_object is RigidBody or kick_object.is_in_group("IGNITE")):
			if Input.is_action_just_pressed("kick"):
				if kick_object is Area:
					kick_object = kick_object.get_parent()   # You just kicked the IGNITE area
				kick_object.apply_central_impulse(-character.global_transform.basis.z * kick_impulse)
				character.kick_timer.start(1)


func drop_grabbable():
	# When the drop button or keys are pressed , grabable objects are released
	if Input.is_action_just_pressed("main_throw") or Input.is_action_just_pressed("offhand_throw") and is_grabbing == true:
		wants_to_drop = true
		if grab_object != null :
			is_grabbing = false
			interaction_handled = true
			var impulse = active_mode.get_aim_direction() * throw_strength
			wanna_grab = false
			grab_object.apply_central_impulse(impulse)
	if Input.is_action_just_released("main_throw") or Input.is_action_just_released("offhand_throw"):
		wants_to_drop = false


func previous_item():
	if Input.is_action_just_pressed("previous_item") and character.inventory.current_mainhand_slot != 0:
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot -=1

	elif  Input.is_action_just_pressed("previous_item") and character.inventory.current_mainhand_slot == 0:
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot = 10


func next_item():
	if Input.is_action_just_pressed("next_item") and character.inventory.current_mainhand_slot != 10:
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot += 1

	elif  Input.is_action_just_pressed("next_item") and character.inventory.current_mainhand_slot == 10:
		character.inventory.drop_bulky_item()
		character.inventory.current_mainhand_slot = 0


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
