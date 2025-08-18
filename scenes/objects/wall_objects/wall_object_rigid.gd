extends RigidBody3D
class_name WallObjectRigid

### Member Variables and Dependencies -------------------------------------------------------------

#--- signals --------------------------------------------------------------------------------------

signal grabbed_by_player(player)
signal released_by_player(player)

#--- public variables - order: export > normal var > onready --------------------------------------

## Whether this object is a painting that can have procedural artwork applied
@export var is_painting: bool = false

## Name of the mesh node that contains the canvas for painting artwork
@export var canvas_mesh_name: String = ""

## Material index on the canvas mesh where painting textures should be applied
@export var canvas_material_index: int = 0

## Reference to the wall attachment component
@onready var wall_attachment: WallAttachmentComponent = $WallAttachmentComponent

## Whether this painting is currently being grabbed by player
var is_grabbed: bool = false

## Reference to the player currently grabbing this painting
var grabbing_player = null

## Painting texture path set during world generation
var painting_texture_path: String = ""

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	# Connect to wall attachment signals
	wall_attachment.attached_to_wall.connect(_on_attached_to_wall)
	wall_attachment.detached_from_wall.connect(_on_detached_from_wall)
	wall_attachment.ready_for_reattachment.connect(_on_ready_for_reattachment)
	wall_attachment.breakaway_triggered.connect(_on_breakaway_triggered)
	
	# Apply painting texture if this is a painting and has a texture path
	print("DEBUG WallObjectRigid _ready: is_painting=%s, painting_texture_path='%s'" % [is_painting, painting_texture_path])
	if is_painting and not painting_texture_path.is_empty():
		print("DEBUG WallObjectRigid _ready: ✓ Applying painting texture from _ready()")
		_apply_painting_texture(painting_texture_path)
	elif is_painting:
		print("DEBUG WallObjectRigid _ready: ✗ This is a painting but no texture path set yet")
	else:
		print("DEBUG WallObjectRigid _ready: This is not a painting, skipping texture application")

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

## Set the painting texture path (called during world generation)
func set_painting_texture_path(texture_path: String):
	print("DEBUG WallObjectRigid set_painting_texture_path: Called with texture_path='%s'" % texture_path)
	print("DEBUG WallObjectRigid set_painting_texture_path: is_painting=%s, is_inside_tree=%s" % [is_painting, is_inside_tree()])
	painting_texture_path = texture_path
	print("DEBUG WallObjectRigid set_painting_texture_path: ✓ Set painting_texture_path variable")
	
	# If already ready, apply texture immediately
	if is_inside_tree() and is_painting and not texture_path.is_empty():
		print("DEBUG WallObjectRigid set_painting_texture_path: ✓ Object is ready, applying texture immediately")
		_apply_painting_texture(texture_path)
	else:
		print("DEBUG WallObjectRigid set_painting_texture_path: ✗ Object not ready yet, texture will be applied in _ready()")
		print("DEBUG WallObjectRigid set_painting_texture_path: is_inside_tree=%s, is_painting=%s, texture_path_empty=%s" % [is_inside_tree(), is_painting, texture_path.is_empty()])

### Private Methods -------------------------------------------------------------------------------

