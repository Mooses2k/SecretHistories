extends SoftBody3D
class_name WallObjectSoft

## Soft body wall-mounted object class for flexible objects like tapestries, curtains, banners
## Extends SoftBody3D and uses multiple WallAttachmentComponents for multi-point mounting
## Supports player interaction (grabbing/releasing) and flexible physics simulation

### Member Variables and Dependencies -------------------------------------------------------------

#--- signals --------------------------------------------------------------------------------------

signal grabbed_by_player(player)
signal released_by_player(player)

#--- public variables - order: export > normal var > onready --------------------------------------

## Array of references to wall attachment components (for multi-point attachment)
var wall_attachments: Array[WallAttachmentComponent] = []

## Whether this soft object is currently being grabbed by player
var is_grabbed: bool = false

## Reference to the player currently grabbing this object
var grabbing_player = null

## Minimum number of attachment points required for stable mounting
@export var min_attachment_points: int = 1

## Maximum number of attachment points supported
@export var max_attachment_points: int = 4

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	# Find all WallAttachmentComponent children
	_discover_wall_attachments()
	
	# Connect to all wall attachment signals
	for attachment in wall_attachments:
		attachment.attached_to_wall.connect(_on_attached_to_wall)
		attachment.detached_from_wall.connect(_on_detached_from_wall)
		attachment.ready_for_reattachment.connect(_on_ready_for_reattachment)
		attachment.breakaway_triggered.connect(_on_breakaway_triggered)
	
	# Check if we have wall_direction set as a custom property (from spawn system)
	# This handles the case where spawn_data sets wall_direction on the first WallAttachmentComponent
	# but we need to apply it to all attachment components for soft bodies
	call_deferred("_check_and_setup_wall_attachments")

### Public Methods --------------------------------------------------------------------------------

## Called by player interaction system when grabbing
func grab_by_player(player):
	if is_grabbed:
		return false
	
	print("WALL_OBJECT_SOFT DEBUG - grab_by_player called, attached points: ", _get_attached_count())
	
	is_grabbed = true
	grabbing_player = player
	
	# Detach from all wall mounts (preserves mounts for re-attachment)
	for attachment in wall_attachments:
		if attachment.is_attached_to_wall:
			attachment.detach_from_wall()
	
	grabbed_by_player.emit(player)
	return true


## Called by player interaction system when releasing
func release_by_player(player):
	if not is_grabbed or grabbing_player != player:
		return false
	
	print("WALL_OBJECT_SOFT DEBUG - release_by_player called, can_reattach points: ", _get_reattachable_count())
	
	is_grabbed = false
	grabbing_player = null
	
	# Try to re-attach to wall mounts if close enough
	var reattached_count: int = 0
	for attachment in wall_attachments:
		if attachment.can_reattach_to_wall():
			if attachment.try_reattach_to_wall():
				reattached_count += 1
	
	print("WALL_OBJECT_SOFT DEBUG - Successfully reattached ", reattached_count, " attachment points")
	released_by_player.emit(player)
	
	return true


## Get the current attachment status
func get_attachment_status() -> String:
	var attached_count = _get_attached_count()
	
	if attached_count >= min_attachment_points:
		return "attached"
	elif attached_count > 0:
		return "partially_attached"
	else:
		return "permanently_detached"


## Get number of currently attached points
func get_attached_count() -> int:
	return _get_attached_count()


## Get number of attachment points that can be reattached
func get_reattachable_count() -> int:
	return _get_reattachable_count()


## Check if object is stable (has minimum required attachment points)
func is_stable_attachment() -> bool:
	return _get_attached_count() >= min_attachment_points


## Get the center position between all attachment points (for positioning)
func get_attachment_center_position() -> Vector3:
	if wall_attachments.is_empty():
		return global_position
	
	var center_position := Vector3.ZERO
	for attachment in wall_attachments:
		center_position += attachment.global_position
	
	return center_position / wall_attachments.size()


## Get the center position between all attachment points in local space
func get_attachment_center_position_local() -> Vector3:
	if wall_attachments.is_empty():
		return Vector3.ZERO
	
	var center_position := Vector3.ZERO
	for attachment in wall_attachments:
		center_position += attachment.position
	
	return center_position / wall_attachments.size()


## Manually detach all attachment points
func detach_all_from_wall():
	for attachment in wall_attachments:
		if attachment.is_attached_to_wall:
			attachment.detach_from_wall()


