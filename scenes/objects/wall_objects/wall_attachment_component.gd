@tool
class_name WallAttachmentComponent
extends Node3D

## Component for objects that can be attached to walls
## Handles wall mounting, physics attachment, and breakaway mechanics
## Position this node at the exact attachment point on the wall object
## Can be added to any PhysicsBody3D (RigidBody3D, SoftBody3D, StaticBody3D)

### Member Variables and Dependencies -------------------------------------------------------------

#--- signals --------------------------------------------------------------------------------------
signal attached_to_wall(mount: StaticBody3D)
signal detached_from_wall(mount: StaticBody3D, is_temporary: bool)
signal breakaway_triggered(force: float)
signal ready_for_reattachment(mount: StaticBody3D)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Wall direction this object is attached to (set by spawn system)
@export var wall_direction: int = -1

## Force threshold needed to break from wall attachment
@export var breakaway_force_threshold: float = 25.0  # Higher threshold to prevent immediate breakaway

## Maximum distance before automatic breakaway (prevents infinite stretching)
@export var max_stretch_distance: float = 0.4  # 40cm max stretch before breaking

## Force accumulation threshold (prevents single-frame spikes from breaking attachment)
@export var force_accumulation_threshold: float = 3.0  # Higher threshold to prevent false triggers
var accumulated_breakaway_force: float = 0.0

## Whether this object should automatically setup wall attachment on ready
@export var auto_setup_attachment: bool = true

## Distance threshold for magnetic pull effect (larger zone for attraction)
@export var magnetic_pull_distance: float = 0.3

## Distance threshold for actual re-attachment (smaller zone for precision)
@export var reattachment_distance: float = 0.05

var orientation_threshold = 0.5  # DEBUG: This should be > 0.0 to prevent front-facing attachment!

## Strength of magnetic pull (higher = stronger pull)
@export var magnetic_pull_strength: float = 4.0  # Increased for stronger attraction

## Speed of smooth lerp movement when snapping
@export var snap_lerp_speed: float = 12.0  # Increased for faster snapping


#--- private variables - order: export > normal var > onready -------------------------------------

## Reference to the wall mount (StaticBody3D)
var wall_mount: StaticBody3D = null

## Joint connecting this object to the wall mount
var attachment_joint: Joint3D = null

## Whether this object is currently attached to a wall
var is_attached_to_wall: bool = false

## Original rotation when attached to wall (for magnetic orientation correction)
var original_wall_rotation: Quaternion = Quaternion.IDENTITY

## Timer for checking re-attachment proximity
var reattachment_timer: Timer = null

## Timer for monitoring breakaway forces
var breakaway_monitor_timer: Timer = null

## Whether magnetic pull is currently active
var is_magnetic_pull_active: bool = false

## Original material of the parent object (for restoring after feedback)
var original_materials: Array[Material] = []

## MeshInstance3D nodes for applying visual feedback
var mesh_instances: Array[MeshInstance3D] = []

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	# Ensure we're attached to a PhysicsBody3D
	if not (get_parent() is PhysicsBody3D):
		push_error("WallAttachmentComponent must be child of a PhysicsBody3D")
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	
	# Cache mesh instances for visual feedback
	_cache_mesh_instances()
	
	if auto_setup_attachment and wall_direction != -1:
		call_deferred("_setup_wall_attachment")
	
	# Connect to physics signals for breakaway detection if parent supports them
	if parent_body.has_signal("body_entered"):
		parent_body.body_entered.connect(_on_body_entered)
	if parent_body.has_signal("sleeping_state_changed"):
		parent_body.sleeping_state_changed.connect(_on_sleeping_state_changed)


