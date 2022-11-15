extends Node


signal is_moving(is_player_moving)
var is_player_moving : bool = false

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

export var _grabcast : NodePath
onready var grabcast : RayCast = get_node(_grabcast) as RayCast

#export var Player_path : NodePath
#onready var player = get_node(Player_path)

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

#stealth player controller addon -->
enum State {
	STATE_WALKING,
	STATE_LEANING,
	STATE_CROUCHING,
	STATE_CRAWLING,
	STATE_CLAMBERING_RISE,
	STATE_CLAMBERING_LEDGE,
	STATE_CLAMBERING_VENT,
	STATE_NOCLIP,
}

export var speed : float = 0.5
export var gravity : float = 10.0
export var jump_force : float = 3.5
export(float, 0.05, 1.0) var crouch_rate = 0.08
export(float, 0.1, 1.0) var crawl_rate = 0.5
export var move_drag : float = 0.2
export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export var interact_distance : float = 0.75
export var mouse_sens : float = 0.5
export var lock_mouse : bool = true
export var head_bob_enabled : bool = true

var state = State.STATE_WALKING
var clamber_destination : Vector3 = Vector3.ZERO
var light_level : float = 0.0
var velocity : Vector3 = Vector3.ZERO
var drag_object : RigidBody = null
var _jumping : bool = false
var _bob_time : float = 0.0
var _clamber_m = null
var _bob_reset : float = 0.0

export var _cam_path : NodePath
onready var _cam_fps = get_node(_cam_path)
onready var _camera : ShakeCamera = get_node(_cam_path)
onready var _collider : CollisionShape = owner.get_node("CollisionShape")
export var _gun_cam_path : NodePath
onready var _gun_cam = get_node(_gun_cam_path)
onready var _frob_raycast = get_node("../Body/FPSCamera/GrabCast")

var _normal_collision_layer_and_mask : int = 1
var _collider_normal_radius : float = 0.0
var _collider_normal_height : float = 0.0
var _camera_orig_pos_y : float = 0.0
var _camera_pos_normal : Vector3 = Vector3.ZERO
var _click_timer : float = 0.0
var _throw_wait_time : float = 400	
#stealth player controller addon -->

var throw_state : int = ThrowState.IDLE
var throw_item : int = ItemSelection.ITEM_PRIMARY
var throw_press_length : float = 0.0
var stamina := 125.0
var active_mode_index = 0
onready var active_mode : ControlMode = get_child(0)

var grab_press_length : float = 0.0
var wanna_stand : bool = false
var is_crouching : bool = false
var wanna_grab : bool = false
var is_grabbing : bool = false
var just_clambered : bool = false
var interaction_handled : bool = false
var grab_object : RigidBody = null
var grab_relative_object_position : Vector3
var grab_distance : float = 0
var target
var current_object = null
var wants_to_drop = false

var is_player_crouch_toggle : bool = true


func _ready():
	_bob_reset = _camera.global_transform.origin.y - owner.global_transform.origin.y
	_clamber_m = ClamberManager.new(owner, _camera, owner.get_world())
	_collider_normal_radius = _collider.shape.radius
	_collider_normal_height = _collider.shape.height
	_normal_collision_layer_and_mask = owner.collision_layer
	_camera_orig_pos_y = _camera.global_transform.origin.y
	
	active_mode.set_deferred("is_active", true)
	pass # Replace with function body.
	


func _physics_process(delta : float):
	_camera_pos_normal = owner.global_transform.origin + Vector3.UP * _bob_reset
	
	_gun_cam.global_transform.origin = _camera_pos_normal
	_gun_cam.rotation_degrees = _camera.rotation_degrees
	
	active_mode.update()
	movement_basis = active_mode.get_movement_basis()
	interaction_target = active_mode.get_interaction_target()
	character.character_state.interaction_target = interaction_target
	interaction_handled = false
	current_object = active_mode.get_grab_target()
	#handle_movement(delta)
	handle_grab_input(delta)
	handle_grab(delta)
	
	handle_inventory(delta)
	next_weapon()
	previous_weapon()
	drop_grabbable()
	empty_slot()

	if is_grabbing==true:
		drop_grabbable()