func _apply_painting_texture(image_path: String):
	## Load texture from image path and apply it to the wall object's canvas
	## Handles texture loading, mesh/material finding, and zoom-to-fit scaling
	
	print("DEBUG WallObjectRigid _apply_painting_texture: === STARTING TEXTURE APPLICATION ===")
	print("DEBUG WallObjectRigid _apply_painting_texture: Loading and applying painting texture: %s" % image_path)
	print("DEBUG WallObjectRigid _apply_painting_texture: Expected canvas mesh name: '%s', Canvas material index: %d" % [canvas_mesh_name, canvas_material_index])
	
	# Debug: List all available mesh nodes in this object
	print("DEBUG WallObjectRigid: === LISTING ALL MESH NODES ===")
	_debug_list_all_mesh_nodes(self)
	
	# Load texture into memory - force fresh load
	var texture: Texture2D = load(image_path)
	if not texture:
		push_warning("Failed to load painting texture: %s" % image_path)
		return
	
	print("DEBUG WallObjectRigid: Successfully loaded texture: %dx%d, ID: %s" % [texture.get_width(), texture.get_height(), texture.get_instance_id()])
	
	# Find canvas mesh by name
	if canvas_mesh_name.is_empty():
		push_warning("Wall object has no canvas_mesh_name specified")
		return
	
	var canvas_mesh_node: Node = find_child(canvas_mesh_name)
	if not canvas_mesh_node:
		print("DEBUG WallObjectRigid: ✗ Canvas mesh not found with exact name: '%s'" % canvas_mesh_name)
		print("DEBUG WallObjectRigid: Attempting to find similar mesh names...")
		canvas_mesh_node = _find_similar_mesh_node(canvas_mesh_name)
		if not canvas_mesh_node:
			push_warning("Canvas mesh not found: %s" % canvas_mesh_name)
			return
		else:
			print("DEBUG WallObjectRigid: ✓ Found similar mesh node: %s" % canvas_mesh_node.name)
	
	# Ensure it's a MeshInstance3D
	var mesh_instance: MeshInstance3D = canvas_mesh_node as MeshInstance3D
	if not mesh_instance:
		push_warning("Canvas mesh node is not a MeshInstance3D: %s" % canvas_mesh_node.name)
		return
	
	print("DEBUG WallObjectRigid: ✓ Found canvas mesh: %s (actual name: %s)" % [canvas_mesh_name, canvas_mesh_node.name])
	
	# Get mesh surface count for validation
	var mesh: Mesh = mesh_instance.mesh
	if not mesh:
		push_warning("Canvas mesh has no mesh resource")
		return
	
	var surface_count: int = mesh.get_surface_count()
	print("DEBUG WallObjectRigid: Mesh surface count: %d" % surface_count)
	
	if canvas_material_index >= surface_count:
		push_warning("Canvas material index %d out of range (0-%d)" % [canvas_material_index, surface_count - 1])
		return
	
	# Get existing material as template (prefer override, fallback to mesh material)
	var template_material: Material = mesh_instance.get_surface_override_material(canvas_material_index)
	if not template_material:
		template_material = mesh.surface_get_material(canvas_material_index)
	
	print("DEBUG WallObjectRigid: Template material: %s" % template_material)
	
	# Create new StandardMaterial3D for the texture
	var new_material: StandardMaterial3D
	if template_material and template_material is StandardMaterial3D:
		# Duplicate existing StandardMaterial3D to preserve settings
		new_material = (template_material as StandardMaterial3D).duplicate()
		print("DEBUG WallObjectRigid: Duplicated existing StandardMaterial3D")
	else:
		# Create new StandardMaterial3D with default settings
		new_material = StandardMaterial3D.new()
		print("DEBUG WallObjectRigid: Created new StandardMaterial3D (template was: %s)" % template_material)
	
	print("DEBUG WallObjectRigid: Current material settings before modification:")
	print("DEBUG WallObjectRigid: - albedo_color: %s" % new_material.albedo_color)
	print("DEBUG WallObjectRigid: - albedo_texture: %s" % new_material.albedo_texture)
	print("DEBUG WallObjectRigid: - shading_mode: %s" % new_material.shading_mode)
	print("DEBUG WallObjectRigid: - vertex_color_use_as_albedo: %s" % new_material.vertex_color_use_as_albedo)
	
	# Configure material for texture display
	new_material.albedo_color = Color.WHITE
	new_material.albedo_texture = texture
	new_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	new_material.vertex_color_use_as_albedo = false
	
	print("DEBUG WallObjectRigid: ✓ Applied texture to material")
	print("DEBUG WallObjectRigid: New material settings:")
	print("DEBUG WallObjectRigid: - albedo_color: %s" % new_material.albedo_color)
	print("DEBUG WallObjectRigid: - albedo_texture: %s (ID: %s)" % [new_material.albedo_texture, new_material.albedo_texture.get_instance_id()])
	
	# Apply zoom-to-fit scaling to the new material
	var canvas_size: Vector2 = Vector2(1.0, 1.0)  # Default canvas size - TODO: get actual canvas size
	_apply_zoom_to_fit_scaling(new_material, texture, canvas_size)
	
	# Apply material using override (this is the key fix!)
	mesh_instance.set_surface_override_material(canvas_material_index, new_material)
	print("DEBUG WallObjectRigid: ✓ Set surface override material at index %d" % canvas_material_index)
	
	# Verify the material was applied
	var applied_material: Material = mesh_instance.get_surface_override_material(canvas_material_index)
	print("DEBUG WallObjectRigid: Verification - Applied material: %s" % applied_material)
	if applied_material and applied_material is StandardMaterial3D:
		var std_mat: StandardMaterial3D = applied_material as StandardMaterial3D
		print("DEBUG WallObjectRigid: Verification - Applied texture: %s" % std_mat.albedo_texture)
	
	print("DEBUG WallObjectRigid: ✓ Successfully applied painting texture with material override")
	


