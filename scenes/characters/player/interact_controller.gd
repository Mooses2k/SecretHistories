extends Node

const PickupResolver := preload("res://scenes/characters/player/pickup_resolver.gd")


enum InteractState {
	NONE,
	PENDING,
	GRAB,
	ADS,
	HOLD_INTERACT
}
@export var inventory : Inventory

# Shapecast pickup zone (issue #736): a sphere anchored at the GrabCast hit
# point (ray end in open air) finds pickup candidates instead of requiring an
# exact ray hit on the item's collision shape. Mask is physics layer 7
# ItemDrops, where dropped PickableItems live (project.godot layer names).
const ITEM_DROPS_MASK : int = 1 << 6
const MAX_PICKUP_HITS : int = 32
@export var pickup_shapecast_radius : float = 0.35
# Tiny items (ammo, coins, keys) get a larger pickup zone and a Receiver-style
# same-kind group radius (issue #735). The group radius is one grid cell (the
# project grid unit is 1.5 m) plus margin: a spilled pile vacuums, the next
# room does not.
@export var tiny_pickup_shapecast_radius : float = 0.75
@export var tiny_group_pickup_radius : float = 2.0

# Releasing the interact key before this time will cause an interaction, holding
# it longer will attempt a grab
@export var interact_threshold : float = 0.2

# Damping parameters for non-heavy grabbed objects
@export var light_object_mass_threshold : float = 30.0  # kg - objects below this get damping
@export var linear_damping_factor : float = 4.0
@export var rotational_damping_factor : float = 2.0
@export var mass_damping_scale : float = 1.0  # How much mass affects damping (0.0-1.0)

# Camera-centered grab parameters
@export var grab_distance : float = 0.7  # Distance in front of camera to hold grabbed objects (meters)
@export var grab_distance_min : float = 0.3  # Minimum grab distance
@export var grab_distance_max : float = 1.5  # Maximum grab distance
@export var grab_distance_increment : float = 0.1  # How much to change grab distance per mousewheel step

# Rotation following parameters
@export var rotation_follow_enabled : bool = true
@export var rotation_deadband : float = 0.1  # Minimum rotation difference to apply torque (radians)
@export var rotation_torque_multiplier : float = 10.0  # Base torque strength
@export var max_rotation_torque : float = 20.0  # Maximum torque to prevent instability

var _interaction_held_timer : float = 0.0
var _holding_interact : bool = false

var interact_state : InteractState = InteractState.NONE

var grabbed_item : RigidBody3D = null
# Pre-grab physics values, captured at grab start and restored on release
# (Brooks audit 3.1): the reset used to assume authored damp was 0.0.
var pre_grab_linear_damp : float = 0.0
var pre_grab_angular_damp : float = 0.0
var pre_grab_gravity_scale : float = 1.0
# Where the object was grabbed, relative to the object
var grab_position_object : Vector3
# Where the object was grabbed, relative to the raycast
var grab_position_raycast : Vector3
# Initial rotation relationship between grabbed object and grab cast
var grab_rotation_offset : Quaternion

var interact_target : Interactable = null
var grab_target : RigidBody3D = null
var pick_target : PickableItem = null
# Additive ADS trigger state (issue #606): true while the separately bound
# ads action is held, so ADS stays engaged until both sources release.
var _ads_action_held : bool = false
# Door (or other hold-follow target) currently being dragged; fed the camera
# ray every physics frame until the interact key is released
var _hold_follow_target : Node = null

# Captured grab target and collision point when interact button is first pressed
var captured_grab_target : RigidBody3D = null

# Deferred same-kind group pickup state (issue #735): the kind key and center
# are captured at pick time, the radius query runs on the next physics tick.
var _pending_group_data : Resource = null
var _pending_group_key_id : int = -1
var _pending_group_center := Vector3.ZERO

@onready var interaction_cast: RayCast3D = $"../../ModelRoot/MainCamera/InteractionCast"
@onready var grab_cast: RayCast3D = $"../../ModelRoot/MainCamera/GrabCast"
@onready var player_controller: PlayerController = $".."
@onready var near_cast: Area3D = $"../../ModelRoot/MainCamera/NearCast"


