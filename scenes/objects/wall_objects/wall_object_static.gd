extends StaticBody3D
class_name WallObjectStatic

## Static wall-mounted object class for objects like sconces that don't need physics interactions
## Extends StaticBody3D and uses WallAttachmentComponent for wall mounting
## Unlike WallObjectRigid, this class doesn't support player interaction (grabbing/releasing)

### Member Variables and Dependencies -------------------------------------------------------------

#--- signals --------------------------------------------------------------------------------------

# No player interaction signals needed for static objects

#--- public variables - order: export > normal var > onready --------------------------------------

## Reference to the wall attachment component
@onready var wall_attachment: WallAttachmentComponent = $WallAttachmentComponent

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	# Connect to wall attachment signals
	wall_attachment.attached_to_wall.connect(_on_attached_to_wall)
	wall_attachment.detached_from_wall.connect(_on_detached_from_wall)
	wall_attachment.ready_for_reattachment.connect(_on_ready_for_reattachment)
	wall_attachment.breakaway_triggered.connect(_on_breakaway_triggered)
	
	# Auto-light candles with 75% probability
	_attempt_candle_lighting()

### Public Methods --------------------------------------------------------------------------------

## Get the current attachment status
func get_attachment_status() -> String:
	if wall_attachment.is_attached_to_wall:
		return "attached"
	else:
		return "permanently_detached"

### Private Methods -------------------------------------------------------------------------------

## Attempts to light any candle nodes with 75% probability
func _attempt_candle_lighting() -> void:
	# Find all child nodes with names starting with "candle" (case-insensitive)
	var candle_nodes: Array[Node] = []
	_find_candle_nodes(self, candle_nodes)
	
	# Light each candle with 75% probability
	for candle_node in candle_nodes:
		if randf() < 0.85 and candle_node.has_method("light"):
			candle_node.light()


## Recursively searches for nodes with names starting with "candle"
func _find_candle_nodes(node: Node, candle_nodes: Array[Node]) -> void:
	# Check if current node name starts with "candle" (case-insensitive)
	if node.name.to_lower().begins_with("candle"):
		candle_nodes.append(node)
	
	# Recursively check all children
	for child in node.get_children():
		_find_candle_nodes(child, candle_nodes)

### Signal Callbacks ------------------------------------------------------------------------------

func _on_attached_to_wall(mount: StaticBody3D):
	# Could play attachment sound effect here
	pass


func _on_detached_from_wall(mount: StaticBody3D, is_temporary: bool):
	# Could play detachment sound effect here
	pass


func _on_ready_for_reattachment(mount: StaticBody3D):
	# Static objects don't typically need reattachment logic
	# but this callback is available if needed
	pass


func _on_breakaway_triggered(force: float):
	# Could spawn debris or play breaking sound for static objects
	# though breakaway is less common for StaticBody3D objects
	pass
