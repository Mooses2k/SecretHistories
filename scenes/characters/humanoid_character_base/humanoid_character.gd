extends RigidBody3D
class_name HumanoidCharacter


#TODO: figure out parameters (position, direction/force vector)
signal recoiled()

const MAX_NORMAL_Y = cos(deg_to_rad(55))
const COLLISIONS_REPORTED = 4

var ground_ray_parameters := PhysicsRayQueryParameters3D.new()
var ground_detection_test_parameters := PhysicsTestMotionParameters3D.new()
var ceiling_detection_test_parameters := PhysicsTestMotionParameters3D.new()

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
@onready var audio_player: CharacterAudio = $Audio
@onready var animation_tree: AnimationTree = $CharacterAnimationTree
@onready var character_reload_anims = $CharacterReloadAnims

# Old-character landing rule: the land sound plays only when the ground is
# regained after a jump, not on every step-off-a-ledge.
var _is_jumping := false

# Owner-approved movement noise ladder (per footstep material; sprint carpet
# equals walk stone). Crouch-walk is silent: no producer writes noise.
const WALK_NOISE : Dictionary = {
	AudioLibrary.FOOTSTEP_TYPES.STONE: 6.0,
	AudioLibrary.FOOTSTEP_TYPES.GRAVEL: 9.0,
	AudioLibrary.FOOTSTEP_TYPES.CARPET: 3.0,
}
const SPRINT_NOISE : Dictionary = {
	AudioLibrary.FOOTSTEP_TYPES.STONE: 12.0,
	AudioLibrary.FOOTSTEP_TYPES.GRAVEL: 14.0,
	AudioLibrary.FOOTSTEP_TYPES.CARPET: 6.0,
}
const LANDING_NOISE : float = 10.0
const NOISE_CLEAR_DELAY_MS : int = 200

# Noise detectable by a SoundSensor. Set on each footstep and landing, then
# cleared deterministically NOISE_CLEAR_DELAY_MS later (same decay shape as
# the PickableItem noise surface).
var noise_level : float = 0
var _noise_clear_at_msec : int = 0


## Ladder lookup, static so tests can pin the values without a live body.
## Unknown materials are silent rather than falling back to stone.
static func movement_noise_for(material : AudioLibrary.FOOTSTEP_TYPES, sprinting : bool) -> float:
	var ladder : Dictionary = SPRINT_NOISE if sprinting else WALK_NOISE
	var level : float = ladder.get(material, 0.0)
	return level


## Movement intent the body consumes (3.x kick-lock parity, issue #747):
## while the kick cooldown window runs the intent reads as zero, so the
## player cannot steer during the kick (origin/main player_controller.gd
## line 231-233 zeroed character_state.move_direction while the kick timer
## ran). The 3.x window was the one-shot KickTimer's default 1.0 s wait,
## which equals parameters.kick_cooldown here, so the cooldown clock is the
## lock window. Jump input stays live, so jumpkicks still work, and dodge
## (a dev4 behavior) reads raw input and keeps its own rules.
func movement_intent() -> Vector3:
	if state.time_since_kick < parameters.kick_cooldown:
		return Vector3.ZERO
	return input.movement_vector


func apply_landing_noise() -> void:
	noise_level = LANDING_NOISE
	_noise_clear_at_msec = Time.get_ticks_msec() + NOISE_CLEAR_DELAY_MS


## Fires a melee attack one-shot on the character animation tree. The equipped
## item owns the attack fact (attack_cut / attack_thrust); this is the seam
## that keeps items out of the animation tree's internals.
func play_melee_attack(attack : StringName, left_hand : bool, attack_speed : float = 1.0) -> void:
	animation_tree.fire_melee_one_shot(attack, left_hand, attack_speed)


## Starts the character-side reload layer for one gun press: fires the
## reload OneShot named by the gun's exact item_name and hands the offhand
## unequip/re-equip choreography to the CharacterReloadAnims coordinator
## (small guns only, 3.x parity).
func play_reload_animation(gun : EquipmentItem) -> void:
	character_reload_anims.start_reload(gun)


## Attack noise (3.x melee parity: thrust 8, cut 10), same decay shape as the
## landing and footstep producers.
func apply_attack_noise(level : float) -> void:
	noise_level = level
	_noise_clear_at_msec = Time.get_ticks_msec() + NOISE_CLEAR_DELAY_MS


