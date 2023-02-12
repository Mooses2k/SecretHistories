extends Node


signal is_moving(is_player_moving)

var is_player_moving : bool = false

onready var character = get_parent()
export var max_placement_distance = 1.5
export var hold_time_to_place = 0.4
export var throw_strength : float = 2

export var hold_time_to_grab : float = 0.4
export var grab_strength : float = 2.0
export var kick_impulse : float = 20
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

#export var Player_path : NodePath
#onready var player = get_node(Player_path)

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

export var speed : float = 0.5
export(float, 0.05, 1.0) var crouch_rate = 0.08
export(float, 0.1, 1.0) var crawl_rate = 0.5
export var move_drag : float = 0.2
export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export var interact_distance : float = 0.75
#export var mouse_sens : float = 0.5   # duplicates GlobalSettings.mouse_sensitivity and caused a bug
export var lock_mouse : bool = true
export var head_bob_enabled : bool = true

var light_level : float = 0.0
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
onready var _player_hitbox = get_node("../PlayerStandChecker")
onready var _ground_checker = get_node("../Body/GroundChecker")

var _camera_orig_pos : Vector3
var _camera_orig_rotation : Vector3
#stealth player controller addon -->

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


func _ready():
	owner.is_to_move = false
	_bob_reset = _camera.global_transform.origin.y - owner.global_transform.origin.y
	_clamber_m = ClamberManager.new(owner, _camera, owner.get_world())
	_camera_orig_pos = _camera.transform.origin
	_camera_orig_rotation = _camera.rotation_degrees

	active_mode.set_deferred("is_active", true)


func _physics_process(delta : float):
	_camera.rotation_degrees = _camera_orig_rotation
	owner.noise_level = 0

	active_mode.update()
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
#	_process_frob_and_drag()
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
	if event is InputEventMouseButton and GameManager.is_reloading == false :
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
#		owner.body.rotation_degrees.y -= event.relative.x * mouse_sens * m

		if owner.state != owner.State.STATE_CRAWLING:
			_camera.rotation_degrees.x -= event.relative.y * GlobalSettings.mouse_sensitivity * m
			_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -90, 90)

		_camera._camera_rotation_reset = _camera.rotation_degrees

		#character.inventory.current_mainhand_slot = 1


func _on_player_landed():
	if !owner.is_crouching:
		owner.noise_level = 8
	else:
		owner.noise_level = 3


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