func _physics_process(delta: float):
	# Handle magnetic pull when detached
	if not is_attached_to_wall and _is_in_magnetic_range() and wall_mount:
		# DEBUG: Check if parent is being grabbed by player
		var parent_body = get_parent() as PhysicsBody3D
		var is_being_grabbed = false
		if parent_body and parent_body.has_method("get_attachment_status"):
			var wall_object = parent_body as WallObjectRigid
			is_being_grabbed = wall_object.is_grabbed
		
		if parent_body and parent_body is RigidBody3D:
			var rigid_body = parent_body as RigidBody3D
			
			# CRITICAL FIX: Check orientation BEFORE applying magnetic pull
			var object_backward = rigid_body.global_transform.basis.z  # +Z axis in global space
			var direction_to_mount = (wall_mount.global_position - rigid_body.global_position).normalized()
			var alignment = object_backward.dot(direction_to_mount)
			
			# DEBUG: Log magnetic zone orientation check
			print("MAGNETIC ZONE DEBUG - Distance: ", snappedf(rigid_body.global_position.distance_to(wall_mount.global_position), 0.01))
			print("MAGNETIC ZONE DEBUG - Alignment: ", snappedf(alignment, 0.01), " Threshold: ", orientation_threshold)
			print("MAGNETIC ZONE DEBUG - Object +Z (backward): ", object_backward)
			print("MAGNETIC ZONE DEBUG - Direction to mount: ", direction_to_mount)
			print("MAGNETIC ZONE DEBUG - Should activate magnetic zone: ", alignment > orientation_threshold)
			
			# Only proceed with magnetic pull if orientation is correct
			if alignment > orientation_threshold:
				# Calculate direction to wall mount
				var direction = (wall_mount.global_position - rigid_body.global_position).normalized()
				var distance = rigid_body.global_position.distance_to(wall_mount.global_position)
				
				# Apply magnetic pull force (stronger when closer to magnetic zone edge)
				var pull_strength = magnetic_pull_strength * (1.0 - (distance / magnetic_pull_distance))
				
				# Use physics forces instead of direct position manipulation to prevent yo-yoing
				var pull_force = direction * pull_strength * rigid_body.mass * 10.0  # Scale up for physics forces
				
				# Only apply if we're not extremely close (reduced dead zone for precision)
				if distance > 0.01:  # Reduced from 0.05 to 0.01 for pixel-perfect precision
					# Apply force at center of mass for stable physics
					rigid_body.apply_central_force(pull_force)
					
					# Progressive velocity damping - stronger when closer to prevent overshoot
					var damping_factor = 1.0 - (pull_strength * 0.1)  # More damping when pull is stronger
					rigid_body.linear_velocity *= damping_factor
				
				# Apply magnetic orientation correction when close enough AND reasonably well-oriented
				if distance <= reattachment_distance * 1.5:  # Start orienting when 1.5x reattachment distance
					print("MAGNETIC DEBUG - Alignment: ", snappedf(alignment, 0.01), " Threshold: ", orientation_threshold, " Will correct: ", alignment > orientation_threshold)
					_apply_magnetic_orientation_correction(rigid_body, delta, pull_strength)
			else:
				print("MAGNETIC ZONE DEBUG - BLOCKED magnetic pull due to wrong orientation (front facing wall)")

### Public Methods --------------------------------------------------------------------------------

## Setup wall attachment system (called manually if needed)
func setup_wall_attachment():
	_setup_wall_attachment()


## Manually detach from wall (e.g., when grabbed by player)
func detach_from_wall():
	if is_attached_to_wall:
		_detach_from_wall()


## Attempt to re-attach to wall mount (called when player places object back)
func try_reattach_to_wall() -> bool:
	if is_attached_to_wall or not wall_mount:
		return false
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return false
	
	# Check if object is close enough to mount
	var distance = parent_body.global_position.distance_to(wall_mount.global_position)
	if distance <= reattachment_distance:
		_reattach_to_wall()
		parent_body.angular_damp = 0.1  # To stop long-time swinging
		return true
	
	return false