func _ready() -> void:
	state.facing = global_basis
	global_basis = Basis.IDENTITY
	# Runtime camera shake mount (issue #747): the player camera carries the
	# minimal stress shake driver (3.x ShakeCamera parity). Attached here in
	# code instead of the scene: scene edits on player.tscn are banned, and
	# only the player has a camera node to find.
	var camera_node := get_node_or_null("ModelRoot/MainCamera")
	if camera_node is Camera3D and camera_node.get_script() == null:
		camera_node.set_script(load("res://scenes/characters/player/camera_stress_shake.gd"))

	character_collision.height = parameters.standing_height
	ground_detection_test_parameters.collide_separation_ray = false
	ground_detection_test_parameters.motion = Vector3.DOWN * 0.3
	ground_detection_test_parameters.max_collisions = COLLISIONS_REPORTED
	ceiling_detection_test_parameters.motion = Vector3.UP * 0.3
	ceiling_detection_test_parameters.max_collisions = COLLISIONS_REPORTED


func _physics_process(delta: float) -> void:
	# Footstep and landing noise decay deterministically a short time after
	# the step that set it, mirroring the item noise decay.
	if noise_level > 0.0 and Time.get_ticks_msec() >= _noise_clear_at_msec:
		noise_level = 0.0
	if not state.is_controllable(): return
	if global_rotation.y != 0:
		state.facing = global_basis * state.facing
		global_basis = Basis.IDENTITY
	# Skip normal movement logic in noclip mode
	if not state.noclip_enabled:
		# crouch input
		state.sprinting = (
			input.sprint
			and movement_intent().dot(-state.facing.z) > 0.0
			and state.stamina > 0.0
			and KeyInputSettings.shift_sprint_enabled()
		)
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

		# Movement audio (old character.gd parity): a footstep whenever the
		# body is actually moving on the ground and the previous one finished.
		# Planar speed only: a grounded RigidBody always carries a constant
		# gravity term on y (~0.16 m/s), which defeats the old 3D threshold.
		var planar_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
		if state.is_on_ground and planar_speed > 0.5 and not audio_player.movement_audio.playing:
			# 3.x parity: the floor surface type under the character selects
			# the footstep material set (stone, gravel, carpet).
			var footstep_material : AudioLibrary.FOOTSTEP_TYPES = audio_player.resolve_footstep_material(global_position)
			if state.current_crouch_ratio > 0.5:
				audio_player.play_footstep_sound(-1.0, 0.1, -20, footstep_material)
			else:
				# Movement noise producer (owner-approved ladder). The
				# SoundSensor reads this body's noise_level.
				noise_level = movement_noise_for(footstep_material, state.sprinting)
				_noise_clear_at_msec = Time.get_ticks_msec() + NOISE_CLEAR_DELAY_MS
				if state.sprinting:
					audio_player.play_footstep_sound(5.0, 1.5, 0.0, footstep_material)
				else:
					audio_player.play_footstep_sound(5.0, 1.0, 0.0, footstep_material)

		# Breathing (3.x Stamina node parity, player only): loudness tracks
		# low stamina, always running while alive.
		if self is Player:
			audio_player.play_breathing(state.stamina_ratio)

	model_root.global_basis = state.facing


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	if not state.is_controllable(): return
	state.was_on_ground = state.is_on_ground
	ground_detection_test_parameters.motion = Vector3.DOWN * 0.2
	if state.was_on_ground:
		ground_detection_test_parameters.motion += Vector3.DOWN * 0.1
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
	
	# Handle noclip movement
	if state.noclip_enabled:
		# In noclip mode, move directly based on input without ground constraints
		var noclip_input := input.movement_vector
		# Add vertical movement in noclip mode using jump and crouch inputs
		if input.jump:
			noclip_input.y += 1.0
		if input.crouch:
			noclip_input.y -= 1.0
		
		# Normalize the input vector to prevent faster diagonal movement
		if noclip_input.length() > 1.0:
			noclip_input = noclip_input.normalized()
		
		# Use base speed directly to avoid crouch speed penalties
		var target_velocity := noclip_input * parameters.base_speed
		physics_state.linear_velocity = physics_state.linear_velocity.move_toward(
			target_velocity,
			physics_state.step * parameters.base_acceleration * 2.0
		)
	else:
		# Normal movement logic
		if state.should_jump():
			physics_state.linear_velocity.y = parameters.jump_speed
			state.is_on_ground = false
			_is_jumping = true

		# Land sound (old character.gd parity): regain the ground after a jump.
		if state.is_on_ground and not state.was_on_ground and _is_jumping:
			_is_jumping = false
			audio_player.play_land_sound()
			# Landing noise (owner-approved ladder). Crouch land silent stays
			# silent: no noise while crouched.
			if state.current_crouch_ratio <= 0.5:
				apply_landing_noise()
		
		var ground_normal := Vector3.UP
		var control_multiplier : float = parameters.jump_control_multiplier
		
		if state.is_on_ground:
			ground_normal = collision_normal
			physics_state.transform.origin.y = move_toward(
				physics_state.transform.origin.y,
				collision_position.y,
				2.0 * physics_state.step
			)
			control_multiplier = 1.0
		
		var ground_plane : Plane = Plane(ground_normal, 0.0)
		#var ground_angle = PI*0.5 - ground_normal.angle_to(Vector3.UP)
		
		var ground_velocity = ground_plane.project(physics_state.linear_velocity)
		var normal_speed = physics_state.linear_velocity.dot(ground_normal)

		var local_z : Vector3 = ground_plane.project(physics_state.transform.basis.z).normalized()
		var local_x : Vector3 = ground_plane.project(physics_state.transform.basis.x).normalized()
		var target_ground_velocity = (movement_intent().x * local_x + movement_intent().z * local_z)
		target_ground_velocity *= state.get_target_speed()
		ground_velocity = ground_velocity.move_toward(target_ground_velocity, physics_state.step * parameters.base_acceleration * control_multiplier)
		
		if state.is_on_ground:
			normal_speed = maxf(normal_speed, 0.0)
			normal_speed = 0.0
		physics_state.linear_velocity = ground_velocity + normal_speed * ground_normal
	
	#var ramp_factor = inverse_lerp(
		#parameters.min_slope_angle,
		#parameters.max_slope_angle,
		#ground_angle
	#)

	#var slide_factor = clamp(ramp_factor - 1.0, 0.0, 1.0)
	#ramp_factor = clamp(ramp_factor, 0.0, 1.0)
	
	# Apply gravity only if not in noclip mode
	if not state.noclip_enabled:
		physics_state.linear_velocity += physics_state.total_gravity * physics_state.step