#	if Input.is_action_pressed("movement"):
##		print("movement pressed")
#		movement_press_length += delta
#		if movement_press_length >= 0.15:
#			owner.is_to_move = true
#			if !owner.is_crouching:
#				player_noise_value = 5

	var move_dir = Vector3()
	move_dir.x = (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	move_dir.z = (Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	character.character_state.move_direction = move_dir.normalized()
	if Input.is_action_pressed("sprint"):
		owner.do_sprint = true
	else:
		owner.do_sprint = false
	HUDS.tired(owner.stamina);

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

#	if owner.is_on_floor() and _jumping and _camera.stress < 0.1:
#		_audio_player.play_land_sound()
##		_camera.add_stress(0.25)

	if Input.is_action_just_pressed("clamber"):
		owner.do_jump = true

	if head_bob_enabled and owner.grounded and owner.state == owner.State.STATE_WALKING:
		_head_bob(delta)


func _check_movement_key(delta):
	if is_movement_key1_held or is_movement_key2_held or is_movement_key3_held or is_movement_key4_held:
		movement_press_length += delta
		if movement_press_length >= 0.25:
			owner.is_to_move = true
			if !owner.is_crouching:
				if owner.do_sprint:
					owner.noise_level = 8
				else:
					owner.noise_level = 5
			else:
				owner.noise_level = 3
	
	if !is_movement_key1_held and !is_movement_key2_held and !is_movement_key3_held and !is_movement_key4_held:
		movement_press_length = 0.0
		owner.is_to_move = false
		



func _head_bob(delta : float) -> void:
	if owner.velocity.length() == 0.0:
		var br = Vector3(0, _bob_reset, 0)
		_camera.global_transform.origin = owner.global_transform.origin + br

	_bob_time += delta
	var y_bob = sin(_bob_time * (2 * PI)) * owner.velocity.length() * (speed / 1000.0)
	var z_bob = sin(_bob_time * (PI)) * owner.velocity.length() * 0.2
	_camera.global_transform.origin.y += y_bob
	_camera.rotation_degrees.z = z_bob


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


#func _lean() -> void:
#	var axis = (Input.get_action_strength("right") - Input.get_action_strength("left"))
#
#	var from = _camera.global_transform.origin
#	var to = _camera_pos_normal + (_camera.global_transform.basis.x * 0.2 * axis)
#	_camera.global_transform.origin = lerp(from, to, 0.1)
#
#	from = _camera.rotation_degrees.z
#	to = max_lean * axis
#	_camera.rotation_degrees.z = lerp(from, to, 0.1)
#
#	var diff = _camera.global_transform.origin - _camera_pos_normal
#	if axis == 0 and diff.length() <= 0.01:
#		state = State.STATE_WALKING
#		return


#func _process_frob_and_drag():
#	if (Input.is_action_just_pressed("main_use_primary")
#		and _click_timer == 0.0
#		and drag_object != null):
#		_click_timer = OS.get_ticks_msec()
#
#	if Input.is_action_pressed("main_use_primary"):
#		if _click_timer + _throw_wait_time < OS.get_ticks_msec():
#			if _click_timer == 0.0:
#				return
#
##			_camera.set_crosshair_state("normal")
#			_click_timer = 0.0
#			_throw()
#			drag_object = null
#
#	if _frob_raycast.is_colliding():
#		var c = _frob_raycast.get_collider()
#		if drag_object == null and c is RigidBody:
#			if c.scale > (Vector3.ONE * 5):
#				return
#
#			var w = owner.get_world().direct_space_state
#			var r = w.intersect_ray(c.global_transform.origin,
#					c.global_transform.origin + Vector3.UP * 0.5, [owner])
#
#			if r and r.collider == owner:
#				return
#
##			_camera.set_crosshair_state("interact")
#
#			if Input.is_action_just_released("main_use_primary"):
##				_camera.set_crosshair_state("dragging")
#				drag_object = c
#				drag_object.linear_velocity = Vector3.ZERO
#
#	if Input.is_action_just_released("main_use_primary"):
#		if drag_object != null:
#			if _click_timer + _throw_wait_time > OS.get_ticks_msec():
#				if _click_timer == 0.0:
#					return
#
##				_camera.set_crosshair_state("normal")
#				drag_object = null
#				_click_timer = 0.0
#
#	if Input.is_action_just_pressed("main_use_secondary") and drag_object != null:
#		drag_object.rotation_degrees.y += 45
#		drag_object.rotation_degrees.x = 90
#
#	if drag_object:
#		_drag()
#
#		var d = _camera.global_transform.origin.distance_to(drag_object.global_transform.origin)
#		if  d > interact_distance + 0.35:
#			drag_object = null
#
##	if !drag_object and not _frob_raycast.is_colliding():
##		_camera.set_crosshair_state("normal")
#
#
#func _drag(damping : float = 0.5, s2ms : int = 15) -> void:
#	var d = _frob_raycast.global_transform.basis.z.normalized()
#	var dest = _frob_raycast.global_transform.origin - d * interact_distance
#	var d1 = (dest - drag_object.global_transform.origin)
#	drag_object.angular_velocity = Vector3.ZERO
#
#	var v1 = velocity * damping + drag_object.linear_velocity * damping
#	var v2 = (d1 * s2ms) * (1.0 - damping) / drag_object.mass
#
#	drag_object.linear_velocity = v1 + v2
#
#
#func _throw(throw_force : float = 10.0) -> void:
#	var d = -_camera.global_transform.basis.z.normalized()
#	drag_object.apply_central_impulse(d * throw_force)
#	_camera.add_stress(0.2)


#func handle_misc_controls(_delta : float):
#	if Input.is_action_just_pressed("toggle_perspective"):
#		active_mode_index = (active_mode_index + 1)%get_child_count()
#		active_mode.is_active = false
#		active_mode = get_child(active_mode_index)
#		active_mode.is_active = true


#func handle_movement(_delta : float):
#	var direction : Vector3 = Vector3.ZERO
#	direction.x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
#	direction.z += Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
#	direction = movement_basis.xform(direction)
#	direction = direction.normalized()*min(1.0, direction.length())
#
#	if Input.is_action_pressed("sprint") and stamina > 0 and GameManager.is_reloading==false:
#		direction *= 0.5;
#		change_stamina(-0.3)
#	else:
#		direction *= 0.2;
#		if !Input.is_action_pressed("sprint"):
#			change_stamina(0.3)
##	print(stamina)
#
#	character.character_state.move_direction = direction
#
#	if direction == Vector3.ZERO:
#		is_player_moving = false
#		emit_signal("is_moving", is_player_moving)
#	else:
#		is_player_moving = true
#		emit_signal("is_moving", is_player_moving)


func handle_grab_input(delta : float):
	if is_grabbing:
		wanna_grab = true
	else:
		wanna_grab = false
	if Input.is_action_pressed("interact") and is_grabbing == false:
		grab_press_length += delta
		if grab_press_length >= 0.15 :
			wanna_grab = true
			interaction_handled = true
#	else:
#		wanna_grab = false
#		if Input.is_action_just_released("interact") and grab_press_length >= hold_time_to_grab:
#		if Input.is_action_just_released("interact") :
#			wanna_grab = true
#			interaction_handled = true

#	else:
#		wanna_grab = false
#		if Input.is_action_just_released("interact") and grab_press_length >= hold_time_to_grab:
#		if Input.is_action_just_released("interact") :
#			wanna_grab = true
#			interaction_handled = true

#		grab_press_length = 0.0
	if Input.is_action_just_released("interact"):
		grab_press_length = 0.0
		if is_grabbing==true:
			if grab_object.has_method("dragging"):
				print("stop")
				grab_object.audio_player.stop()
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

		# Some visualization stuff
		$MeshInstance.global_transform.origin = grab_target_global
		$MeshInstance2.global_transform.origin = grab_object_global
		if $MeshInstance.global_transform.origin.distance_to($MeshInstance2.global_transform.origin) >= 1.0 and !grab_object is PickableItem:
			is_grabbing = false
			interaction_handled = true
		#local velocity of the object at the grabbing point, used to cancel the objects movement
		var local_velocity : Vector3 = direct_state.get_velocity_at_local_position(grab_object_local)

		# Desired velocity scales with distance to target, to a maximum of 2.0 m/s
		var desired_velocity : Vector3 = 32.0*(grab_target_global - grab_object_global)
		desired_velocity = desired_velocity.normalized()*min(desired_velocity.length(), 2.0)

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
		direct_state.angular_velocity = direct_state.angular_velocity.normalized()*min(direct_state.angular_velocity.length(), 4.0)
		
		grab_object.dragging()


func update_throw_state(delta : float):
	match throw_state:
		ThrowState.IDLE:
			if Input.is_action_just_pressed("main_throw") and owner.inventory.get_mainhand_item() and is_grabbing == false and GameManager.is_reloading == false:
				throw_item = ItemSelection.ITEM_MAINHAND
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
			elif Input.is_action_just_pressed("offhand_throw") and owner.inventory.get_offhand_item() and is_grabbing == false  and GameManager.is_reloading == false:
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
	pass


func empty_slot():
	var inv = character.inventory
	if inv.hotbar != null:
		var gun = preload("res://scenes/objects/pickable_items/equipment/empty_slot/_empty_hand.tscn").instance()
		if  !inv.hotbar.has(10):
			inv.hotbar[10] = gun


func throw_consumable():
		var inv = character.inventory
		var item : EquipmentItem = null
		if throw_item == ItemSelection.ITEM_MAINHAND:
			item = inv.get_mainhand_item()
			inv.drop_mainhand_item()
		else:
			item = inv.get_offhand_item()
			inv.drop_offhand_item()
		if item:
			var impulse = active_mode.get_aim_direction()*throw_strength
			# At this point, the item is still equipped, so we wait until
			# it exits the tree and is re inserted in the world
			item.apply_central_impulse(impulse)


func handle_inventory(delta : float):
	var inv = character.inventory

	# Main-hand slot selection
	for i in range(character.inventory.HOTBAR_SIZE):
		# hotbar_%d is a nasty hack which prevents renaming hotbar_11 to holster_offhand in Input Map
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]) and GameManager.is_reloading == false  :
			if i != inv.current_offhand_slot :
				owner.change_equipment_out(true)
				yield(owner, "change_main_equipment_out_done")
				inv.current_mainhand_slot = i
				throw_state = ThrowState.IDLE
				owner.change_equipment_in(true)

	# Offhand slot selection

	if Input.is_action_just_pressed("cycle_offhand_slot") and GameManager.is_reloading == false:
		var start_slot = inv.current_offhand_slot
		var new_slot = (start_slot + 1)%inv.hotbar.size()
		while new_slot != start_slot \
			and (
					(

						inv.hotbar[new_slot] != null \
						and inv.hotbar[new_slot].item_size != GlobalConsts.ItemSize.SIZE_SMALL\
					)\
					or new_slot == inv.current_mainhand_slot \
					or inv.hotbar[new_slot] == null \
				):

				new_slot = (new_slot + 1)%inv.hotbar.size()
		if start_slot != new_slot:
			owner.change_equipment_out(false)
			yield(owner, "change_off_equipment_out_done")
			inv.current_offhand_slot = new_slot
			print("Offhand slot cycled to ", new_slot)
			throw_state = ThrowState.IDLE
			owner.change_equipment_in(false)

	if Input.is_action_just_pressed("hotbar_11"):
		if inv.current_offhand_slot != 10:
			inv.current_offhand_slot = 10
	## Item Usage
	if Input.is_action_just_pressed("main_use_primary"):
		if inv.get_mainhand_item():
			inv.get_mainhand_item().use_primary()
			throw_state = ThrowState.IDLE

	if Input.is_action_just_pressed("main_use_secondary"):
		if inv.get_mainhand_item():
			inv.get_mainhand_item().use_secondary()
			throw_state = ThrowState.IDLE

	if Input.is_action_just_pressed("reload"):
		if inv.get_mainhand_item():
			inv.get_mainhand_item().use_reload()
			throw_state = ThrowState.IDLE