## Check if object can be re-attached (close to mount and properly oriented)
func can_reattach_to_wall() -> bool:
	if is_attached_to_wall or not wall_mount:
		return false
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return false
	
	var distance = parent_body.global_position.distance_to(wall_mount.global_position)
	if distance > reattachment_distance:
		return false
	
	# Check orientation - the wall object's +Z axis (backward) should face toward the wall mount
	var object_backward = parent_body.global_transform.basis.z  # +Z axis in global space
	var direction_to_mount = (wall_mount.global_position - parent_body.global_position).normalized()
	
	# Calculate dot product to check alignment (should be positive for correct orientation)
	var alignment = object_backward.dot(direction_to_mount)
	
	# DEBUG: Log orientation check
	print("ORIENTATION DEBUG - Alignment: ", snappedf(alignment, 0.01), " Threshold: ", orientation_threshold, " Valid: ", alignment > orientation_threshold)
	
	return alignment > orientation_threshold


## Check if object can be attached to wall
func can_attach_to_wall() -> bool:
	return wall_direction != -1 and not is_attached_to_wall


## Check if object is in magnetic pull range
func _is_in_magnetic_range() -> bool:
	if not wall_mount:
		print("MAGNETIC RANGE DEBUG - No wall mount")
		return false
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		print("MAGNETIC RANGE DEBUG - No parent body")
		return false
	
	var distance = parent_body.global_position.distance_to(wall_mount.global_position)
	var in_range = distance <= magnetic_pull_distance
	print("MAGNETIC RANGE DEBUG - Distance: ", snappedf(distance, 0.01), " Threshold: ", magnetic_pull_distance, " In range: ", in_range)
	return in_range

### Private Methods -------------------------------------------------------------------------------

func _setup_wall_attachment():
	if not can_attach_to_wall():
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		push_error("Cannot setup wall attachment - parent is not a PhysicsBody3D")
		return
	
	# Ensure physics is stable before creating attachment
	if parent_body is RigidBody3D:
		var rigid_body = parent_body as RigidBody3D
		# Stop any existing motion
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
		# Temporarily disable gravity during attachment setup
		rigid_body.gravity_scale = 0.0
	
	_create_wall_mount()
	await _create_attachment_joint()  # Wait for joint creation to complete
	
	# Re-enable gravity after attachment is established
	if parent_body is RigidBody3D:
		var rigid_body = parent_body as RigidBody3D
		rigid_body.gravity_scale = 1.0
	
	is_attached_to_wall = true
	
	# Store the original rotation for magnetic orientation correction
	original_wall_rotation = parent_body.global_transform.basis.get_rotation_quaternion()
	
	_setup_reattachment_monitoring()
	
	attached_to_wall.emit(wall_mount)


func _create_wall_mount():
	var parent_body = get_parent() as PhysicsBody3D
	
	# Create invisible StaticBody3D as wall mount
	wall_mount = StaticBody3D.new()
	wall_mount.name = "WallMount_%s" % parent_body.name
	
	# Add to scene first
	var scene_parent = parent_body.get_parent()
	scene_parent.add_child(wall_mount)
	
	# Position mount at this component's position AFTER adding to scene
	# Ensure the mount is at the exact attachment point
	wall_mount.global_position = global_position