func toggle_noclip() -> void:
	if not state.noclip_enabled:
		# Enable noclip
		state.noclip_enabled = true
		character_collision.disabled = true
		gravity_scale = 0.0
		print("CHEAT: noclip enabled")
	else:
		# Disable noclip
		state.noclip_enabled = false
		gravity_scale = 1.0
		# Always end standing (equivalent to wanna_stand = true in old system)
		input.crouch = false
		character_collision.disabled = false
		print("CHEAT: noclip disabled")


func recoil() -> void:
	print("recoil")
	recoiled.emit()


## Kick execution point shared by every trigger source. `from_action` marks
## the separately bound kick key (issue #606); the default (no argument) is
## the contextual Shift-tap path wired from player_controller, which the
## Shift overload settings gate at this seam (wiki Interface 5.2.1). The
## frozen player_controller keeps calling kick() with no argument, so its
## call site stays untouched.
func kick(from_action : bool = false) -> void:
	if state.stamina < parameters.kick_stamina_cost or state.time_since_kick < parameters.kick_cooldown:
		return
	if not from_action and not KeyInputSettings.shift_kick_enabled():
		return
	print("kick")
	state.time_since_kick = 0.0
	state.stamina -= 50.0
	# 3.x kick feedback parity (issue #747): the frozen character.gd kicked
	# the camera with add_stress(0.25) on every kick (character.gd line 289).
	# Only the player carries a camera node.
	var camera_node := get_node_or_null("ModelRoot/MainCamera")
	if camera_node != null and camera_node.has_method("add_stress"):
		camera_node.add_stress(0.25)
	var kick_list : Array[Node3D] = kick_cast.get_kick_objects()
	print(kick_list)
	var kick_direction := kick_cast.global_basis.y
	var kick_origin := kick_cast.global_position
	# Array instead of dicitonary because the list is assumed to be very small
	var hit_list : Array[Node]
	for node : Node3D in kick_list:
		if node is RigidBody3D:
			var body := node as RigidBody3D
			var kick_impulse := minf(parameters.kick_impulse, body.mass * parameters.kick_max_speed)
			body.apply_impulse(kick_impulse * kick_direction, kick_origin - body.global_position)
		# The kick is the one damage entry that lands on large bodies today
		# (bullets, bombs, dropped-item impacts and melee hitboxes all target
		# Hurtbox sensors, which large objects do not carry). Break-capable
		# large objects accumulate the kick damage; everyone else ignores it.
		if node.has_method("accumulate_break_damage"):
			node.accumulate_break_damage(parameters.kick_damage)
		if node is Hurtbox:
			var hurtbox := node as Hurtbox
			if not hit_list.has(hurtbox.owner_node):
				hit_list.push_back(hurtbox.owner_node)
				hurtbox.damage(parameters.kick_damage, parameters.kick_damage_type, kick_direction, kick_origin)
		pass
	pass


func dodge() -> void:
	# Contextual Shift + direction dodge: the only dodge trigger in dev4,
	# so the Shift overload setting gates it here at the humanoid seam.
	if not KeyInputSettings.shift_dodge_enabled():
		return
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
		apply_central_impulse(dodge_direction * parameters.dodge_impulse * mass)

		# Add animation hook - set a parameter that can be used in the animation tree
		pass

		print("Dodged with impulse: ", dodge_direction * parameters.dodge_impulse)