func _process(delta: float) -> void:
	interaction_cast.force_raycast_update()
	interact_target = interaction_cast.get_collider() as Interactable
	grab_cast.force_raycast_update()
	grab_target = grab_cast.get_collider() as RigidBody3D

	# If we don't have a grab_target but we have an ignite area, check if its parent is grabbable
	if grab_target == null and is_instance_valid(interact_target) and interact_target.is_in_group(&"IGNITE"):

		# The ignite area is typically a child Area3D of a RigidBody3D (like a candle)
		# So we need to check if the parent is a RigidBody3D
		var interact_node = interact_target as Node
		if interact_node and interact_node.get_parent() is RigidBody3D:
			grab_target = interact_node.get_parent() as RigidBody3D
	#TODO: move this code to the gui instead, and make near cast behave like kick
	GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.NONE

	if pick_target:
		GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.GRAB
	elif grab_target or interact_target:
		# Per-target override first (the floor candelabra take is a GRAB), then
		# the group default: ignite areas show the ignite cursor.
		var target_indicator : HUD.Indicator = HUD.Indicator.DOT
		if is_instance_valid(interact_target):
			if interact_target.indicator_override >= 0:
				target_indicator = interact_target.indicator_override as HUD.Indicator
			elif interact_target.is_in_group(&"IGNITE"):
				target_indicator = HUD.Indicator.IGNITE
		GameManager.game.ui_root.hud_root.active_indicator = target_indicator
	if GameManager.game.ui_root.hud_root.active_indicator == HUD.Indicator.NONE:
		for body in near_cast.get_overlapping_bodies():
			if body is RigidBody3D:
				GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.DOT
				break
	if GameManager.game.ui_root.hud_root.active_indicator == HUD.Indicator.NONE:
		for area in near_cast.get_overlapping_areas():
			if area is Interactable:
				GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.DOT
				break

	if interact_state == InteractState.PENDING:
		_interaction_held_timer += delta
		if _interaction_held_timer > interact_threshold and grabbed_item == null:
			# Hold-to-interact targets (doors #17, Amnesia style): fire once on
			# the hold, then keep feeding the drag every frame until release
			if captured_grab_target == null and is_instance_valid(interact_target) and interact_target.hold_interact:
				interact_target.interact_press_was_hold = true
				interact_target.interact(owner)
				if interact_target.has_method(&"interact_hold_update"):
					_hold_follow_target = interact_target
					interact_state = InteractState.HOLD_INTERACT
				else:
					interact_state = InteractState.NONE
				return
			if not _try_grab_captured():
				player_controller.set_ads(true)
				interact_state = InteractState.ADS