## Try to reattach all possible attachment points
func try_reattach_all_to_wall() -> int:
	var reattached_count: int = 0
	for attachment in wall_attachments:
		if attachment.can_reattach_to_wall():
			if attachment.try_reattach_to_wall():
				reattached_count += 1
	return reattached_count


## Setup wall attachments for a specific direction (called by spawn system)
func setup_wall_attachments_for_direction(wall_direction: int):
	print("WALL_OBJECT_SOFT DEBUG - Setting up %d attachment points for wall_direction: %d" % [wall_attachments.size(), wall_direction])
	
	for attachment in wall_attachments:
		attachment.wall_direction = wall_direction
		attachment.call_deferred("setup_wall_attachment")
	
	print("WALL_OBJECT_SOFT DEBUG - All attachment points configured for wall_direction: %d" % wall_direction)

### Private Methods -------------------------------------------------------------------------------

## Check if spawn system has set wall_direction and apply to all attachments
func _check_and_setup_wall_attachments():
	# Check if any attachment component has wall_direction set (from spawn system)
	var wall_direction: int = -1
	for attachment in wall_attachments:
		if attachment.wall_direction != -1:
			wall_direction = attachment.wall_direction
			break
	
	# If we found a wall_direction, apply it to all attachment components
	if wall_direction != -1:
		print("WALL_OBJECT_SOFT DEBUG - Found wall_direction %d from spawn system, applying to all %d attachment points" % [wall_direction, wall_attachments.size()])
		setup_wall_attachments_for_direction(wall_direction)


## Discover and cache all WallAttachmentComponent children
func _discover_wall_attachments():
	wall_attachments.clear()
	_find_wall_attachment_components(self, wall_attachments)
	
	print("WALL_OBJECT_SOFT DEBUG - Found ", wall_attachments.size(), " wall attachment components")
	
	# Validate attachment point count
	if wall_attachments.size() < min_attachment_points:
		push_warning("WallObjectSoft has fewer attachment points (%d) than minimum required (%d)" % [wall_attachments.size(), min_attachment_points])
	elif wall_attachments.size() > max_attachment_points:
		push_warning("WallObjectSoft has more attachment points (%d) than maximum supported (%d)" % [wall_attachments.size(), max_attachment_points])


## Recursively find all WallAttachmentComponent nodes
func _find_wall_attachment_components(node: Node, components: Array[WallAttachmentComponent]):
	if node is WallAttachmentComponent:
		components.append(node as WallAttachmentComponent)
	
	for child in node.get_children():
		_find_wall_attachment_components(child, components)


## Get count of currently attached points
func _get_attached_count() -> int:
	var count: int = 0
	for attachment in wall_attachments:
		if attachment.is_attached_to_wall:
			count += 1
	return count


## Get count of points that can be reattached
func _get_reattachable_count() -> int:
	var count: int = 0
	for attachment in wall_attachments:
		if attachment.can_reattach_to_wall():
			count += 1
	return count

### Signal Callbacks ------------------------------------------------------------------------------

func _on_attached_to_wall(mount: StaticBody3D):
	var attached_count = _get_attached_count()
	print("WALL_OBJECT_SOFT DEBUG - Attachment point connected, total attached: ", attached_count)
	
	# Could play attachment sound effect here
	# Different sounds based on attachment stability
	if attached_count >= min_attachment_points:
		# Stable attachment achieved
		pass
	else:
		# Partial attachment
		pass


func _on_detached_from_wall(mount: StaticBody3D, is_temporary: bool):
	var attached_count = _get_attached_count()
	print("WALL_OBJECT_SOFT DEBUG - Attachment point disconnected, remaining attached: ", attached_count)
	
	# Could play detachment sound effect here
	# Different behavior based on remaining attachment points
	if attached_count < min_attachment_points:
		# Object is no longer stable
		print("WALL_OBJECT_SOFT DEBUG - Object is no longer stable (below minimum attachment points)")


func _on_ready_for_reattachment(mount: StaticBody3D):
	# Could show visual indicator or play sound to guide player
	# For soft bodies, this might involve highlighting the attachment point
	pass


func _on_breakaway_triggered(force: float):
	var attached_count = _get_attached_count()
	print("WALL_OBJECT_SOFT DEBUG - Breakaway triggered on attachment point, remaining: ", attached_count)
	
	# Could spawn debris or play breaking sound
	# For soft bodies, partial breakaway might cause interesting physics effects
	if attached_count < min_attachment_points:
		# Object has lost stability
		print("WALL_OBJECT_SOFT DEBUG - Soft object lost stability due to breakaway")