func _create_attachment_joint():
	if not wall_mount:
		push_error("No wall mount found for joint creation")
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	
	# Ensure both bodies are properly positioned before creating joint
	await get_tree().process_frame
	
	# Choose joint type based on parent body type
	if parent_body is RigidBody3D:
		# PinJoint3D for natural swinging motion (paintings)
		attachment_joint = PinJoint3D.new()
		attachment_joint.name = "WallAttachmentJoint"
		
		# Add joint to scene first to establish proper node paths
		var scene_parent = parent_body.get_parent()
		scene_parent.add_child(attachment_joint)
		
		# Position joint at the attachment point (this component's position)
		attachment_joint.global_position = global_position
		
		# Configure joint with absolute node references
		attachment_joint.node_a = attachment_joint.get_path_to(wall_mount)
		attachment_joint.node_b = attachment_joint.get_path_to(parent_body)
		
		# DEBUG: Check if PinJoint3D has damping parameters
		print("JOINT DEBUG - PinJoint3D created, checking for damping parameters...")
		
		# Force the painting to the exact wall mount position
		parent_body.global_position = wall_mount.global_position
		
	elif parent_body is SoftBody3D:
		# Generic6DOFJoint3D for soft body flexibility (tapestries)
		attachment_joint = Generic6DOFJoint3D.new()
		attachment_joint.name = "WallAttachmentJoint"
		
		# Add joint to scene first
		var scene_parent = parent_body.get_parent()
		scene_parent.add_child(attachment_joint)
		
		# Position joint at attachment point
		attachment_joint.global_position = global_position
		
		# Configure joint with absolute node references
		attachment_joint.node_a = attachment_joint.get_path_to(wall_mount)
		attachment_joint.node_b = attachment_joint.get_path_to(parent_body)
		
		# Allow some movement but constrain to wall
		attachment_joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		attachment_joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		attachment_joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		
		# Set tight limits to keep close to wall
		attachment_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.1)
		attachment_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.1)
		attachment_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.1)
		attachment_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.1)
		attachment_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.1)
		attachment_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.1)
		
	elif parent_body is StaticBody3D:
		# No joint needed for StaticBody3D - they're already static
		# Just position them correctly
		parent_body.global_position = wall_mount.global_position
		return


func _detach_from_wall():
	if not is_attached_to_wall:
		return
	
	var old_mount = wall_mount
	var parent_body = get_parent() as PhysicsBody3D
	
	print("JOINT DEBUG - Detaching, parent damping before: Linear=", parent_body.linear_damp, " Angular=", parent_body.angular_damp)
	
	# Remove joint but keep mount for re-attachment
	if attachment_joint and is_instance_valid(attachment_joint):
		attachment_joint.queue_free()
		attachment_joint = null
	
	is_attached_to_wall = false
	
	print("JOINT DEBUG - After joint removal, parent damping: Linear=", parent_body.linear_damp, " Angular=", parent_body.angular_damp)
	
	# Start monitoring for re-attachment
	_start_reattachment_monitoring()
	
	detached_from_wall.emit(old_mount, false)


func _reattach_to_wall():
	if is_attached_to_wall or not wall_mount:
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return
	
	print("JOINT DEBUG - Reattaching, parent damping before: Linear=", parent_body.linear_damp, " Angular=", parent_body.angular_damp)
	
	# Position object at mount
	# Calculate offset from parent body to this component
	var component_offset = global_position - parent_body.global_position
	# Position parent body so that this component aligns with wall mount
	parent_body.global_position = wall_mount.global_position - component_offset
	
	# Recreate joint
	_create_attachment_joint()
	
	is_attached_to_wall = true
	
	print("JOINT DEBUG - After reattachment, parent damping: Linear=", parent_body.linear_damp, " Angular=", parent_body.angular_damp)
	
	# Stop monitoring for re-attachment
	_stop_reattachment_monitoring()
	
	attached_to_wall.emit(wall_mount)


func _setup_reattachment_monitoring():
	if not reattachment_timer:
		reattachment_timer = Timer.new()
		reattachment_timer.wait_time = 0.1  # Check every 100ms
		reattachment_timer.timeout.connect(_check_reattachment_proximity)
		add_child(reattachment_timer)
	
	# Setup breakaway force monitoring with less frequent checks to reduce instability
	if not breakaway_monitor_timer:
		breakaway_monitor_timer = Timer.new()
		breakaway_monitor_timer.wait_time = 0.2  # Check every 200ms - less frequent to avoid physics interference
		breakaway_monitor_timer.timeout.connect(_check_breakaway_force)
		add_child(breakaway_monitor_timer)
		breakaway_monitor_timer.start()  # Start monitoring immediately when attached


