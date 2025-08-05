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
signal should_show_wall_blueprint(mount_position: Vector3, mount_rotation: Vector3)
signal should_hide_wall_blueprint()

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Wall direction this object is attached to (set by spawn system)
@export var wall_direction: int = -1

## Force threshold needed to break from wall attachment
@export var breakaway_force_threshold: float = 5.0

## Whether this object should automatically setup wall attachment on ready
@export var auto_setup_attachment: bool = true

## Distance threshold for re-attachment detection
@export var reattachment_distance: float = 0.3

## Whether to keep the wall mount when temporarily detached (for re-attachment)
@export var preserve_mount_on_detach: bool = true

## Whether to show blueprint when close to reattachment point
@export var show_reattachment_blueprint: bool = true

#--- private variables - order: export > normal var > onready -------------------------------------

## Reference to the wall mount (StaticBody3D)
var wall_mount: StaticBody3D = null

## Joint connecting this object to the wall mount
var attachment_joint: Joint3D = null

## Whether this object is currently attached to a wall
var is_attached_to_wall: bool = false

## Whether the object was temporarily detached (can be re-attached)
var is_temporarily_detached: bool = false


## Timer for checking re-attachment proximity
var reattachment_timer: Timer = null

## Timer for monitoring breakaway forces
var breakaway_monitor_timer: Timer = null

## Whether we're currently showing the blueprint
var is_showing_blueprint: bool = false

## Reference to the player's throw place controller (set when grabbed)
var throw_place_controller: Node = null

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	print("DEBUG WallAttachmentComponent: _ready() called for %s" % get_parent().name)
	
	# Ensure we're attached to a PhysicsBody3D
	if not (get_parent() is PhysicsBody3D):
		push_error("WallAttachmentComponent must be child of a PhysicsBody3D")
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	print("DEBUG WallAttachmentComponent: Parent body type: %s" % parent_body.get_class())
	print("DEBUG WallAttachmentComponent: Wall direction: %d" % wall_direction)
	print("DEBUG WallAttachmentComponent: Auto setup: %s" % auto_setup_attachment)
	
	if auto_setup_attachment and wall_direction != -1:
		print("DEBUG WallAttachmentComponent: Scheduling wall attachment setup")
		call_deferred("_setup_wall_attachment")
	else:
		print("DEBUG WallAttachmentComponent: Skipping auto setup - direction: %d, auto: %s" % [
			wall_direction, auto_setup_attachment
		])
	
	# Connect to physics signals for breakaway detection if parent supports them
	if parent_body.has_signal("body_entered"):
		parent_body.body_entered.connect(_on_body_entered)
		print("DEBUG WallAttachmentComponent: Connected to body_entered signal")
	if parent_body.has_signal("sleeping_state_changed"):
		parent_body.sleeping_state_changed.connect(_on_sleeping_state_changed)
		print("DEBUG WallAttachmentComponent: Connected to sleeping_state_changed signal")

### Public Methods --------------------------------------------------------------------------------

## Setup wall attachment system (called manually if needed)
func setup_wall_attachment():
	print("DEBUG WallAttachmentComponent: setup_wall_attachment called manually with direction: %d" % wall_direction)
	_setup_wall_attachment()

## Manually detach from wall (e.g., when grabbed by player)
## Set temporary=true to allow re-attachment, false for permanent breakaway
func detach_from_wall(temporary: bool = true):
	if is_attached_to_wall:
		if temporary:
			_temporarily_detach_from_wall()
		else:
			_permanently_break_wall_attachment()

## Attempt to re-attach to wall mount (called when player places object back)
func try_reattach_to_wall() -> bool:
	if not is_temporarily_detached or not wall_mount:
		return false
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return false
	
	# Check if object is close enough to mount
	var distance = parent_body.global_position.distance_to(wall_mount.global_position)
	if distance <= reattachment_distance:
		_reattach_to_wall()
		return true
	
	return false

## Check if object can be re-attached (close to mount)
func can_reattach_to_wall() -> bool:
	if not is_temporarily_detached or not wall_mount:
		return false
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return false
	
	var distance = parent_body.global_position.distance_to(wall_mount.global_position)
	return distance <= reattachment_distance

## Check if object can be attached to wall
func can_attach_to_wall() -> bool:
	return wall_direction != -1 and not is_attached_to_wall

### Private Methods -------------------------------------------------------------------------------