func _unhandled_input(event: InputEvent) -> void:
	# Additive triggers (issue #606): the kick, interact and ads actions
	# ship unbound, so when nothing is bound these events never match and
	# the contextual RMB/Shift paths remain the sole behavior.
	if event.is_action_pressed(&"kick"):
		_kick_from_action()
	if event.is_action_pressed(&"interact"):
		_tap_interact_from_action()
	if event.is_action_pressed(&"ads"):
		_ads_action_pressed()
	elif event.is_action_released(&"ads"):
		_ads_action_released()
	# Handle mousewheel for grab distance adjustment when grabbing
	if interact_state == InteractState.GRAB:
		if event.is_action_pressed(&"itm|next_hotbar_item"):
			grab_distance = clamp(grab_distance + grab_distance_increment, grab_distance_min, grab_distance_max)
			get_viewport().set_input_as_handled()  # Prevent hotbar switching
			return
		elif event.is_action_pressed(&"itm|previous_hotbar_item"):
			grab_distance = clamp(grab_distance - grab_distance_increment, grab_distance_min, grab_distance_max)
			get_viewport().set_input_as_handled()  # Prevent hotbar switching
			return

	if event.is_action_pressed(&"player|interact"):
		if not (interact_target or grab_target or pick_target):
			interact_state = InteractState.ADS
			player_controller.set_ads(true)
		else:
			# Arbitration rule (issue #736): a tap always prefers the shapecast
			# pickup, and a tiny item (ammo, coin, key) under the crosshair
			# always wins pickup, so tiny and key candidates block hold-to-grab
			# capture. Equipment keeps the timing split: tap picks it, holding
			# drags it. Dragging therefore still works for everything else:
			# tables, statues, and doors never become pickup candidates, and a
			# player aiming to drag a table aims at a spot with no tiny
			# candidate inside the pickup zone.
			if pick_target == null or not PickupResolver.outranks_drag(pick_target):
				# Store the grab target and collision point that were under crosshair when button was FIRST pressed
				captured_grab_target = grab_target

				# Special case: if we're pointing at an ignite area but no grab_target,
				# check if the ignite area's parent is grabbable
				if captured_grab_target == null and is_instance_valid(interact_target) and interact_target.is_in_group(&"IGNITE"):
					var interact_node = interact_target as Node
					if interact_node and interact_node.get_parent() is RigidBody3D:
						captured_grab_target = interact_node.get_parent() as RigidBody3D

			interact_state = InteractState.PENDING
			_interaction_held_timer = 0.0
	elif event.is_action_released(&"player|interact"):
		match interact_state:
			InteractState.ADS:
				if _ads_action_held:
					# The separately bound ads key keeps ADS held; it owns
					# the disengage when it releases (issue #606).
					_holding_interact = false
					return
				player_controller.set_ads(false)
			InteractState.GRAB:
				# Special handling for wall objects
				if grabbed_item and grabbed_item.has_method("release_by_player"):
					grabbed_item.release_by_player(player_controller)

				_reset_object_damping(grabbed_item)
				grabbed_item = null
				player_controller.set_drag_speed_modifier(1.0)
			InteractState.HOLD_INTERACT:
				# Release ends the door drag; the leaf keeps its momentum
				if is_instance_valid(_hold_follow_target) and _hold_follow_target.has_method(&"interact_hold_end"):
					_hold_follow_target.interact_hold_end()
				_hold_follow_target = null
			InteractState.PENDING:
				if pick_target:
					pick_item()
				elif is_instance_valid(interact_target) and interact_target.hold_interact:
					# Quick tap on a hold-interact target: still delivered, the
					# target itself decides that a tap does nothing (locked
					# doors rattle on tap, normal doors ignore it)
					interact_target.interact_press_was_hold = false
					interact()
				else:
					interact()
		interact_state = InteractState.NONE
		_holding_interact = false
	elif (
		event.is_action_pressed(&"playerhand|mainhand_throw")
		or event.is_action_pressed(&"playerhand|offhand_throw")
	):
		if interact_state == InteractState.GRAB:
			interact_state = InteractState.NONE
			var item_to_throw = grabbed_item

			# Special handling for wall objects
			if item_to_throw and item_to_throw.has_method("release_by_player"):
				item_to_throw.release_by_player(player_controller)

			_reset_object_damping(item_to_throw)
			grabbed_item = null
			player_controller.set_drag_speed_modifier(1.0)
			player_controller.throw_object(item_to_throw)
			get_viewport().set_input_as_handled()


func _try_grab_captured() -> bool:
	if is_instance_valid(captured_grab_target):
		grabbed_item = captured_grab_target

		# Capture the item's authored physics values before any damping change
		pre_grab_linear_damp = grabbed_item.linear_damp
		pre_grab_angular_damp = grabbed_item.angular_damp
		pre_grab_gravity_scale = grabbed_item.gravity_scale

		grab_position_object = grabbed_item.to_local(grab_cast.get_collision_point())
		grab_position_raycast = grab_cast.to_local(grab_cast.get_collision_point())

		# CAMERA-CENTERED: No need to store grab positions or collision points
		# Object will be pulled to camera center regardless of where it was initially grabbed

		# Store the initial rotation relationship between the object and the grab cast
		grab_rotation_offset = grab_cast.global_transform.basis.get_rotation_quaternion().inverse() * grabbed_item.global_transform.basis.get_rotation_quaternion()

		# Special handling for wall objects
		if grabbed_item.has_method("grab_by_player"):
			grabbed_item.grab_by_player(player_controller)

		interact_state = InteractState.GRAB
		return true
	return false