#	handle_misc_controls(delta)
	
	if wanna_stand:
		var from = _collider.shape.height
		var to = _collider_normal_height
		_collider.shape.height = lerp(from, to, 0.1)

		from = _collider.shape.radius
		to = _collider_normal_radius
		_collider.shape.radius = lerp(from, to, 0.1)

		_collider.rotation_degrees.x = 90

		from = _camera.global_transform.origin
		to = _camera_pos_normal + (Vector3.UP * _bob_reset * (crouch_rate - 0.1))
		#to = _camera_pos_normal + (Vector3.UP * _bob_reset)
		_camera.global_transform.origin = lerp(from, to, 0.1)
		
		if (str(_collider.shape.height) == str(_collider_normal_height) or 
			str(_camera.global_transform.origin) == str(_camera_pos_normal + 
			(Vector3.UP * _bob_reset * (crouch_rate - 0.1)))):
			is_crouching = false
			wanna_stand = false
#			print("standing" + str(owner.global_transform.origin.y))
	
	match state:
		State.STATE_WALKING:
			_process_frob_and_drag()
#			if Input.is_action_pressed("lean"):
#				state = State.STATE_LEANING
#				return
				
			if Input.is_action_just_pressed("crouch"):
				state = State.STATE_CROUCHING
				return
			
#			if Input.is_action_pressed("crawl"):
#				state = State.STATE_CRAWLING
#				return
#
#			if Input.is_action_pressed("sneak"):
#				_walk(delta, 0.75)
#				return
#
#			if Input.is_action_just_pressed("noclip"):
#				state = State.STATE_NOCLIP
#				return
#
#			if Input.is_action_pressed("zoom"):
#				_camera.state = _camera.CameraState.STATE_ZOOM
#			else:
#				_camera.state = _camera.CameraState.STATE_NORMAL
			
			_walk(delta)
		
#		State.STATE_LEANING:
#			_process_frob_and_drag()
#			_lean()

		State.STATE_CROUCHING:
#			if Input.is_action_pressed("zoom"):
#				_camera.state = _camera.CameraState.STATE_ZOOM
#			else:
#				_camera.state = _camera.CameraState.STATE_NORMAL
				
			if Input.is_action_just_pressed("crouch"):
				if is_player_crouch_toggle:
					if is_crouching:
						is_crouching = false
						wanna_stand = true
						state = State.STATE_WALKING
						return
				
			_process_frob_and_drag()
			is_crouching = true
			_crouch()
			_walk(delta, 0.65)

#		State.STATE_CRAWLING:
#			if Input.is_action_pressed("zoom"):
#				_camera.state = _camera.CameraState.STATE_ZOOM
#			else:
#				_camera.state = _camera.CameraState.STATE_NORMAL
#
##			_crawling()
##			crawl_headmove(delta)
#			_walk(delta, 0.45)

		State.STATE_CLAMBERING_RISE:
			var pos = owner.global_transform.origin
			var target = Vector3(pos.x, clamber_destination.y, pos.z)
			owner.global_transform.origin = lerp(pos, target, 0.1)
			_crouch()
			is_crouching = true
			
			var from = _camera.rotation_degrees.x
			var to = pos.angle_to(target)
			_camera.rotation_degrees.x = lerp(from, to, 0.1)
			
			var d = pos - target
			if d.length() < 0.1:
				state = State.STATE_CLAMBERING_LEDGE
				return

		State.STATE_CLAMBERING_LEDGE:
			#_audio_player.play_clamber_sound(false)
			var pos = owner.global_transform.origin
			owner.global_transform.origin = lerp(pos, clamber_destination, 0.1)
			_crouch()
			is_crouching = true
			
			var from = _camera.rotation_degrees.x
			var to = owner.global_transform.origin.angle_to(clamber_destination)
			_camera.rotation_degrees.x = lerp(from, to, 0.1)
			
			var d = owner.global_transform.origin - clamber_destination
			if d.length() < 0.1:
				owner.global_transform.origin = clamber_destination
				just_clambered = true
				state = State.STATE_CROUCHING
				if is_player_crouch_toggle:
					if is_crouching:
						is_crouching = false
						wanna_stand = true
						state = State.STATE_WALKING
				return