func _setup_wall_attachment():
	print("DEBUG WallAttachmentComponent: === SETTING UP WALL ATTACHMENT ===")
	
	if not can_attach_to_wall():
		print("DEBUG WallAttachmentComponent: Cannot attach to wall - conditions not met")
		print("DEBUG WallAttachmentComponent: Wall direction: %d, Already attached: %s" % [
			wall_direction, is_attached_to_wall
		])
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		push_error("Cannot setup wall attachment - parent is not a PhysicsBody3D")
		return
	
	print("DEBUG WallAttachmentComponent: Parent body: %s at %s" % [
		parent_body.name, parent_body.global_position
	])
	print("DEBUG WallAttachmentComponent: Component position: %s" % global_position)
	
	# Ensure physics is stable before creating attachment
	if parent_body is RigidBody3D:
		var rigid_body = parent_body as RigidBody3D
		# Stop any existing motion
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
		# Temporarily disable gravity during attachment setup
		rigid_body.gravity_scale = 0.0
		print("DEBUG WallAttachmentComponent: Stabilized RigidBody3D physics")
	
	_create_wall_mount()
	await _create_attachment_joint()  # Wait for joint creation to complete
	
	# Re-enable gravity after attachment is established
	if parent_body is RigidBody3D:
		var rigid_body = parent_body as RigidBody3D
		rigid_body.gravity_scale = 1.0
		print("DEBUG WallAttachmentComponent: Re-enabled gravity")
	
	is_attached_to_wall = true
	is_temporarily_detached = false
	_setup_reattachment_monitoring()
	
	print("DEBUG WallAttachmentComponent: ✓ Wall attachment setup complete")
	print("DEBUG WallAttachmentComponent: Wall mount at: %s" % (wall_mount.global_position if wall_mount else "null"))
	
	attached_to_wall.emit(wall_mount)
	print("DEBUG WallAttachmentComponent: === END WALL ATTACHMENT SETUP ===")

func _create_wall_mount():
	print("DEBUG WallAttachmentComponent: Creating wall mount")
	
	var parent_body = get_parent() as PhysicsBody3D
	
	# Create invisible StaticBody3D as wall mount
	wall_mount = StaticBody3D.new()
	wall_mount.name = "WallMount_%s" % parent_body.name
	
	## Add small collision shape for the mount
	#var mount_collision = CollisionShape3D.new()
	#var mount_shape = BoxShape3D.new()
	#mount_shape.size = Vector3(0.05, 0.05, 0.05)  # Smaller collision shape
	#mount_collision.shape = mount_shape
	#wall_mount.add_child(mount_collision)
	#
	#print("DEBUG WallAttachmentComponent: Added collision shape to wall mount")
	#
	# Add to scene first
	var scene_parent = parent_body.get_parent()
	scene_parent.add_child(wall_mount)
	print("DEBUG WallAttachmentComponent: Wall mount added to scene parent: %s" % scene_parent.name)
	
	# Position mount at this component's position AFTER adding to scene
	# Ensure the mount is at the exact attachment point
	wall_mount.global_position = global_position
	
	# StaticBody3D is already static by nature - no need to freeze
	print("DEBUG WallAttachmentComponent: Wall mount positioned at: %s (StaticBody3D is inherently static)" % wall_mount.global_position)

func _create_attachment_joint():
	print("DEBUG WallAttachmentComponent: Creating attachment joint")
	if not wall_mount:
		print("DEBUG WallAttachmentComponent: ERROR - No wall mount found!")
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	print("DEBUG WallAttachmentComponent: Parent body type: %s" % parent_body.get_class())
	
	# Ensure both bodies are properly positioned before creating joint
	await get_tree().process_frame
	
	# Choose joint type based on parent body type
	if parent_body is RigidBody3D:
		print("DEBUG WallAttachmentComponent: Creating PinJoint3D for RigidBody3D")
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
		print("DEBUG WallAttachmentComponent: Joint node_a path: %s" % attachment_joint.node_a)
		print("DEBUG WallAttachmentComponent: Joint node_b path: %s" % attachment_joint.node_b)
		
		# Set joint parameters stability - eliminate oscillation
		#attachment_joint.set_param(PinJoint3D.PARAM_BIAS, 0.3) 
		#attachment_joint.set_param(PinJoint3D.PARAM_DAMPING, 0.01) 
		#attachment_joint.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 20.0)
		#print("DEBUG WallAttachmentComponent: Joint parameters set")
		
		# Force the painting to the exact wall mount position
		parent_body.global_position = wall_mount.global_position
		print("DEBUG WallAttachmentComponent: Forced parent body to wall mount position: %s" % wall_mount.global_position)
		
	elif parent_body is SoftBody3D:
		print("DEBUG WallAttachmentComponent: Creating Generic6DOFJoint3D for SoftBody3D")
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
		print("DEBUG WallAttachmentComponent: StaticBody3D - no joint needed")
		# No joint needed for StaticBody3D - they're already static
		# Just position them correctly
		parent_body.global_position = wall_mount.global_position
		return
	
	# Verify joint was created successfully
	if attachment_joint:
		print("DEBUG WallAttachmentComponent: ✓ Joint created successfully: %s" % attachment_joint.name)
		print("DEBUG WallAttachmentComponent: Joint position: %s" % attachment_joint.global_position)
		print("DEBUG WallAttachmentComponent: Wall mount position: %s" % wall_mount.global_position)
		print("DEBUG WallAttachmentComponent: Parent body position: %s" % parent_body.global_position)
	else:
		print("DEBUG WallAttachmentComponent: ERROR - Failed to create joint!")