#			if inv.get_mainhand_item() is ShotgunItem:
#				print(inv.get_mainhand_item())

	if Input.is_action_just_pressed("offhand_use"):
		if inv.get_offhand_item():
			inv.get_offhand_item().use_primary()
			throw_state = ThrowState.IDLE

	if throw_state == ThrowState.SHOULD_PLACE:
		var item : EquipmentItem = inv.get_mainhand_item() if throw_item == ItemSelection.ITEM_MAINHAND else inv.get_offhand_item()
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
					inv.drop_mainhand_item()
				else:
					inv.drop_offhand_item()
				item.call_deferred("global_translate", result.motion)

	elif throw_state == ThrowState.SHOULD_THROW:
		var item : EquipmentItem = null
		if throw_item == ItemSelection.ITEM_MAINHAND:
			item = inv.get_mainhand_item()
			inv.drop_mainhand_item()
		else:
			item = inv.get_offhand_item()
			inv.drop_offhand_item()
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

#	if Input.is_action_just_released("throw") and throw_state:
#		throw_state = false
#		var item = inv.get_mainhand_item()
#		if item:
#			if throw_press_length < hold_time_to_place:
#				inv.drop_mainhand_item()
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
			if interaction_target is PickableItem and character.inventory.current_mainhand_slot != 10:
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

func kick():
	var kick_object = legcast.get_collider()

	if legcast.is_colliding() and kick_object.is_in_group("Door_hitbox"):
		if is_grabbing == false:
			if Input.is_action_just_pressed("kick"):
				kick_object.get_parent().damage( -character.global_transform.basis.z , character.kick_damage)

	elif legcast.is_colliding() and kick_object.is_in_group("CHARACTER"):
		if Input.is_action_just_pressed("kick"):
			kick_object.get_parent().damage(character.kick_damage , kick_damage_type , kick_object)

	elif legcast.is_colliding() and kick_object is RigidBody:
		if Input.is_action_just_pressed("kick"):
			kick_object.apply_central_impulse( -character.global_transform.basis.z * kick_impulse)

func drop_grabbable():
	#when the drop button or keys are pressed , grabable objects are released
	if Input.is_action_just_pressed("main_throw")  or   Input.is_action_just_pressed("offhand_throw") and is_grabbing == true :
		wants_to_drop = true
		if grab_object != null :
			is_grabbing = false
			interaction_handled = true
			var impulse = active_mode.get_aim_direction() * throw_strength
#			if current_object is MeleeItem :
#				current_object.apply_throw_logic(impulse)
#			else:
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
