extends RigidBody3D
class_name WallPainting

## Example wall painting that demonstrates grab-and-place mechanics
## This shows how to integrate with the WallAttachmentComponent

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
	wall_attachment.should_show_wall_blueprint.connect(_on_should_show_wall_blueprint)
	wall_attachment.should_hide_wall_blueprint.connect(_on_should_hide_wall_blueprint)

### Public Methods --------------------------------------------------------------------------------

## Called by player interaction system when grabbing
func grab_by_player(player):
	if is_grabbed:
		return false
	
	is_grabbed = true
	grabbing_player = player
	
	# Set reference to player's throw place controller for blueprint integration
	var throw_controller = player.get_node_or_null("ThrowPlaceController")
	if throw_controller:
		wall_attachment.set_throw_place_controller(throw_controller)
	
	# Temporarily detach from wall (preserves mount for re-attachment)
	wall_attachment.detach_from_wall(true)  # true = temporary
	
	# Disable gravity while being carried
	gravity_scale = 0.0
	
	grabbed_by_player.emit(player)
	return true

## Called by player interaction system when releasing
func release_by_player(player):
	if not is_grabbed or grabbing_player != player:
		return false
	
	is_grabbed = false
	grabbing_player = null
	
	# Clear throw place controller reference
	wall_attachment.clear_throw_place_controller()
	
	# Re-enable gravity
	gravity_scale = 1.0
	
	# Try to re-attach to wall if close enough
	if wall_attachment.can_reattach_to_wall():
		wall_attachment.try_reattach_to_wall()
	
	released_by_player.emit(player)
	return true

## Check if painting can be grabbed
func can_be_grabbed() -> bool:
	return not is_grabbed

## Get the current attachment status
func get_attachment_status() -> String:
	if wall_attachment.is_attached_to_wall:
		return "attached"
	elif wall_attachment.is_temporarily_detached:
		return "temporarily_detached"
	else:
		return "permanently_detached"

### Private Methods -------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

func _on_attached_to_wall(mount: StaticBody3D):
	print("Painting attached to wall mount: ", mount.name)
	# Could play attachment sound effect here

func _on_detached_from_wall(mount: StaticBody3D, is_temporary: bool):
	if is_temporary:
		print("Painting temporarily detached from wall (can be re-attached)")
	else:
		print("Painting permanently detached from wall")
	# Could play detachment sound effect here

func _on_ready_for_reattachment(mount: StaticBody3D):
	print("Painting is close to wall mount and ready for re-attachment")
	# Could show visual indicator or play sound to guide player

func _on_breakaway_triggered(force: float):
	print("Painting broke away from wall with force: ", force)
	# Could spawn debris or play breaking sound

func _on_should_show_wall_blueprint(mount_position: Vector3, mount_rotation: Vector3):
	print("Should show wall reattachment blueprint at: ", mount_position)
	# This integrates with the existing blueprint system
	# The ThrowPlaceController will handle showing the blueprint

func _on_should_hide_wall_blueprint():
	print("Should hide wall reattachment blueprint")
	# The ThrowPlaceController will handle hiding the blueprint

### -----------------------------------------------------------------------------------------------

## Example integration with your existing player interaction system:
##
## In your player controller:
##
## func try_grab_object():
##     var target = get_grab_target()  # Your existing grab detection
##     if target is WallPainting:
##         var painting = target as WallPainting
##         if painting.can_be_grabbed():
##             painting.grab_by_player(self)
##
## func release_grabbed_object():
##     if grabbed_object is WallPainting:
##         var painting = grabbed_object as WallPainting
##         painting.release_by_player(self)