func _apply_zoom_to_fit_scaling(material: StandardMaterial3D, texture: Texture2D, canvas_size: Vector2):
	## Apply zoom-to-fit scaling to material texture transform
	## Scales texture to fill canvas completely without letterboxing
	
	if not material or not texture:
		push_warning("Invalid material or texture for scaling")
		return
	
	# Calculate aspect ratios
	var texture_width: float = float(texture.get_width())
	var texture_height: float = float(texture.get_height())
	var texture_aspect_ratio: float = texture_width / texture_height
	
	var canvas_aspect_ratio: float = canvas_size.x / canvas_size.y
	
	print("DEBUG WallObjectRigid: Texture dimensions: %dx%d (aspect: %.3f)" % [texture_width, texture_height, texture_aspect_ratio])
	print("DEBUG WallObjectRigid: Canvas dimensions: %.3fx%.3f (aspect: %.3f)" % [canvas_size.x, canvas_size.y, canvas_aspect_ratio])
	
	# For now, let's try a simple 1:1 mapping first to see if the texture shows up at all
	# We can optimize the scaling later once we confirm the texture is visible
	var scale_x: float = 1.0
	var scale_y: float = 1.0
	
	# If we want to implement proper zoom-to-fit later:
	# Calculate scale factors for both dimensions
	var scale_factor_x: float = canvas_size.x / texture_width
	var scale_factor_y: float = canvas_size.y / texture_height
	
	# For zoom-to-fit (fill canvas, may crop), use the larger scale factor
	var zoom_scale_factor: float = max(scale_factor_x, scale_factor_y)
	
	# For fit-to-canvas (show entire image, may letterbox), use the smaller scale factor
	var fit_scale_factor: float = min(scale_factor_x, scale_factor_y)
	
	print("DEBUG WallObjectRigid: Scale factors - X: %.3f, Y: %.3f" % [scale_factor_x, scale_factor_y])
	print("DEBUG WallObjectRigid: Zoom-to-fit factor: %.3f, Fit-to-canvas factor: %.3f" % [zoom_scale_factor, fit_scale_factor])
	
	# For debugging, let's start with no scaling to see if texture appears
	# TODO: Implement proper scaling once texture visibility is confirmed
	scale_x = 1.0
	scale_y = 1.0
	
	print("DEBUG WallObjectRigid: Using scale factors: X=%.3f, Y=%.3f (debug mode - no scaling)" % [scale_x, scale_y])
	
	# Apply scaling via UV transform
	material.uv1_scale = Vector3(scale_x, scale_y, 1.0)
	
	# Also try setting UV offset to center the texture
	material.uv1_offset = Vector3(0.0, 0.0, 0.0)
	
	print("DEBUG WallObjectRigid: Applied UV scaling: %s" % material.uv1_scale)
	print("DEBUG WallObjectRigid: Applied UV offset: %s" % material.uv1_offset)


func _debug_list_all_mesh_nodes(node: Node, indent: String = ""):
	## Debug helper to list all mesh nodes in the object hierarchy
	
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		print("DEBUG WallObjectRigid: %sMeshInstance3D: '%s' (surfaces: %d)" % [indent, node.name, mesh_instance.get_surface_override_material_count()])
		
		# List materials for each surface
		for i in range(mesh_instance.get_surface_override_material_count()):
			var override_mat: Material = mesh_instance.get_surface_override_material(i)
			var mesh_mat: Material = null
			if mesh_instance.mesh and i < mesh_instance.mesh.get_surface_count():
				mesh_mat = mesh_instance.mesh.surface_get_material(i)
			print("DEBUG WallObjectRigid: %s  Surface %d - Override: %s, Mesh: %s" % [indent, i, override_mat, mesh_mat])
	
	# Recursively check children
	for child in node.get_children():
		_debug_list_all_mesh_nodes(child, indent + "  ")


func _find_similar_mesh_node(target_name: String) -> Node:
	## Try to find a mesh node with a similar name (case-insensitive, partial match)
	
	var all_mesh_nodes: Array[Node] = []
	_collect_mesh_nodes(self, all_mesh_nodes)
	
	# First try exact case-insensitive match
	for mesh_node in all_mesh_nodes:
		if mesh_node.name.to_lower() == target_name.to_lower():
			print("DEBUG WallObjectRigid: Found exact case-insensitive match: %s" % mesh_node.name)
			return mesh_node
	
	# Then try partial matches
	for mesh_node in all_mesh_nodes:
		if target_name.to_lower() in mesh_node.name.to_lower() or mesh_node.name.to_lower() in target_name.to_lower():
			print("DEBUG WallObjectRigid: Found partial match: %s (looking for %s)" % [mesh_node.name, target_name])
			return mesh_node
	
	return null


func _collect_mesh_nodes(node: Node, mesh_nodes: Array[Node]):
	## Helper to collect all MeshInstance3D nodes recursively
	
	if node is MeshInstance3D:
		mesh_nodes.append(node)
	
	for child in node.get_children():
		_collect_mesh_nodes(child, mesh_nodes)

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