#		State.STATE_NOCLIP:
#			if Input.is_action_just_pressed("noclip"):
#				state = State.STATE_WALKING
#				return
#
#			owner.collision_layer = 2
#			owner.collision_mask = 2
#			_noclip_walk()


func _input(event):
	if event is InputEventMouseButton and GameManager.is_reloading == false :
		if event.pressed:
			match event.button_index:
				BUTTON_WHEEL_UP:
					if character.inventory.current_primary_slot != 0:
						var total_inventory = character.inventory.current_primary_slot - 1
						if total_inventory != character.inventory.current_secondary_slot:
							character.inventory.current_primary_slot = total_inventory
						else:
							var plus_inventory = total_inventory - 1
							if plus_inventory != -1  :
								character.inventory.current_primary_slot = plus_inventory
							else:
								character.inventory.current_primary_slot = 10
					elif character.inventory.current_primary_slot == 0:
						character.inventory.current_primary_slot = 10
						
						
				BUTTON_WHEEL_DOWN:
					if character.inventory.current_primary_slot != 10:
						var total_inventory = character.inventory.current_primary_slot + 1
						if total_inventory != character.inventory.current_secondary_slot :
							character.inventory.current_primary_slot = total_inventory
						else:
							var plus_inventory = total_inventory + 1
							if character.inventory.current_secondary_slot != 10:
								character.inventory.current_primary_slot = plus_inventory
							else:
								character.inventory.current_primary_slot = 10
					elif character.inventory.current_primary_slot == 10:
						if character.inventory.current_secondary_slot != 0:
							character.inventory.current_primary_slot = 0
						else:
							character.inventory.current_primary_slot = 1
					if character.inventory.current_primary_slot!=9:
						character.inventory.current_primary_slot+=1
	
	if event is InputEventMouseMotion:
		if (state == State.STATE_CLAMBERING_LEDGE 
			or state == State.STATE_CLAMBERING_RISE 
			or state == State.STATE_CLAMBERING_VENT):
			return
		
		var m = 1.0
		
		if _camera.state == _camera.CameraState.STATE_ZOOM:
			m = _camera.zoom_camera_sens_mod
		
		owner.body.rotation_degrees.y -= event.relative.x * mouse_sens * m
		
		if state != State.STATE_CRAWLING:
			_camera.rotation_degrees.x -= event.relative.y * mouse_sens * m
			_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -90, 90)

		_camera._camera_rotation_reset = _camera.rotation_degrees


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
#	if Input.is_action_pressed("sprint") and stamina > 0:
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


func _walk(delta, speed_mod : float = 1.0) -> void:
#	owner.collision_layer = _normal_collision_layer_and_mask
#	owner.collision_mask = _normal_collision_layer_and_mask
	