func _physics_process(delta: float) -> void:
	_update_pick_target()
	_collect_pending_tiny_group()
	# Feed the held door drag: the camera ray steers the hinge every frame
	if interact_state == InteractState.HOLD_INTERACT and is_instance_valid(_hold_follow_target):
		_hold_follow_target.interact_hold_update(interaction_cast.global_position, -interaction_cast.global_transform.basis.z)

	if is_instance_valid(grabbed_item):
		var difference : Vector3

		# Old method that works well with large objects
		var point_object := grabbed_item.to_global(grab_position_object)
		if grabbed_item is LargeObject:
			var point_raycast := grab_cast.to_global(grab_position_raycast)
			difference = point_raycast - point_object

		# CAMERA-CENTERED APPROACH: Pull object toward camera center instead of maintaining grab offset
		else:
			var desired_position = grab_cast.global_position + (-grab_cast.global_transform.basis.z * grab_distance)
			difference = desired_position - grabbed_item.global_position
		# Avoid taking impact damage from items the player is carrying
		if grabbed_item is PickableItem:
			grabbed_item.impact_damage_cooldown[owner] = PickableItem.IMPACT_DAMAGE_REPEAT_COOLDOWN

		# Calculate mass-based force scaling
		var mass = grabbed_item.mass

		# Local damping factors for this grab (Brooks audit 3.1): very light
		# objects get stronger damping via locals only. Assigning the exported
		# members here kept the 8.0 override for every later grab in the session.
		var linear_damp_factor : float = linear_damping_factor
		var rotational_damp_factor : float = rotational_damping_factor
		if mass < 0.5:
			linear_damp_factor = 8.0
			rotational_damp_factor = 8.0
		var base_force_multiplier = 100.0
		var temp_mass_threshold = light_object_mass_threshold
		var max_force_limit = 200.0

		# Scale force based on mass for heavy objects
		var force_multiplier = base_force_multiplier
		if mass > temp_mass_threshold:
			# Increase force multiplier for heavy objects
			var mass_factor = 1.0 + (mass - temp_mass_threshold) / temp_mass_threshold
			force_multiplier = base_force_multiplier * mass_factor * 1.5  # Additional boost for heavy objects
			max_force_limit = 200.0 + (mass - temp_mass_threshold) * 4.6  # Higher limit for heavy objects

		var force = (difference * mass * force_multiplier)
		force = force.limit_length(max_force_limit)

		# Apply force to object center instead of specific grab point
		grabbed_item.apply_force(force, point_object - grabbed_item.global_position)

		# Apply rotational forces to make object follow player's orientation
		if rotation_follow_enabled:
			var desired_rotation := grab_cast.global_transform.basis.get_rotation_quaternion() * grab_rotation_offset
			var current_rotation := grabbed_item.global_transform.basis.get_rotation_quaternion()
			var rotation_difference := desired_rotation * current_rotation.inverse()

			# Convert quaternion difference to angular velocity
			var rotation_axis := Vector3.ZERO
			var rotation_angle := 0.0
			if abs(rotation_difference.w) < 0.999:  # Only process if there's meaningful rotation
				rotation_angle = 2.0 * acos(clamp(abs(rotation_difference.w), 0.0, 1.0))
				var sin_half_angle := sin(rotation_angle * 0.5)
				if sin_half_angle > 0.001:  # Avoid division by zero
					rotation_axis = Vector3(rotation_difference.x, rotation_difference.y, rotation_difference.z) / sin_half_angle
					if rotation_difference.w < 0.0:
						rotation_axis = -rotation_axis

			# Apply rotational torque with deadband and safety limits
			if rotation_angle > rotation_deadband:
				# Use mass-based scaling similar to the damping system
				var mass_factor: float = clamp(mass / light_object_mass_threshold, 0.01, 1.0)

				# Scale torque inversely with mass for light objects, but proportionally for heavy ones
				var base_torque := rotation_torque_multiplier
				if mass < 0.5:
					base_torque = 0.01
				if mass <= light_object_mass_threshold:
					# Light objects: reduce torque significantly and use mass_damping_scale
					base_torque *= mass_factor * (1.0 - mass_damping_scale) + mass_damping_scale #* 0.1
				else:
					# Heavy objects: scale torque up but with diminishing returns
					base_torque *= sqrt(mass / light_object_mass_threshold)

				# Calculate torque with angle-based scaling (stronger for larger differences)
				var angle_factor: float = clamp(rotation_angle / PI, 0.1, 1.0)  # Scale from 0.1 to 1.0
				var torque: Vector3 = rotation_axis * angle_factor * base_torque

				# Apply maximum torque limit that scales with mass
				var mass_adjusted_max_torque := max_rotation_torque
				if mass <= light_object_mass_threshold:
					# Much lower max torque for light objects
					mass_adjusted_max_torque *= mass_factor #* 0.5
				else:
					# Higher max torque for heavy objects
					mass_adjusted_max_torque *= clamp(mass / light_object_mass_threshold, 1.0, 3.0)

				torque = torque.limit_length(mass_adjusted_max_torque)

				grabbed_item.apply_torque(torque)

		# Apply movement speed reduction based on mass
		var speed_reduction_factor = 1.0
		if mass > temp_mass_threshold:
			# Calculate speed reduction: heavier objects = more reduction
			var mass_ratio = mass / 100.0  # Normalize against 100kg reference
			speed_reduction_factor = clamp(1.0 - mass_ratio * 0.6, 0.2, 1.0)  # Min 20% speed
			speed_reduction_factor = max(speed_reduction_factor, 0.2)  # Ensure minimum 20% speed

		# Apply speed reduction to player controller
		player_controller.set_drag_speed_modifier(speed_reduction_factor)

		# Apply damping to non-heavy objects
		if mass <= light_object_mass_threshold:
			var mass_factor = clamp(mass / light_object_mass_threshold, 0.01, 1.0)
			var scaled_linear_damp = linear_damp_factor * (1.0 - mass_factor * mass_damping_scale)
			var scaled_rotational_damp = rotational_damp_factor * (1.0 - mass_factor * mass_damping_scale)

			# Ensure minimum damping values
			scaled_linear_damp = max(scaled_linear_damp, 0.01)
			scaled_rotational_damp = max(scaled_rotational_damp, 0.01)

			# Apply damping
			grabbed_item.linear_damp = scaled_linear_damp
			grabbed_item.angular_damp = scaled_rotational_damp

	elif interact_state == InteractState.GRAB:
		interact_state = InteractState.NONE
		# Reset movement speed when not dragging
		player_controller.set_drag_speed_modifier(1.0)

	# Safety check: if grabbed_item becomes invalid, reset drag speed modifier
	if not is_instance_valid(grabbed_item) and interact_state != InteractState.GRAB:
		player_controller.set_drag_speed_modifier(1.0)


