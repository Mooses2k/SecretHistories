extends RigidBody3D
class_name HumanoidCharacter

#TODO: figure out parameters (position, direction/force vector)
signal recoiled()

const MAX_NORMAL_Y = cos(deg_to_rad(55))
const COLLISIONS_REPORTED = 4

@onready var parameters : HumanoidCharacterParameters = $Parameters
@onready var state : HumanoidCharacterState = $State
@onready var input : HumanoidCharacterInput = $Input
@onready var character_collision: CharacterCollision = $CharacterCollision
@onready var model_root: Node3D = $ModelRoot
@onready var off_hand_root: Marker3D = %OffHandRoot
@onready var main_hand_root: Marker3D = %MainHandRoot
@onready var inventory: Inventory = $Inventory
@onready var throw_origin: Marker3D = $ModelRoot/ThrowOrigin
@onready var place_origin: Marker3D = $ModelRoot/PlaceOrigin
@onready var kick_cast: KickCast = $ModelRoot/KickCast


var ground_ray_parameters := PhysicsRayQueryParameters3D.new()
var ground_detection_test_parameters := PhysicsTestMotionParameters3D.new()
var ceiling_detection_test_parameters := PhysicsTestMotionParameters3D.new()


func _ready() -> void:
	state.facing = global_basis
	global_basis = Basis.IDENTITY

	character_collision.height = parameters.standing_height
	ground_detection_test_parameters.collide_separation_ray = false
	ground_detection_test_parameters.motion = Vector3.DOWN*0.3
	ground_detection_test_parameters.max_collisions = COLLISIONS_REPORTED
	ceiling_detection_test_parameters.motion = Vector3.UP*0.3
	ceiling_detection_test_parameters.max_collisions = COLLISIONS_REPORTED


func _physics_process(delta: float) -> void:
	if global_rotation.y != 0:
		state.facing = global_basis * state.facing
		global_basis = Basis.IDENTITY
	# crouch input
	state.sprinting = input.sprint and input.movement_vector.dot(-state.facing.z) > 0.0 and state.stamina > 0.0
	if state.sprinting:
		state.stamina -= parameters.stamina_drain_rate * delta
	else:
		state.stamina += parameters.stamina_drain_rate * delta
	var target_crouch_ratio : float = 1.0 if (input.crouch and not state.sprinting) else 0.0
	
	var target_height = lerp(parameters.standing_height, parameters.crouch_height, target_crouch_ratio)
	if target_height > character_collision.height:
		ceiling_detection_test_parameters.motion = Vector3.UP * (target_height - character_collision.height + 0.1)
		ceiling_detection_test_parameters.from = global_transform
		var ceiling_detection_result := PhysicsTestMotionResult3D.new()
		var ceiling_detected : bool = PhysicsServer3D.body_test_motion(
			get_rid(),
			ceiling_detection_test_parameters,
			ceiling_detection_result
		)
		if ceiling_detected:
			for i in ceiling_detection_result.get_collision_count():
				var check_normal := ceiling_detection_result.get_collision_normal(i)
				var check_position := ceiling_detection_result.get_collision_point(i)
				check_position.y -= global_position.y
				# Only collisions with horizontal prin ground
				if is_zero_approx(check_normal.y): continue
				# Only collisions below the body origin
				if (check_position.y < target_height + 0.1):
					target_height = check_position.y - 0.1
			target_height = maxf(target_height, character_collision.height)
			target_crouch_ratio = inverse_lerp(parameters.standing_height, parameters.crouch_height, target_height)
	state.current_crouch_ratio = move_toward(state.current_crouch_ratio, target_crouch_ratio, delta/parameters.crouch_animation_duration)
	character_collision.height = lerp(parameters.standing_height, parameters.crouch_height, state.current_crouch_ratio)
	
	model_root.global_basis = state.facing


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	state.was_on_ground = state.is_on_ground
	ground_detection_test_parameters.motion = Vector3.DOWN*0.2
	if state.was_on_ground:
		ground_detection_test_parameters.motion += Vector3.DOWN*0.1
	ground_detection_test_parameters.from = physics_state.transform
	var ground_detection_result : PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	var ground_detected : bool = PhysicsServer3D.body_test_motion(
		get_rid(),
		ground_detection_test_parameters,
		ground_detection_result
	)
	state.is_on_ground = false
	var collision_normal := Vector3.UP
	var collision_position : Vector3 = physics_state.transform.origin
	collision_position.y = -INF

	if ground_detected:
		for i in ground_detection_result.get_collision_count():
			var check_normal := ground_detection_result.get_collision_normal(i)
			var check_position := ground_detection_result.get_collision_point(i)

			# Only collisions with horizontal prin ground
			if check_normal.y < MAX_NORMAL_Y: continue
			# Only collisions below the body origin
			if check_position.y > physics_state.transform.origin.y + 0.2: continue
			if (check_position.y > collision_position.y):
				collision_normal = check_normal
				collision_position = check_position
				state.is_on_ground = true

	# fallback to raycast
	if not state.is_on_ground:
		var space := PhysicsServer3D.space_get_direct_state(get_world_3d().space)
		var ray_parameters := PhysicsRayQueryParameters3D.new()
		ray_parameters.from = physics_state.transform.origin + Vector3.UP*0.4
		ray_parameters.collision_mask = collision_mask
		ray_parameters.exclude = [self.get_rid()]
		ray_parameters.to = physics_state.transform.origin
		if state.was_on_ground:
			ray_parameters.to += Vector3.DOWN*0.2
		var ray_result := space.intersect_ray(ray_parameters)
		if not ray_result.is_empty():
			collision_normal = ray_result["normal"]
			collision_position = ray_result["position"]
			state.is_on_ground = collision_normal.y > MAX_NORMAL_Y

	if state.should_jump():
		physics_state.linear_velocity.y = parameters.jump_speed
		state.is_on_ground = false

	var ground_normal := Vector3.UP
	var control_multiplier : float = parameters.jump_control_multiplier

	if state.is_on_ground:
		ground_normal = collision_normal
		physics_state.transform.origin.y = move_toward(
			physics_state.transform.origin.y, 
			collision_position.y, 
			2.0*physics_state.step
		)
		control_multiplier = 1.0

	var ground_plane : Plane = Plane(ground_normal, 0.0)
	#var ground_angle = PI*0.5 - ground_normal.angle_to(Vector3.UP)

	var ground_velocity = ground_plane.project(physics_state.linear_velocity)
	var normal_speed = physics_state.linear_velocity.dot(ground_normal)


	var local_z : Vector3 = ground_plane.project(physics_state.transform.basis.z).normalized()
	var local_x : Vector3 = ground_plane.project(physics_state.transform.basis.x).normalized()
	var target_ground_velocity = (input.movement_vector.x*local_x + input.movement_vector.z*local_z)
	target_ground_velocity *= state.get_target_speed()
	ground_velocity = ground_velocity.move_toward(target_ground_velocity, physics_state.step*parameters.base_acceleration*control_multiplier)

	if state.is_on_ground:
		normal_speed = maxf(normal_speed, 0.0)
		normal_speed = 0.0
	physics_state.linear_velocity = ground_velocity + normal_speed*ground_normal

	#var ramp_factor = inverse_lerp(
		#parameters.min_slope_angle,
		#parameters.max_slope_angle,
		#ground_angle
	#)