func _start_reattachment_monitoring():
	if reattachment_timer:
		reattachment_timer.start()


func _stop_reattachment_monitoring():
	if reattachment_timer:
		reattachment_timer.stop()
	
	# Stop breakaway monitoring when detached
	if breakaway_monitor_timer:
		breakaway_monitor_timer.stop()


func _check_reattachment_proximity():
	if is_attached_to_wall:
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body or not wall_mount:
		return
	
	var distance = parent_body.global_position.distance_to(wall_mount.global_position)
	var can_reattach = distance <= reattachment_distance
	var in_magnetic_range = distance <= magnetic_pull_distance
	
	# Handle magnetic pull
	if in_magnetic_range and not is_magnetic_pull_active:
		_start_magnetic_pull()
	elif not in_magnetic_range and is_magnetic_pull_active:
		_stop_magnetic_pull()
	
	# Auto-attachment when very close AND properly oriented
	if can_reattach:
		ready_for_reattachment.emit(wall_mount)
		# Auto-attach if object is released (not being actively moved) AND properly oriented
		if parent_body is RigidBody3D:
			var rigid_body = parent_body as RigidBody3D
			if rigid_body.linear_velocity.length() < 0.1:  # Object is nearly stationary
				# Double-check orientation before auto-attaching
				if can_reattach_to_wall():  # This includes the orientation check
					print("AUTO-ATTACH DEBUG - Auto-attaching with proper orientation")
					_reattach_to_wall()
				else:
					print("AUTO-ATTACH DEBUG - Blocked auto-attach due to wrong orientation")


## Get the rotation for the wall mount based on wall direction
func _get_wall_mount_rotation() -> Vector3:
	match wall_direction:
		WorldData.Direction.NORTH:
			return Vector3(0, 0, 0)
		WorldData.Direction.EAST:
			return Vector3(0, PI * 1.5, 0)
		WorldData.Direction.SOUTH:
			return Vector3(0, PI, 0)
		WorldData.Direction.WEST:
			return Vector3(0, PI * 0.5, 0)
		_:
			return Vector3.ZERO


## Cache mesh instances for visual feedback
func _cache_mesh_instances():
	mesh_instances.clear()
	original_materials.clear()
	
	var queue: Array[Node] = [get_parent()]
	while not queue.is_empty():
		var node = queue.pop_front()
		if node is MeshInstance3D:
			var mesh_instance = node as MeshInstance3D
			mesh_instances.append(mesh_instance)
			original_materials.append(mesh_instance.material_override)
		
		for child in node.get_children():
			queue.append(child)


## Start magnetic pull effect
func _start_magnetic_pull():
	is_magnetic_pull_active = true


## Stop magnetic pull effect
func _stop_magnetic_pull():
	is_magnetic_pull_active = false