func pick_item() -> void:
	if is_instance_valid(pick_target):
		print("pick")
		var anchor := pick_target
		pick_target = null
		_capture_tiny_group(anchor)
		inventory.add_item(anchor)


# Group pickup (issue #735): the anchor's kind and position are captured here
# because add_item frees the anchor node; the radius query runs on the next
# physics tick, where direct space state queries are safe.
func _capture_tiny_group(anchor : PickableItem) -> void:
	var tiny := anchor as TinyItem
	if tiny != null:
		_pending_group_data = tiny.item_data
	else:
		var key := anchor as KeyItem
		if key != null:
			_pending_group_key_id = key.key_id
	if _pending_group_data == null and _pending_group_key_id < 0:
		return
	_pending_group_center = anchor.global_position


func _collect_pending_tiny_group() -> void:
	if _pending_group_data == null and _pending_group_key_id < 0:
		return
	var data : Resource = _pending_group_data
	var key_id : int = _pending_group_key_id
	_pending_group_data = null
	_pending_group_key_id = -1
	var space_state := grab_cast.get_world_3d().direct_space_state
	var bodies : Array = []
	for hit in _sphere_query(space_state, _pending_group_center, tiny_group_pickup_radius):
		bodies.append(hit["collider"])
	for item in PickupResolver.filter_pick_candidates(bodies, inventory):
		if PickupResolver.matches_group_kind(item, data, key_id):
			inventory.add_item(item)


