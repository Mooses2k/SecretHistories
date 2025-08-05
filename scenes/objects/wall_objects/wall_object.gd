@tool
class_name WallObject
extends RigidBody3D

## Base class for objects that can be attached to walls
## Handles wall mounting, physics attachment, and breakaway mechanics

### Member Variables and Dependencies -------------------------------------------------------------

#--- signals --------------------------------------------------------------------------------------
signal attached_to_wall(mount: StaticBody3D)
signal detached_from_wall(mount: StaticBody3D)
signal breakaway_triggered(force: float)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## Wall direction this object is attached to (set by spawn system)
@export var wall_direction: int = -1

## Offset from object center to wall mount point
@export var mount_offset: Vector3 = Vector3(0, 0, -0.05)

## Force threshold needed to break from wall attachment
@export var breakaway_force_threshold: float = 50.0

## Whether this object should automatically setup wall attachment on ready
@export var auto_setup_attachment: bool = true

#--- private variables - order: export > normal var > onready -------------------------------------

## Reference to the wall mount (StaticBody3D)
var wall_mount: StaticBody3D = null

## Joint connecting this object to the wall mount
var attachment_joint: Joint3D = null

## Whether this object is currently attached to a wall
var is_attached_to_wall: bool = false

## Node that marks where the wall mount should be positioned
@onready var wall_mount_point: Node3D = $WallMountPoint

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	if auto_setup_attachment and wall_direction != -1:
		call_deferred("_setup_wall_attachment")
	
	# Connect to physics signals for breakaway detection
	body_entered.connect(_on_body_entered)
	if has_signal("sleeping_state_changed"):
		sleeping_state_changed.connect(_on_sleeping_state_changed)

### Public Methods --------------------------------------------------------------------------------

## Setup wall attachment system
func setup_wall_attachment(p_wall_direction: int, mount_position: Vector3 = Vector3.ZERO):
	wall_direction = p_wall_direction
	if mount_position != Vector3.ZERO:
		global_position = mount_position
	_setup_wall_attachment()


## Manually detach from wall (e.g., when grabbed by player)
func detach_from_wall():
	if is_attached_to_wall:
		_break_wall_attachment()


## Check if object can be attached to wall
func can_attach_to_wall() -> bool:
	return wall_direction != -1 and not is_attached_to_wall

### Private Methods -------------------------------------------------------------------------------

func _setup_wall_attachment():
	if not can_attach_to_wall():
		return
	
	_create_wall_mount()
	_create_attachment_joint()
	is_attached_to_wall = true
	attached_to_wall.emit(wall_mount)


func _create_wall_mount():
	# Create invisible StaticBody3D as wall mount
	wall_mount = StaticBody3D.new()
	wall_mount.name = "WallMount"
	
	# Position mount at the wall mount point
	var mount_position = global_position
	if wall_mount_point:
		mount_position = wall_mount_point.global_position
	else:
		mount_position += mount_offset
	
	wall_mount.global_position = mount_position
	
	# Add small collision shape for the mount
	var mount_collision = CollisionShape3D.new()
	var mount_shape = BoxShape3D.new()
	mount_shape.size = Vector3(0.1, 0.1, 0.1)
	mount_collision.shape = mount_shape
	wall_mount.add_child(mount_collision)
	
	# Add to scene
	get_parent().add_child(wall_mount)


func _create_attachment_joint():
	if not wall_mount:
		return
	
	# Create PinJoint3D for natural swinging motion
	attachment_joint = PinJoint3D.new()
	attachment_joint.name = "WallAttachmentJoint"
	
	# Configure joint
	attachment_joint.node_a = wall_mount.get_path()
	attachment_joint.node_b = get_path()
	
	# Set joint parameters for stable attachment
	attachment_joint.set_param(PinJoint3D.PARAM_BIAS, 0.3)
	attachment_joint.set_param(PinJoint3D.PARAM_DAMPING, 1.0)
	attachment_joint.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 0.0)
	
	# Add joint to scene
	get_parent().add_child(attachment_joint)


func _break_wall_attachment():
	if not is_attached_to_wall:
		return
	
	var old_mount = wall_mount
	
	# Remove joint
	if attachment_joint and is_instance_valid(attachment_joint):
		attachment_joint.queue_free()
		attachment_joint = null
	
	# Remove wall mount
	if wall_mount and is_instance_valid(wall_mount):
		wall_mount.queue_free()
		wall_mount = null
	
	is_attached_to_wall = false
	detached_from_wall.emit(old_mount)


func _check_breakaway_force():
	if not is_attached_to_wall or not attachment_joint:
		return
	
	# Get applied force (simplified - in practice you'd monitor joint stress)
	var current_force = linear_velocity.length() * mass
	
	if current_force > breakaway_force_threshold:
		breakaway_triggered.emit(current_force)
		_break_wall_attachment()

### Signal Callbacks ------------------------------------------------------------------------------

func _on_body_entered(body):
	# Monitor for collisions that might cause breakaway
	if is_attached_to_wall:
		call_deferred("_check_breakaway_force")


func _on_sleeping_state_changed():
	# Check for breakaway when object stops moving
	if is_attached_to_wall and not sleeping:
		call_deferred("_check_breakaway_force")

### -----------------------------------------------------------------------------------------------
