@tool
# Helper class for spawning objects
class_name SpawnData
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const ITEM_CENTER_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)  # This is unique in the code with the 1m vertical

#--- public variables - order: export > normal var > onready --------------------------------------

@export var scene_path: String = ""
@export var amount: int = 1: set = _set_amount

#--- private variables - order: export > normal var > onready -------------------------------------

@export var _transforms: Array

# Array of Dictionary of properties to be applied to the spawned node, after spawn.
@export var _custom_properties: Array

var _has_spawned := false

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	_set_amount(1)


func _to_string() -> String:
	var msg := "[SpawnData:%s | amount: %s scene_path: %s tranforms: %s]"%[
			get_instance_id(), amount, scene_path, _transforms
	]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Core spawning interface - maintains backward compatibility
func spawn_item_in(node: Node, should_log := false) -> void:
	if _has_spawned:
		return
	
	var item_scene : PackedScene = load(scene_path)
	if !is_instance_valid(item_scene):
		print("ERROR SpawnData: Failed to load scene: %s" % scene_path)
		return
	
	for index in amount:
		var item = item_scene.instantiate()
		if !is_instance_valid(item):
			print("ERROR SpawnData: Failed to instantiate scene: %s" % scene_path)
			continue
		
		if item is Node3D:
			var node3d_item = item as Node3D
			node3d_item.transform = _transforms[index]
		
		# Apply custom properties using extracted method
		var custom_properties := _custom_properties[index] as Dictionary
		_apply_custom_properties(item, custom_properties)
		
		node.add_child(item, true)
		
		# Apply post-spawn setup using extracted method
		_post_spawn_item_setup(item)
		
		# Handle wall-specific properties that need access to custom_properties
		_handle_wall_object_properties(item, custom_properties)
	
	_has_spawned = true


## New anchor-based spawning interface for future phases
## This method signature is prepared for anchor-based spawning systems
func spawn_at_anchors(anchors: Array, rng: RandomNumberGenerator = null, should_log := false) -> Array:
	push_error("spawn_at_anchors() must be implemented in subclass")
	return []


## CellFilter integration interface methods
## These provide hooks for CellFilter-based spawning systems

## Gets valid spawn cells using the provided CellFilter
func get_valid_spawn_cells(world_data: WorldData, room_data: RoomData, cell_filter: CellFilter, rng: RandomNumberGenerator = null) -> Array:
	if not cell_filter:
		push_warning("SpawnData.get_valid_spawn_cells(): No CellFilter provided")
		return []
	
	return cell_filter.filter_cells(world_data, room_data, rng)


## Spawns items at filtered cell positions
func spawn_at_filtered_cells(node: Node, world_data: WorldData, cells: Array, should_log := false) -> void:
	if _has_spawned:
		return
	
	if cells.is_empty():
		if should_log:
			print("SpawnData: No valid cells provided for spawning")
		return
	
	var item_scene: PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		print("ERROR SpawnData: Failed to load scene: %s" % scene_path)
		return
	
	var spawn_count := mini(amount, cells.size())
	
	for index in spawn_count:
		var cell_index: int = cells[index]
		var cell_position := CellFilter.get_cell_position(world_data, cell_index)
		
		var item = item_scene.instantiate()
		if not is_instance_valid(item):
			print("ERROR SpawnData: Failed to instantiate scene: %s" % scene_path)
			continue
		
		if item is Node3D:
			var node3d_item = item as Node3D
			# Use cell position with center offset
			var spawn_position := cell_position + _get_center_offset()
			node3d_item.global_position = spawn_position
			
			# Apply stored transform if available
			if index < _transforms.size():
				var stored_transform := _transforms[index] as Transform3D
				# Preserve the position we just set, but apply rotation
				node3d_item.transform.basis = stored_transform.basis
		
		# Apply custom properties
		if index < _custom_properties.size():
			var custom_properties := _custom_properties[index] as Dictionary
			_apply_custom_properties(item, custom_properties)
		
		node.add_child(item, true)
		
		# Apply item-specific post-spawn logic
		_post_spawn_item_setup(item)
	
	_has_spawned = true


func set_center_position_in_cell(cell_position: Vector3, instance_index := INF) -> void:
	if amount > 1 and instance_index == INF:
		push_warning("Setting the same position for multiple item instances")
	
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform := Transform3D.IDENTITY.translated(cell_position + _get_center_offset())
		_transforms[i] = transform


# This calculates the center position of the cell and then tries to find a random position 
# around it, inside a range from min_radius to max_radius away from center
func set_random_position_in_cell(
		rng: RandomNumberGenerator,
		cell_position: Vector3, 
		min_radius: float, 
		max_radius: float, 
		p_angle := INF,
		instance_index := INF
) -> void:
	if p_angle != INF and instance_index == INF:
		push_warning("Setting the same position for multiple item instances")
	
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform := _transforms[i] as Transform3D
		var angle := p_angle
		var center_position := cell_position + _get_center_offset()
		
		if angle == INF:
			angle = rng.randf_range(0.0, TAU)
		
		var radius := rng.randf_range(min_radius, max_radius)
		var random_direction := Vector3(cos(angle), 0.0, sin(angle)).normalized()
		var polar_coordinate := random_direction * radius
		var random_position := center_position + polar_coordinate
		transform = transform.translated(random_position)
		transform.basis = transform.basis.rotated(Vector3.UP, angle)
		_transforms[i] = transform