func _check_breakaway_force():
	if not is_attached_to_wall or not attachment_joint:
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return
	
	# Only check breakaway for dynamic bodies
	if parent_body is RigidBody3D:
		var rigid_body = parent_body as RigidBody3D
		
		# Calculate distance from wall mount
		var distance_from_mount = rigid_body.global_position.distance_to(wall_mount.global_position)
		
		# Immediate breakaway if stretched too far (prevents infinite stretching)
		if distance_from_mount > max_stretch_distance:
			print("BREAKAWAY DEBUG - Distance breakaway triggered: ", distance_from_mount, " > ", max_stretch_distance)
			breakaway_triggered.emit(distance_from_mount * 20.0)  # High force value for distance breakaway
			_detach_from_wall()
			return
		
		# Calculate applied force using multiple factors
		var velocity_magnitude = rigid_body.linear_velocity.length()
		var angular_velocity_magnitude = rigid_body.angular_velocity.length()
		
		# More conservative force calculation to prevent immediate breakaway
		var velocity_force = velocity_magnitude * rigid_body.mass * 1.5  # Reduced multiplier
		# Only apply stretch force when significantly stretched (beyond normal joint distance)
		var stretch_ratio = max(0.0, (distance_from_mount - 0.15) / (max_stretch_distance - 0.15))  # Start stretch force at 15cm
		var stretch_force = pow(stretch_ratio, 2) * 12.0  # Reduced and delayed stretch force
		var angular_force = angular_velocity_magnitude * rigid_body.mass * 1.0  # Reduced rotational force
		var instantaneous_force = velocity_force + stretch_force + angular_force
		
		# Only accumulate force when there's significant movement or stretch
		if instantaneous_force > force_accumulation_threshold and (velocity_magnitude > 1.0 or stretch_ratio > 0.3):
			accumulated_breakaway_force += instantaneous_force * 0.15  # Slower accumulation rate
		else:
			# Faster decay when not under significant stress
			accumulated_breakaway_force = max(0.0, accumulated_breakaway_force - 3.0)  # Faster decay rate

		# Check accumulated force threshold for breakaway
		if accumulated_breakaway_force > breakaway_force_threshold:
			print("BREAKAWAY DEBUG - Accumulated force breakaway triggered: ", accumulated_breakaway_force, " > ", breakaway_force_threshold)
			breakaway_triggered.emit(accumulated_breakaway_force)
			_detach_from_wall()
	# SoftBody3D and StaticBody3D don't break away easily

### Signal Callbacks ------------------------------------------------------------------------------

func _on_body_entered(body):
	# Monitor for collisions that might cause breakaway
	if is_attached_to_wall:
		call_deferred("_check_breakaway_force")


func _on_sleeping_state_changed():
	# Check for breakaway when object stops moving
	var parent_body = get_parent() as PhysicsBody3D
	if is_attached_to_wall and parent_body is RigidBody3D:
		var rigid_body = parent_body as RigidBody3D
		if not rigid_body.sleeping:
			call_deferred("_check_breakaway_force")


## Apply magnetic orientation correction to gradually align object to original wall rotation
func _apply_magnetic_orientation_correction(rigid_body: RigidBody3D, delta: float, pull_strength: float):
	if original_wall_rotation == Quaternion.IDENTITY:
		return  # No original rotation stored
	
	# Get current rotation
	var current_rotation = rigid_body.global_transform.basis.get_rotation_quaternion()
	
	# The target rotation should simply be the original wall rotation (no multiplication needed)
	# The original_wall_rotation already contains the correct orientation for this wall
	var target_rotation = original_wall_rotation
	
	# Calculate rotation correction strength (stronger when closer and when pull is stronger)
	var distance = rigid_body.global_position.distance_to(wall_mount.global_position)
	var rotation_strength = pull_strength * snap_lerp_speed * delta * 1.0  # Reduced multiplier
	
	# DEBUG: Log rotation correction
	print("MAGNETIC DEBUG - Current: ", current_rotation, " Target: ", target_rotation, " Strength: ", snappedf(rotation_strength, 0.01))
	
	# Smoothly interpolate toward target rotation
	var corrected_rotation = current_rotation.slerp(target_rotation, rotation_strength)
	
	# Apply the corrected rotation
	rigid_body.global_transform.basis = Basis(corrected_rotation)
	
	# Dampen angular velocity to make rotation smoother
	rigid_body.angular_velocity *= 0.7
	
	# DEBUG: Log when magnetic orientation correction is applied
	print("WALL_ATTACHMENT DEBUG - Applied magnetic orientation correction to ", rigid_body.name)


## Get the rotation quaternion for the wall mount based on wall direction
func _get_wall_mount_rotation_quaternion() -> Quaternion:
	var rotation_vector = _get_wall_mount_rotation()
	return Quaternion.from_euler(rotation_vector)

### -----------------------------------------------------------------------------------------------