# Shapecast-based pickup detection (issue #736). Runs on the physics tick,
# where direct space state queries are safe. The zone centers on the GrabCast
# hit point, so it follows whatever the player is aiming at; in open air it
# centers on the ray end.
func _update_pick_target() -> void:
	var space_state := grab_cast.get_world_3d().direct_space_state
	var ray_origin := grab_cast.global_position
	var ray_direction := -grab_cast.global_transform.basis.z
	var ray_length : float = grab_cast.target_position.length()
	var anchor := ray_origin + ray_direction * ray_length
	if grab_cast.is_colliding():
		anchor = grab_cast.get_collision_point()

	var bodies : Array = []
	for hit in _sphere_query(space_state, anchor, pickup_shapecast_radius):
		bodies.append(hit["collider"])
	var candidates : Array[PickableItem] = PickupResolver.filter_pick_candidates(bodies, inventory)

	# Tiny/key candidates come from a second, larger zone (issue #735); the
	# ranking over the union keeps the closest-to-crosshair item winning.
	var tiny_bodies : Array = []
	for hit in _sphere_query(space_state, anchor, tiny_pickup_shapecast_radius):
		tiny_bodies.append(hit["collider"])
	candidates.append_array(PickupResolver.filter_pick_candidates(tiny_bodies, inventory, true))

	pick_target = PickupResolver.select_best(candidates, ray_origin, ray_direction)


func _sphere_query(space_state : PhysicsDirectSpaceState3D, center : Vector3, radius : float) -> Array:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = ITEM_DROPS_MASK
	params.collide_with_bodies = true
	params.collide_with_areas = false
	return space_state.intersect_shape(params, MAX_PICKUP_HITS)


func interact() -> void:
	if is_instance_valid(interact_target):
		print("interact")
		interact_target.interact(owner)


## Additive kick trigger (issue #606): a separately bound kick key fires
## alongside the contextual path (sprint tapped without moving, wired in
## player_controller.gd). Both paths share the single execution point
## HumanoidCharacter.kick(), whose cooldown guard blocks the second call,
## and this side skips the attempt outright when a kick already ran within
## the cooldown, so a same frame double trigger kicks once.
func _kick_from_action() -> void:
	var character := owner as HumanoidCharacter
	if character == null:
		return
	if character.state.time_since_kick < character.parameters.kick_cooldown:
		return
	# from_action: the separately bound kick key is its own trigger and is
	# never gated by the Shift overload settings (wiki Interface 5.2.1).
	character.kick(true)


## Additive interact trigger (issue #606): a separately bound interact key
## fires the RMB tap semantics on press: the shapecast pickup first (the
## issue #736 arbitration), then the target's interact. Hold and grab
## behaviors stay exclusive to the RMB context path.
func _tap_interact_from_action() -> void:
	if pick_target:
		pick_item()
		return
	if is_instance_valid(interact_target) and interact_target.hold_interact:
		interact_target.interact_press_was_hold = false
	interact()


## Additive ADS trigger (issue #606): the ads action engages the same
## InteractState.ADS as the RMB hold on empty air, and ADS disengages only
## when both the contextual hold and the ads action are released.
func _ads_action_pressed() -> void:
	_ads_action_held = true
	if interact_state != InteractState.NONE:
		return
	if interact_target or grab_target or pick_target:
		return
	interact_state = InteractState.ADS
	player_controller.set_ads(true)


func _ads_action_released() -> void:
	_ads_action_held = false
	if interact_state != InteractState.ADS:
		return
	if Input.is_action_pressed(&"player|interact"):
		return
	interact_state = InteractState.NONE
	player_controller.set_ads(false)


# Helper function to reset object damping when released
func _reset_object_damping(item: RigidBody3D) -> void:
	if is_instance_valid(item):
		print("INTERACT DEBUG - Resetting damping for: ", item.name, ". Before reset - Linear: ", item.linear_damp, " Angular: ", item.angular_damp)

		# Restore the item's pre-grab physics values (captured in _try_grab_captured)
		item.linear_damp = pre_grab_linear_damp
		item.angular_damp = pre_grab_angular_damp
		item.gravity_scale = pre_grab_gravity_scale

		print("INTERACT DEBUG - After reset - Linear: ", item.linear_damp, " Angular: ", item.angular_damp)