func set_random_rotation_in_all_axis(
		rng: RandomNumberGenerator, 
		limit_x:= TAU, 
		limit_y := TAU, 
		limit_z := TAU, 
		instance_index := INF
) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform3D
		var axis_angle := Vector3(
			rng.randf_range(0, limit_x),
			rng.randf_range(0, limit_y),
			rng.randf_range(0, limit_z)
		)
		var random_rotation := Quaternion(axis_angle.normalized(), axis_angle.length())
		transform.basis = Basis(random_rotation)
		_transforms[i] = transform


func set_y_rotation(angle_rad: float, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform3D
		transform.basis = transform.basis.rotated(Vector3.UP, angle_rad)
		_transforms[i] = transform


func set_position_in_cell(cell_position: Vector3, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform3D
		transform.origin = cell_position
		_transforms[i] = transform


func set_custom_property(key: String, value, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		_custom_properties[i][key] = value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## Applies custom properties to a spawned item
## Extracted from spawn_item_in() for reusability
func _apply_custom_properties(item: Node, custom_properties: Dictionary) -> void:
	for key in custom_properties:
		var value = custom_properties[key]
		
		# Try to set the property - Godot will handle validation internally
		var property_list = item.get_property_list()
		var has_property := false
		for prop in property_list:
			if prop.name == key:
				has_property = true
				break
		
		if has_property:
			item.set(key, value)


## Handles post-spawn setup for items
## Extracted from spawn_item_in() for reusability
func _post_spawn_item_setup(item: Node) -> void:
	# Having this here instead of ready() function of light fixes blueprint SHOULD_PLACE candle emissive material bug
	if item is CandleItem or item is CandelabraItem:
		item.light()
	
	# Special handling for wall objects with WallAttachmentComponent
	var wall_attachment_component = item.get_node_or_null("WallAttachmentComponent")
	if wall_attachment_component:
		print("=== WALL OBJECT SPAWN DEBUG ===")
		print("WALL SPAWN: Found WallAttachmentComponent on %s" % item.name)
		print("WALL SPAWN: Scene path: %s" % scene_path)
		print("WALL SPAWN: Final position: %s" % item.global_position)
		# Note: wall_direction handling moved to _apply_custom_properties
		print("=== END WALL OBJECT SPAWN DEBUG ===")
	
	# Special handling for painting texture application
	if item is WallObjectRigid:
		var wall_object_rigid = item as WallObjectRigid
		print("WALL SPAWN: Item is WallObjectRigid, is_painting: %s" % wall_object_rigid.is_painting)
		# Note: painting texture handling moved to _apply_custom_properties

func _set_amount(value: int) -> void:
	amount = int(max(1, value))
	var old_tranforms = _transforms.duplicate()
	_transforms.resize(amount)
	_custom_properties.resize(amount)
	
	_transforms.fill(Transform3D.IDENTITY)
	
	for index in _transforms.size():
		if index < old_tranforms.size() and _transforms[index] != old_tranforms[index]:
			_transforms[index] = old_tranforms[index]
		if _custom_properties[index] == null:
			_custom_properties[index] = {}


## Handles wall-specific properties that need access to the custom_properties dictionary
func _handle_wall_object_properties(item: Node, custom_properties: Dictionary) -> void:
	# Special handling for wall objects with WallAttachmentComponent
	var wall_attachment_component = item.get_node_or_null("WallAttachmentComponent")
	if wall_attachment_component:
		var wall_direction = custom_properties.get("wall_direction", -1)
		print("WALL SPAWN: Custom properties: %s" % custom_properties)
		if wall_direction != -1:
			print("WALL SPAWN: Setting wall_direction on component: %d" % wall_direction)
			wall_attachment_component.wall_direction = wall_direction
			print("WALL SPAWN: Manually calling setup_wall_attachment")
			wall_attachment_component.call_deferred("setup_wall_attachment")
		else:
			print("WALL SPAWN ERROR: Wall object missing wall_direction property!")
	
	# Special handling for painting texture application
	if item is WallObjectRigid:
		var wall_object_rigid = item as WallObjectRigid
		var painting_texture_path = custom_properties.get("painting_texture_path", "")
		print("WALL SPAWN: Painting texture path from custom properties: '%s'" % painting_texture_path)
		if not painting_texture_path.is_empty():
			print("WALL SPAWN: ✓ Found painting texture path: %s" % painting_texture_path)
			print("WALL SPAWN: Calling set_painting_texture_path on wall object")
			wall_object_rigid.set_painting_texture_path(painting_texture_path)
		else:
			print("WALL SPAWN: ✗ No painting texture path found in custom properties")
			if wall_object_rigid.is_painting:
				print("WALL SPAWN: WARNING - This is a painting but no texture path was set!")


func _get_center_offset() -> Vector3:
	return ITEM_CENTER_POSITION_OFFSET

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
