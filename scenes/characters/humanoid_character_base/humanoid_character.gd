extends RigidBody3D
class_name HumanoidCharacter

const MAX_NORMAL_Y = cos(deg_to_rad(55))
const COLLISIONS_REPORTED = 4

@onready var parameters : HumanoidCharacterParameters = $Parameters
@onready var character_state : HumanoidCharacterState = $State
@onready var input : HumanoidCharacterInput = $Input
@onready var character_collision: CharacterCollision = $CharacterCollision
@onready var model_root: Node3D = $ModelRoot
@onready var off_hand_root: Marker3D = %OffHandRoot
@onready var main_hand_root: Marker3D = %MainHandRoot
@onready var components: Node = $Components



var ground_ray_parameters := PhysicsRayQueryParameters3D.new()
var ground_detection_test_parameters := PhysicsTestMotionParameters3D.new()
var ceiling_detection_test_parameters := PhysicsTestMotionParameters3D.new()


func _ready() -> void:
	character_state.facing = global_basis
	global_basis = Basis.IDENTITY

	character_collision.height = parameters.standing_height
	ground_detection_test_parameters.collide_separation_ray = false
	ground_detection_test_parameters.motion = Vector3.DOWN*0.3
	ground_detection_test_parameters.max_collisions = COLLISIONS_REPORTED
	ceiling_detection_test_parameters.motion = Vector3.UP*0.3
	ceiling_detection_test_parameters.max_collisions = COLLISIONS_REPORTED

func _physics_process(delta: float) -> void:
	if global_rotation.y != 0:
		character_state.facing = global_basis * character_state.facing
		global_basis = Basis.IDENTITY
	# crouch input
	var target_crouch_ratio : float = 1.0 if input.crouch else 0.0

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
	character_state.current_crouch_ratio = move_toward(character_state.current_crouch_ratio, target_crouch_ratio, delta*parameters.crouch_animation_speed)
	character_collision.height = lerp(parameters.standing_height, parameters.crouch_height, character_state.current_crouch_ratio)
	character_state.sprinting = input.sprint

	model_root.global_basis = character_state.facing

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	character_state.was_on_ground = character_state.is_on_ground
	ground_detection_test_parameters.motion = Vector3.DOWN*0.2
	if character_state.was_on_ground:
		ground_detection_test_parameters.motion += Vector3.DOWN*0.1
	ground_detection_test_parameters.from = state.transform
	var ground_detection_result : PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	var ground_detected : bool = PhysicsServer3D.body_test_motion(
		get_rid(),
		ground_detection_test_parameters,
		ground_detection_result
	)
	character_state.is_on_ground = false
	var collision_normal := Vector3.UP
	var collision_position : Vector3 = state.transform.origin
	collision_position.y = -INF

	if ground_detected:
		for i in ground_detection_result.get_collision_count():
			var check_normal := ground_detection_result.get_collision_normal(i)
			var check_position := ground_detection_result.get_collision_point(i)

			# Only collisions with horizontal prin ground
			if check_normal.y < MAX_NORMAL_Y: continue
			# Only collisions below the body origin
			if check_position.y > state.transform.origin.y + 0.2: continue
			if (check_position.y > collision_position.y):
				collision_normal = check_normal
				collision_position = check_position
				character_state.is_on_ground = true

	# fallback to raycast
	if not character_state.is_on_ground:
		var space := PhysicsServer3D.space_get_direct_state(get_world_3d().space)
		var ray_parameters := PhysicsRayQueryParameters3D.new()
		ray_parameters.from = state.transform.origin + Vector3.UP*0.4
		ray_parameters.collision_mask = collision_mask
		ray_parameters.exclude = [self.get_rid()]
		ray_parameters.to = state.transform.origin
		if character_state.was_on_ground:
			ray_parameters.to += Vector3.DOWN*0.2
		var ray_result := space.intersect_ray(ray_parameters)
		if not ray_result.is_empty():
			collision_normal = ray_result["normal"]
			collision_position = ray_result["position"]
			character_state.is_on_ground = collision_normal.y > MAX_NORMAL_Y

	if character_state.should_jump():
		state.linear_velocity.y = parameters.jump_speed
		character_state.is_on_ground = false

	var ground_normal := Vector3.UP
	var control_multiplier : float = parameters.jump_control_multiplier

	if character_state.is_on_ground:
		ground_normal = collision_normal
		state.transform.origin.y = move_toward(state.transform.origin.y, collision_position.y, 2.0*state.step)
		control_multiplier = 1.0

	var ground_plane : Plane = Plane(ground_normal, 0.0)
	#var ground_angle = PI*0.5 - ground_normal.angle_to(Vector3.UP)

	var ground_velocity = ground_plane.project(state.linear_velocity)
	var normal_speed = state.linear_velocity.dot(ground_normal)


	var local_z : Vector3 = ground_plane.project(state.transform.basis.z).normalized()
	var local_x : Vector3 = ground_plane.project(state.transform.basis.x).normalized()
	var target_ground_velocity = input.movement_vector.x*local_x + input.movement_vector.z*local_z
	target_ground_velocity *= character_state.get_target_speed()
	ground_velocity = ground_velocity.move_toward(target_ground_velocity, state.step*parameters.base_acceleration*control_multiplier)

	if character_state.is_on_ground:
		normal_speed = maxf(normal_speed, 0.0)
		normal_speed = 0.0
	state.linear_velocity = ground_velocity + normal_speed*ground_normal

	#var ramp_factor = inverse_lerp(
		#parameters.min_slope_angle,
		#parameters.max_slope_angle,
		#ground_angle
	#)
#
	##var slide_factor = clamp(ramp_factor - 1.0, 0.0, 1.0)
	#ramp_factor = clamp(ramp_factor, 0.0, 1.0)

	state.linear_velocity += state.total_gravity*state.step
