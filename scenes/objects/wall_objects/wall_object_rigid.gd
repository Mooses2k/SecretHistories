extends RigidBody3D
class_name WallObjectRigid

### Member Variables and Dependencies -------------------------------------------------------------

#--- signals --------------------------------------------------------------------------------------

signal grabbed_by_player(player)
signal released_by_player(player)

#--- public variables - order: export > normal var > onready --------------------------------------

## Reference to the wall attachment component
@onready var wall_attachment: WallAttachmentComponent = $WallAttachmentComponent

## Whether this painting is currently being grabbed by player
var is_grabbed: bool = false

## Reference to the player currently grabbing this painting
var grabbing_player = null

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	# Connect to wall attachment signals
	wall_attachment.attached_to_wall.connect(_on_attached_to_wall)
	wall_attachment.detached_from_wall.connect(_on_detached_from_wall)
	wall_attachment.ready_for_reattachment.connect(_on_ready_for_reattachment)
	wall_attachment.breakaway_triggered.connect(_on_breakaway_triggered)

### Public Methods --------------------------------------------------------------------------------

## Called by player interaction system when grabbing
func grab_by_player(player):
	if is_grabbed:
		return false
	
	print("WALL_OBJECT DEBUG - grab_by_player called, attached: ", wall_attachment.is_attached_to_wall)
	print("WALL_OBJECT DEBUG - Before grab - Linear damp: ", linear_damp, " Angular damp: ", angular_damp)
	
	is_grabbed = true
	grabbing_player = player
	
	# Only detach if actually attached to wall
	if wall_attachment.is_attached_to_wall:
		# Temporarily detach from wall (preserves mount for re-attachment)
		wall_attachment.detach_from_wall()
	
	# Keep gravity enabled while being carried - only disable during attachment setup
	# gravity_scale = 0.0  # Removed - let physics work naturally
	
	grabbed_by_player.emit(player)
	return true


## Called by player interaction system when releasing
func release_by_player(player):
	if not is_grabbed or grabbing_player != player:
		return false
	
	print("WALL_OBJECT DEBUG - release_by_player called, can_reattach: ", wall_attachment.can_reattach_to_wall())
	print("WALL_OBJECT DEBUG - Before release - Linear damp: ", linear_damp, " Angular damp: ", angular_damp)
	
	is_grabbed = false
	grabbing_player = null
	
	# Try to re-attach to wall if close enough
	if wall_attachment.can_reattach_to_wall():
		wall_attachment.try_reattach_to_wall()
	
	print("WALL_OBJECT DEBUG - After release - Linear damp: ", linear_damp, " Angular damp: ", angular_damp)
	released_by_player.emit(player)

	return true


## Get the current attachment status
func get_attachment_status() -> String:
	if wall_attachment.is_attached_to_wall:
		return "attached"
	else:
		return "permanently_detached"

### Private Methods -------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

func _on_attached_to_wall(mount: StaticBody3D):
	# Could play attachment sound effect here
	pass


func _on_detached_from_wall(mount: StaticBody3D, is_temporary: bool):
	# Could play detachment sound effect here
	pass


func _on_ready_for_reattachment(mount: StaticBody3D):
	# Could show visual indicator or play sound to guide player
	pass


func _on_breakaway_triggered(force: float):
	# Could spawn debris or play breaking sound
	pass