#
	##var slide_factor = clamp(ramp_factor - 1.0, 0.0, 1.0)
	#ramp_factor = clamp(ramp_factor, 0.0, 1.0)

	physics_state.linear_velocity += physics_state.total_gravity*physics_state.step


func recoil() -> void:
	print("recoil")
	recoiled.emit()


func kick():
	if state.stamina < parameters.kick_stamina_cost or state.time_since_kick < parameters.kick_cooldown:
		return
	state.time_since_kick = 0.0
	state.stamina -= 50.0
	var kick_list : Array[Node3D] = kick_cast.get_kick_objects()
	var kick_direction := kick_cast.global_basis.y
	var kick_origin := kick_cast.global_position
	for node : Node3D in kick_list:
		if node is RigidBody3D:
			var body := node as RigidBody3D
			var kick_impulse := minf(parameters.kick_impulse, body.mass * parameters.kick_max_speed)
			body.apply_impulse(kick_impulse * kick_direction, kick_origin - body.global_position)
		if node is Hurtbox:
			var hurtbox := node as Hurtbox
			hurtbox.damage(parameters.kick_damage, parameters.kick_damage_type, kick_direction, kick_origin)
		pass
	pass


func dodge() -> void:
	if state.stamina >= parameters.dodge_stamina_cost and state.time_since_dodge >= parameters.dodge_cooldown:
		state.stamina -= parameters.dodge_stamina_cost
		state.time_since_dodge = 0.0
		
		# Apply impulse based on movement direction
		var dodge_direction := input.movement_vector.normalized()
		if dodge_direction == Vector3.ZERO:
			# If no movement input, use facing direction
			dodge_direction = -state.facing.z
		else:
			# Project movement direction onto ground plane
			dodge_direction = dodge_direction - state.facing.y * dodge_direction.dot(state.facing.y)
			dodge_direction = dodge_direction.normalized()
		
		# Apply the dodge impulse
		apply_impulse(dodge_direction * parameters.dodge_impulse, Vector3.ZERO)
		
		# Add animation hook - set a parameter that can be used in the animation tree
		pass
		
		print("Dodged with impulse: ", dodge_direction * parameters.dodge_impulse)