func _temporarily_detach_from_wall():
	if not is_attached_to_wall:
		return
	
	var old_mount = wall_mount
	
	# Remove joint but keep mount for re-attachment
	if attachment_joint and is_instance_valid(attachment_joint):
		attachment_joint.queue_free()
		attachment_joint = null
	
	is_attached_to_wall = false
	is_temporarily_detached = true
	
	# Start monitoring for re-attachment
	_start_reattachment_monitoring()
	
	detached_from_wall.emit(old_mount, true)

func _permanently_break_wall_attachment():
	if not is_attached_to_wall and not is_temporarily_detached:
		return
	
	var old_mount = wall_mount
	
	# Remove joint
	if attachment_joint and is_instance_valid(attachment_joint):
		attachment_joint.queue_free()
		attachment_joint = null
	
	# Remove wall mount permanently
	if wall_mount and is_instance_valid(wall_mount):
		wall_mount.queue_free()
		wall_mount = null
	
	# Stop reattachment monitoring
	_stop_reattachment_monitoring()
	
	is_attached_to_wall = false
	is_temporarily_detached = false
	detached_from_wall.emit(old_mount, false)

func _reattach_to_wall():
	if not is_temporarily_detached or not wall_mount:
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return
	
	# Position object at mount
	parent_body.global_position = wall_mount.global_position
	
	# Recreate joint
	_create_attachment_joint()
	
	is_attached_to_wall = true
	is_temporarily_detached = false
	
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
		print("DEBUG WallAttachmentComponent: Started breakaway force monitoring (200ms intervals)")

func _start_reattachment_monitoring():
	if reattachment_timer:
		reattachment_timer.start()

func _stop_reattachment_monitoring():
	if reattachment_timer:
		reattachment_timer.stop()
	
	# Stop breakaway monitoring when detached
	if breakaway_monitor_timer:
		breakaway_monitor_timer.stop()
		print("DEBUG WallAttachmentComponent: Stopped breakaway force monitoring")

func _check_reattachment_proximity():
	if not is_temporarily_detached or not show_reattachment_blueprint:
		return
	
	var can_reattach = can_reattach_to_wall()
	
	if can_reattach and not is_showing_blueprint:
		# Show blueprint at wall mount position
		var mount_position = wall_mount.global_position
		var mount_rotation = _get_wall_mount_rotation()
		should_show_wall_blueprint.emit(mount_position, mount_rotation)
		is_showing_blueprint = true
		ready_for_reattachment.emit(wall_mount)
		
	elif not can_reattach and is_showing_blueprint:
		# Hide blueprint when too far away
		should_hide_wall_blueprint.emit()
		is_showing_blueprint = false

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

## Set reference to throw place controller (called when object is grabbed)
func set_throw_place_controller(controller: Node):
	throw_place_controller = controller

## Clear throw place controller reference (called when object is released)
func clear_throw_place_controller():
	if is_showing_blueprint:
		should_hide_wall_blueprint.emit()
		is_showing_blueprint = false
	throw_place_controller = null

func _check_breakaway_force():
	if not is_attached_to_wall or not attachment_joint:
		return
	
	var parent_body = get_parent() as PhysicsBody3D
	if not parent_body:
		return
	
	# Only check breakaway for dynamic bodies
	if parent_body is RigidBody3D:
		var rigid_body = parent_body as RigidBody3D
		
		# Calculate force based on distance from wall mount and velocity
		var distance_from_mount = rigid_body.global_position.distance_to(wall_mount.global_position)
		var velocity_force = rigid_body.linear_velocity.length() * rigid_body.mass
		var stretch_force = distance_from_mount * 10.0  # Force increases with distance
		var total_force = velocity_force + stretch_force
		
		# Only print debug if there's significant movement to reduce spam
		if distance_from_mount > 0.1 or velocity_force > 1.0:
			print("DEBUG WallAttachmentComponent: Breakaway check - Distance: %f, Velocity force: %f, Stretch force: %f, Total: %f, Threshold: %f" % [
				distance_from_mount, velocity_force, stretch_force, total_force, breakaway_force_threshold
			])
		
		# If object is too far from mount, it's definitely broken
		if distance_from_mount > 0.5:  # 50cm max stretch
			print("DEBUG WallAttachmentComponent: Object too far from mount - forcing breakaway")
			breakaway_triggered.emit(total_force)
			_permanently_break_wall_attachment()
			return
		
		# Check force threshold
		if total_force > breakaway_force_threshold:
			print("DEBUG WallAttachmentComponent: Force threshold exceeded - triggering breakaway")
			breakaway_triggered.emit(total_force)
			_permanently_break_wall_attachment()
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

### -----------------------------------------------------------------------------------------------
