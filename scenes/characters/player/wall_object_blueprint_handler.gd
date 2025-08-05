extends Node

## Handler for wall object blueprint integration with ThrowPlaceController
## Manages showing/hiding blueprints for wall object re-attachment

### Member Variables and Dependencies -------------------------------------------------------------

@onready var throw_place_controller: Node = get_parent()
@onready var player: Player = owner

## Current wall object that might show a blueprint
var current_wall_object: RigidBody3D = null

## Blueprint for wall reattachment
var wall_reattachment_blueprint: RigidBody3D = null

## Position where the wall blueprint should appear
var wall_blueprint_position: Vector3 = Vector3.ZERO

## Rotation for the wall blueprint
var wall_blueprint_rotation: Vector3 = Vector3.ZERO

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	# Connect to interact controller to detect when wall objects are grabbed
	var interact_controller = get_node("../InteractController")
	if interact_controller:
		# We'll need to modify interact_controller to emit signals for wall objects
		pass

### Public Methods --------------------------------------------------------------------------------

## Called when a wall object signals it should show a blueprint
func show_wall_blueprint(wall_object: RigidBody3D, mount_position: Vector3, mount_rotation: Vector3):
	if current_wall_object == wall_object:
		return  # Already showing blueprint for this object
	
	# Hide any existing blueprint
	hide_wall_blueprint()
	
	current_wall_object = wall_object
	wall_blueprint_position = mount_position
	wall_blueprint_rotation = mount_rotation
	
	# Create blueprint at the wall mount position
	wall_reattachment_blueprint = _make_wall_blueprint(wall_object)
	if wall_reattachment_blueprint:
		wall_reattachment_blueprint.top_level = true
		wall_reattachment_blueprint.global_position = wall_blueprint_position
		wall_reattachment_blueprint.rotation = wall_blueprint_rotation
		add_child(wall_reattachment_blueprint)
		
		print("Showing wall reattachment blueprint for: ", wall_object.name)

## Called when a wall object signals it should hide its blueprint
func hide_wall_blueprint():
	if wall_reattachment_blueprint and is_instance_valid(wall_reattachment_blueprint):
		wall_reattachment_blueprint.queue_free()
		wall_reattachment_blueprint = null
	
	current_wall_object = null
	print("Hiding wall reattachment blueprint")

## Check if the player is trying to place a wall object back on its mount
func try_wall_reattachment() -> bool:
	if not current_wall_object or not wall_reattachment_blueprint:
		return false
	
	# Check if the wall object has a wall attachment component
	var wall_attachment = current_wall_object.get_node_or_null("WallAttachmentComponent")
	if not wall_attachment:
		return false
	
	# Try to reattach
	if wall_attachment.try_reattach_to_wall():
		hide_wall_blueprint()
		return true
	
	return false

### Private Methods -------------------------------------------------------------------------------

## Create a blueprint for wall object reattachment
func _make_wall_blueprint(wall_object: RigidBody3D) -> RigidBody3D:
	if not is_instance_valid(wall_object):
		return null
	
	# Use the same blueprint creation logic as ThrowPlaceController
	var blueprint_root := RigidBody3D.new()
	blueprint_root.freeze = true
	blueprint_root.collision_layer = 0
	blueprint_root.collision_mask = 0  # Wall blueprints don't need collision
	
	# Get the blueprint material from ThrowPlaceController
	var blueprint_material = throw_place_controller.place_blueprint_material
	
	var node_queue : Array[Node] = wall_object.get_children()
	var transform_queue : Array[Transform3D]
	transform_queue.resize(node_queue.size())
	transform_queue.fill(Transform3D.IDENTITY)
	
	while not node_queue.is_empty():
		var node : Node = node_queue.pop_front() as Node
		var transform : Transform3D = transform_queue.pop_front()
		
		if node is not Node3D or node.is_in_group(&"NO_BLUEPRINT"):
			continue
		
		var new_transform : Transform3D = transform * node.transform
		
		# Only create mesh instances for wall blueprints (no collision needed)
		if node is MeshInstance3D and node.visible:
			var new_node := MeshInstance3D.new()
			new_node.mesh = node.mesh
			new_node.material_override = blueprint_material
			new_node.transform = new_transform
			blueprint_root.add_child(new_node)
		
		# Continue traversing children
		var children = node.get_children()
		var transforms : Array[Transform3D]
		transforms.resize(children.size())
		transforms.fill(new_transform)
		node_queue.append_array(children)
		transform_queue.append_array(transforms)
	
	blueprint_root.top_level = true
	return blueprint_root

### Signal Callbacks ------------------------------------------------------------------------------

## Connect this to wall objects when they're grabbed
func _on_wall_object_grabbed(wall_object: RigidBody3D):
	var wall_attachment = wall_object.get_node_or_null("WallAttachmentComponent")
	if wall_attachment:
		# Connect to the wall attachment signals
		if not wall_attachment.should_show_wall_blueprint.is_connected(_on_should_show_wall_blueprint):
			wall_attachment.should_show_wall_blueprint.connect(_on_should_show_wall_blueprint)
		if not wall_attachment.should_hide_wall_blueprint.is_connected(_on_should_hide_wall_blueprint):
			wall_attachment.should_hide_wall_blueprint.connect(_on_should_hide_wall_blueprint)

func _on_should_show_wall_blueprint(mount_position: Vector3, mount_rotation: Vector3):
	if current_wall_object:
		show_wall_blueprint(current_wall_object, mount_position, mount_rotation)

func _on_should_hide_wall_blueprint():
	hide_wall_blueprint()

### -----------------------------------------------------------------------------------------------