#	if Input.is_action_pressed("sprint") and stamina > 0 and GameManager.is_reloading==false:
#		direction *= 0.5;
#		change_stamina(-0.3)
#	else:
#		direction *= 0.2;
#		if !Input.is_action_pressed("sprint"):
#			change_stamina(0.3)
#	print(stamina)
	var move_dir = Vector3()
	move_dir.x = (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	move_dir.z = (Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	move_dir = move_dir.normalized()
	move_dir = move_dir.rotated(Vector3.UP, owner.body.rotation.y)
	
	var y_velo = velocity.y
	
	var v1 = speed * move_dir - velocity * Vector3(move_drag, 0, move_drag)
	var v2 = Vector3.DOWN * gravity * delta
	
	velocity += v1 + v2
	
	var grounded = owner.is_on_floor()
	
	velocity = owner.move_and_slide((velocity * speed_mod) + owner.get_floor_velocity(),
			Vector3.UP, true, 4, PI, false)
	
	if move_dir == Vector3.ZERO:
		is_player_moving = false
		emit_signal("is_moving", is_player_moving)
	else:
		is_player_moving = true
		emit_signal("is_moving", is_player_moving)
	
#	if owner.is_on_floor() and !grounded and state != State.STATE_CROUCHING and _camera.stress < 0.1:
#		#_audio_player.play_land_sound()
#		_camera.add_stress(0.25)

	grounded = owner.is_on_floor()
	
	if !grounded and y_velo < velocity.y:
		velocity.y = y_velo
		
	if grounded:
		velocity.y = -0.01
		_jumping = false
	
	if grounded and Input.is_action_just_pressed("clamber"):
		if state != State.STATE_WALKING or _jumping:
			return
		
		# Check for clamber
		var c = _clamber_m.attempt_clamber()
		if c != Vector3.ZERO:
			print(c)
			clamber_destination = c
			state = State.STATE_CLAMBERING_RISE
#			_audio_player.play_clamber_sound(true)
			return
			
		# If no clamber, jump
		velocity.y = jump_force
		_jumping = true
		return
		
	#_handle_player_sound_emission()
	
	if head_bob_enabled and grounded and state == State.STATE_WALKING:
		_head_bob(delta)
		
#	if velocity.length() > 0.1 and grounded and not _audio_player.playing:
#		_audio_player.play_footstep_sound()


func _head_bob(delta : float) -> void:
	if velocity.length() == 0.0:
		var br = Vector3(0, _bob_reset, 0)
		_camera.global_transform.origin = owner.global_transform.origin + br

	_bob_time += delta
	var y_bob = sin(_bob_time * (4 * PI)) * velocity.length() * (speed / 1000.0)
	var z_bob = sin(_bob_time * (2 * PI)) * velocity.length() * 0.2
	_camera.global_transform.origin.y += y_bob
	_camera.rotation_degrees.z = z_bob


func _noclip_walk() -> void:
	var move_dir = Vector3()
	move_dir.x = (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	move_dir.z = (Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	move_dir = move_dir.normalized()	
	move_dir = move_dir.rotated(Vector3.RIGHT, _cam_fps.rotation.x)
	move_dir = move_dir.rotated(Vector3.UP, owner.rotation.y)
	
	var _vel = owner.move_and_slide(move_dir * speed * 3.0)


func _crouch() -> void:
	wanna_stand = false
	crouch_rate = clamp(crouch_rate, 0.05, 1.0)

	var from = _collider.shape.height
	var to = _collider_normal_height * crouch_rate
	_collider.shape.height = lerp(from, to, 0.1)
	
	from = _collider.shape.radius
	to = _collider_normal_radius * crouch_rate
	_collider.shape.radius = lerp(from, to, 0.1)
	
	_collider.rotation_degrees.x = 0
	
	from = _camera.global_transform.origin
	to = _camera_pos_normal + (Vector3.DOWN * _bob_reset * (crouch_rate - 0.1))
	_camera.global_transform.origin = lerp(from, to, 0.1)
	
	velocity.y -= 0.08
	
	if is_player_crouch_toggle:
		return
		

		
	if !Input.is_action_pressed("crouch") and state == State.STATE_CROUCHING:
		var pos = owner.global_transform.origin
		var space = owner.get_world().direct_space_state
		
		var r_up = space.intersect_ray(pos, 
				pos + Vector3.UP * _bob_reset + Vector3.UP * 0.2, [owner])
				
		if just_clambered:
			state = State.STATE_WALKING
			wanna_stand = true
			return
		
		if !r_up:
			pass
		elif r_up.collider.name != "ground":
			return
		else:
			just_clambered = false
			state = State.STATE_WALKING
			wanna_stand = true
			return
		
#		state = State.STATE_WALKING
#
#		while(!is_equal_approx(_collider.shape.height, _collider_normal_height) or !is_equal_approx(owner.global_transform.origin.y, 0.15)):
#			from = _collider.shape.height
#			to = _collider_normal_height
#			_collider.shape.height = lerp(from, to, 0.1)
#
#			from = _collider.shape.radius
#			to = _collider_normal_radius
#			_collider.shape.radius = lerp(from, to, 0.1)
#
#			_collider.rotation_degrees.x = 90
#
#			from = _camera.global_transform.origin
#			pos.y = 0.15
#			to = pos + (Vector3.UP * _bob_reset)
#			#to = _camera_pos_normal + (Vector3.UP * _bob_reset)
#			_camera.global_transform.origin = lerp(from, to, 0.1)
#
#			from = owner.global_transform.origin.y
#			to = 0.15
#			owner.global_transform.origin.y = lerp(from, to, 0.1)
#
#			velocity.y -= 1

#		state = State.STATE_WALKING
#		_camera.global_transform.origin = pos + Vector3.UP * _bob_reset
#		_collider.rotation_degrees.x = 90
#		_collider.shape.height = _collider_normal_height
#		_collider.shape.radius = _collider_normal_radius


func _process_frob_and_drag():
	if (Input.is_action_just_pressed("main_use_primary") 
		and _click_timer == 0.0 
		and drag_object != null):
		_click_timer = OS.get_ticks_msec()
		
	if Input.is_action_pressed("main_use_primary"):
		if _click_timer + _throw_wait_time < OS.get_ticks_msec():
			if _click_timer == 0.0:
				return
			
#			_camera.set_crosshair_state("normal")
			_click_timer = 0.0
			_throw()
			drag_object = null
	
	if _frob_raycast.is_colliding():
		var c = _frob_raycast.get_collider()
		if drag_object == null and c is RigidBody:
			if c.scale > (Vector3.ONE * 5):
				return
				
			var w = owner.get_world().direct_space_state
			var r = w.intersect_ray(c.global_transform.origin,
					c.global_transform.origin + Vector3.UP * 0.5, [owner])
						
			if r and r.collider == owner:
				return
				
#			_camera.set_crosshair_state("interact")
				
			if Input.is_action_just_released("main_use_primary"):
#				_camera.set_crosshair_state("dragging")
				drag_object = c
				drag_object.linear_velocity = Vector3.ZERO
	
	if Input.is_action_just_released("main_use_primary"):	
		if drag_object != null:
			if _click_timer + _throw_wait_time > OS.get_ticks_msec():
				if _click_timer == 0.0:
					return
				
#				_camera.set_crosshair_state("normal")
				drag_object = null
				_click_timer = 0.0
				
	if Input.is_action_just_pressed("main_use_secondary") and drag_object != null:
		drag_object.rotation_degrees.y += 45
		drag_object.rotation_degrees.x = 90
				
	if drag_object:
		_drag()
		
		var d = _camera.global_transform.origin.distance_to(drag_object.global_transform.origin)
		if  d > interact_distance + 0.35:
			drag_object = null
	
#	if !drag_object and not _frob_raycast.is_colliding():
#		_camera.set_crosshair_state("normal")
	

func _drag(damping : float = 0.5, s2ms : int = 15) -> void:
	var d = _frob_raycast.global_transform.basis.z.normalized()
	var dest = _frob_raycast.global_transform.origin - d * interact_distance
	var d1 = (dest - drag_object.global_transform.origin)
	drag_object.angular_velocity = Vector3.ZERO
	
	var v1 = velocity * damping + drag_object.linear_velocity * damping
	var v2 = (d1 * s2ms) * (1.0 - damping) / drag_object.mass
	
	drag_object.linear_velocity = v1 + v2
	
	
func _throw(throw_force : float = 10.0) -> void:
	var d = -_camera.global_transform.basis.z.normalized()
	drag_object.apply_central_impulse(d * throw_force)
	_camera.add_stress(0.2)



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
			is_grabbing = false
			wanna_grab=false 
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
			if Input.is_action_just_pressed("main_throw") and owner.inventory.get_primary_item() and is_grabbing == false and GameManager.is_reloading == false:
				throw_item = ItemSelection.ITEM_PRIMARY
				throw_state = ThrowState.PRESSING
				throw_press_length = 0.0
			elif Input.is_action_just_pressed("offhand_throw") and owner.inventory.get_secondary_item() and is_grabbing == false  and GameManager.is_reloading == false:
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



func empty_slot():
	
	var inv = character.inventory
	if inv.hotbar != null:
		var gun = preload("res://scenes/objects/items/pickable/equipment/empty_slot/empty_hand.tscn").instance()
		if  !inv.hotbar.has(10):
			inv.hotbar[10] = gun

func handle_inventory(delta : float):
	var inv = character.inventory

	# Primary slot selection
	for i in range(character.inventory.HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]) and GameManager.is_reloading == false  :
			if i != inv.current_secondary_slot :
				inv.current_primary_slot = i
				throw_state = ThrowState.IDLE
	
	# Secondary slot selection
		
	if Input.is_action_just_pressed("cycle_offhand_slot") and GameManager.is_reloading == false:
		var start_slot = inv.current_secondary_slot
		var new_slot = (start_slot + 1)%inv.hotbar.size()
		while new_slot != start_slot \
			and (
					(
						
						inv.hotbar[new_slot] != null \
						and inv.hotbar[new_slot].item_size != GlobalConsts.ItemSize.SIZE_SMALL\
					)\
					or new_slot == inv.current_primary_slot \
					or inv.hotbar[new_slot] == null \
				):
				
				new_slot = (new_slot + 1)%inv.hotbar.size()
		if start_slot != new_slot:
			inv.current_secondary_slot = new_slot
			print("Offhand slot cycled to ", new_slot)
			throw_state = ThrowState.IDLE
	
	if Input.is_action_just_pressed("hotbar_11"):
		if inv.current_secondary_slot != 10:
			inv.current_secondary_slot = 10
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
			var x_pos = item.global_transform.origin.x
			#Applies unique throw  logic to item if its a melee item 
			if item is MeleeItem :
				item.apply_throw_logic(impulse)
			else:
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
			if interaction_target is PickableItem and character.inventory.current_primary_slot != 10:
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


func drop_grabbable():
	#when the drop button or keys are pressed , grabable objects are released
	if Input.is_action_just_pressed("main_throw")  or   Input.is_action_just_pressed("offhand_throw") and is_grabbing == true :
		wants_to_drop = true
		if grab_object != null :
			is_grabbing = false
			interaction_handled = true
			var impulse = active_mode.get_aim_direction()*throw_strength
#			if current_object is MeleeItem :
#				current_object.apply_throw_logic(impulse)
#			else:
			wanna_grab = false
			grab_object.apply_central_impulse(impulse)
	if Input.is_action_just_released("main_throw") or Input.is_action_just_released("offhand_throw"):
		wants_to_drop = false
#		
	#when the drop buttons or keys are pressed , grabable objects are released
	if Input.is_action_just_pressed("main_throw") or   Input.is_action_just_pressed("offhand_throw"):
		is_grabbing = false
		interaction_handled = true
		var impulse = active_mode.get_aim_direction()*throw_strength
		grab_object.apply_central_impulse(impulse)


func change_stamina(amount: float) -> void:
	stamina = min(125, max(0, stamina + amount));
	HUDS.tired(stamina);


func previous_weapon():
	if Input.is_action_just_pressed("Previous_weapon") and character.inventory.current_primary_slot != 0:
		character.inventory.current_primary_slot -=1 
		
	elif  Input.is_action_just_pressed("Previous_weapon") and character.inventory.current_primary_slot == 0:
		character.inventory.current_primary_slot = 10


func next_weapon():
	if Input.is_action_just_pressed("Next_weapon") and character.inventory.current_primary_slot != 10:
		character.inventory.current_primary_slot += 1
		
	elif  Input.is_action_just_pressed("Next_weapon") and character.inventory.current_primary_slot == 10:
		character.inventory.current_primary_slot = 0
