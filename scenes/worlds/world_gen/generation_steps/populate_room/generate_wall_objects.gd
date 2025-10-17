@tool
class_name GenerateWallObjects
extends GenerationStep

## Generates wall objects on convex corner pillars
## Places wall objects randomly on pillar sides that face outward between two CORRIDOR cells

### Member Variables and Dependencies -------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export var portrait_frame_spawn_list: Resource
@export var square_frame_spawn_list: Resource
@export var landscape_frame_spawn_list: Resource
@export var wide_landscape_frame_spawn_list: Resource

@export var wall_object_spawn_list_resource: Resource  # For non-painting wall objects

@export var _spawn_chance: float = 0.25  # Chance to spawn on each valid pillar side
@export var _wall_offset_multiplier: float = 0.225  # How far from pillar surface to place objects
@export var _wall_mount_height: float = 1.6  # Height above floor to mount wall objects
@export var paintings_directory: String = "res://resources/art/paintings/"

#--- private variables - order: export > normal var > onready -------------------------------------
var _rng := RandomNumberGenerator.new()
var _pillar_filter := PillarPlacementCellFilter.new()
var _painting_image_paths: Array[String] = []
var _loaded_painting_textures: Array[Texture2D] = []

### Built-in Virtual Overrides --------------------------------------------------------------------

func _execute_step(data: WorldData, _gen_data: Dictionary, generation_seed: int):
	_rng.seed = generation_seed
	
	# Scan for painting images
	_scan_painting_images()
	
	# Configure pillar filter with CORRIDOR cell type requirement and spawn chance
	_pillar_filter.set_required_adjacent_cell_types([WorldData.CellType.CORRIDOR])
	_pillar_filter.set_spawn_chance(_spawn_chance)
	_pillar_filter.set_wall_offset_multiplier(_wall_offset_multiplier)
	_pillar_filter.set_wall_mount_height(_wall_mount_height)
	
	# Debug: First let's see how many pillars exist total
	var total_pillars = _count_total_pillars(data)
	print("DEBUG: Total pillars in world: %d" % total_pillars)
	
	# Use PillarPlacementCellFilter to get valid pillar sides
	var valid_pillar_sides = _pillar_filter.get_valid_pillar_sides(data, _rng)
	print("Found %d valid pillar sides for potential wall object placement" % valid_pillar_sides.size())
	
	var objects_placed = 0
	for pillar_data in valid_pillar_sides:
		_spawn_wall_object_on_pillar(data, pillar_data)
		objects_placed += 1
	
	print("Placed %d wall objects out of %d valid pillar sides" % [objects_placed, valid_pillar_sides.size()])
	
	# Clean up loaded painting textures
	_cleanup_painting_textures()

### Private Methods -------------------------------------------------------------------------------

# Count total pillars for debugging
func _count_total_pillars(data: WorldData) -> int:
	var count = 0
	print("DEBUG: Scanning for pillars in %dx%d world..." % [data.world_size_x, data.world_size_z])
	
	# Pillars are at vertices, so check all positions
	for x in range(data.world_size_x):
		for z in range(data.world_size_z):
			var cell_index = CellFilter.get_cell_index(data, x, z)
			var pillar_tile = data.get_pillar_tile_index(cell_index)
			var cell_type = CellFilter.get_cell_type(data, cell_index)
			
			if pillar_tile != -1:
				count += 1
				#print("DEBUG: Found pillar at vertex (%d, %d) - tile: %d, cell_type: %s" % [x, z, pillar_tile, data.CellType.keys()[cell_type]])
	
	return count


# Old pillar finding methods removed - now handled by PillarPlacementCellFilter
# This consolidates the logic and makes it reusable for other wall-mounted objects


func _spawn_wall_object_on_pillar(data: WorldData, pillar_data: Dictionary):
	print("DEBUG GenerateWallObjects: === SPAWNING WALL OBJECT ===")
	
	var spawn_list = wall_object_spawn_list_resource as ObjectSpawnList
	if not spawn_list:
		push_warning("No wall object spawn list resource assigned")
		return
	
	var spawn_data = spawn_list.get_random_spawn_data(_rng)
	if spawn_data.scene_path.is_empty():
		print("ERROR GenerateWallObjects: Empty scene path from spawn list")
		return
	
	print("DEBUG GenerateWallObjects: Selected scene: %s" % spawn_data.scene_path)
	
	# Check if this is a painting and handle accordingly
	print("DEBUG GenerateWallObjects: Loading wall object scene to check if it's a painting...")
	var wall_object_scene = load(spawn_data.scene_path)
	if not wall_object_scene:
		print("ERROR GenerateWallObjects: Failed to load wall object scene: %s" % spawn_data.scene_path)
		return
	
	print("DEBUG GenerateWallObjects: Instantiating wall object to check is_painting property...")
	var wall_object_instance = wall_object_scene.instantiate()
	var is_painting_object = false
	
	if wall_object_instance is WallObjectRigid:
		var wall_object_rigid = wall_object_instance as WallObjectRigid
		is_painting_object = wall_object_rigid.is_painting
		print("DEBUG GenerateWallObjects: ✓ Wall object is WallObjectRigid, is_painting: %s" % is_painting_object)
		print("DEBUG GenerateWallObjects: Canvas mesh name: '%s', Canvas material index: %d" % [wall_object_rigid.canvas_mesh_name, wall_object_rigid.canvas_material_index])
	else:
		print("DEBUG GenerateWallObjects: ✗ Wall object is not WallObjectRigid, type: %s" % wall_object_instance.get_class())
	
	# Free the temporary instance
	wall_object_instance.queue_free()
	
	# If it's a painting, use painting-specific logic
	if is_painting_object:
		print("DEBUG GenerateWallObjects: ✓ This is a painting! Using painting-specific spawn logic...")
		_spawn_painting_with_texture(data, pillar_data)
		return
	
	# Otherwise, spawn as regular wall object using existing logic
	print("DEBUG GenerateWallObjects: This is not a painting, using regular wall object spawn logic...")
	_spawn_regular_wall_object(data, pillar_data, spawn_data)


func _get_rotation_for_direction(direction: int) -> float:
	match direction:
		WorldData.Direction.NORTH:
			return 0.0
		WorldData.Direction.EAST:
			return PI * 1.5
		WorldData.Direction.SOUTH:
			return PI
		WorldData.Direction.WEST:
			return PI * 0.5
		_:
			return 0.0


# Wall offset and directional offset methods moved to PillarPlacementCellFilter for reusability


func _try_place_in_nearby_cell(data: WorldData, spawn_data: SpawnData, object_position: Vector3, direction: int, pillar_x: int, pillar_z: int):
	## Try to place the wall object in a nearby free cell
	## This is a fallback when the primary target cell is occupied
	
	print("DEBUG GenerateWallObjects: Trying to place in nearby cell from position %s" % object_position)
	
	# Try cells in expanding rings around the target position
	var max_search_radius := 3
	var placed := false
	
	for search_radius in range(1, max_search_radius + 1):
		if placed:
			break
		
		# Try positions in a ring at this radius
		for offset_x in range(-search_radius, search_radius + 1):
			for offset_z in range(-search_radius, search_radius + 1):
				if placed:
					break
				
				# Skip positions not on the current ring boundary
				if abs(offset_x) != search_radius and abs(offset_z) != search_radius:
					continue
				
				var test_position := object_position + Vector3(offset_x * 0.5, 0, offset_z * 0.5)
				var test_cell_index := CellFilter.get_cell_from_local_position(data, test_position)
				
				if test_cell_index != -1 and CellFilter.get_cell_type(data, test_cell_index) == data.CellType.CORRIDOR:
					var existing_objects = data.get_objects_to_spawn()
					if not existing_objects.has(test_cell_index):
						# Update spawn data position to the new location
						spawn_data.set_position_in_cell(test_position)
						data.set_object_spawn_data_to_cell(test_cell_index, spawn_data)
						print("DEBUG GenerateWallObjects: ✓ Placed wall object in nearby cell %d at %s (radius %d)" % [test_cell_index, test_position, search_radius])
						placed = true
	
	if not placed:
		print("DEBUG GenerateWallObjects: Could not find any nearby free cell within radius %d" % max_search_radius)


func _get_frame_spawn_list_for_aspect_ratio(aspect_ratio: String) -> Resource:
	## Returns the appropriate spawn list resource for the given aspect ratio
	## Falls back to wall_object_spawn_list_resource if specific frame list is null
	
	print("DEBUG GenerateWallObjects: Getting frame spawn list for aspect ratio: %s" % aspect_ratio)
	
	var frame_spawn_list: Resource
	
	match aspect_ratio:
		"portrait":
			frame_spawn_list = portrait_frame_spawn_list
		"square":
			frame_spawn_list = square_frame_spawn_list
		"landscape":
			frame_spawn_list = landscape_frame_spawn_list
		"wide_landscape":
			frame_spawn_list = wide_landscape_frame_spawn_list
		_:
			print("WARNING GenerateWallObjects: Unknown aspect ratio '%s', using square frame" % aspect_ratio)
			frame_spawn_list = square_frame_spawn_list
	
	# Fallback to wall_object_spawn_list_resource if frame list is null
	if not frame_spawn_list:
		print("WARNING GenerateWallObjects: No frame spawn list for aspect ratio '%s', using fallback" % aspect_ratio)
		frame_spawn_list = wall_object_spawn_list_resource
	
	print("DEBUG GenerateWallObjects: Selected frame spawn list: %s" % ("valid" if frame_spawn_list else "null"))
	return frame_spawn_list


func _spawn_painting_with_texture(data: WorldData, pillar_data: Dictionary):
	## Spawn a painting with randomly selected texture and appropriate frame
	
	print("DEBUG GenerateWallObjects: === SPAWNING PAINTING WITH TEXTURE ===")
	
	# Check if we have any painting images
	if _painting_image_paths.is_empty():
		print("WARNING GenerateWallObjects: No painting images found, using fallback spawn list")
		var fallback_spawn_list = wall_object_spawn_list_resource as ObjectSpawnList
		if fallback_spawn_list:
			var fallback_spawn_data = fallback_spawn_list.get_random_spawn_data(_rng)
			_spawn_regular_wall_object(data, pillar_data, fallback_spawn_data)
		return
	
	# Select random image
	var random_image_index = _rng.randi() % _painting_image_paths.size()
	var selected_image_path = _painting_image_paths[random_image_index]
	print("DEBUG GenerateWallObjects: Selected painting image: %s" % selected_image_path)
	
	# Detect aspect ratio
	var aspect_ratio = _detect_image_aspect_ratio(selected_image_path)
	print("DEBUG GenerateWallObjects: Detected aspect ratio: %s" % aspect_ratio)
	
	# Get appropriate frame spawn list
	var frame_spawn_list = _get_frame_spawn_list_for_aspect_ratio(aspect_ratio) as ObjectSpawnList
	if not frame_spawn_list:
		print("ERROR GenerateWallObjects: No valid frame spawn list found, aborting painting spawn")
		return
	
	print("DEBUG GenerateWallObjects: Using frame spawn list for aspect ratio: %s" % aspect_ratio)
	
	# Get frame spawn data
	var frame_spawn_data = frame_spawn_list.get_random_spawn_data(_rng)
	if frame_spawn_data.scene_path.is_empty():
		print("ERROR GenerateWallObjects: Empty scene path from frame spawn list")
		return
	
	print("DEBUG GenerateWallObjects: Selected frame scene: %s" % frame_spawn_data.scene_path)
	
	# Use the frame spawn data with texture
	_spawn_regular_wall_object_with_texture(data, pillar_data, frame_spawn_data, selected_image_path)


func _spawn_regular_wall_object(data: WorldData, pillar_data: Dictionary, spawn_data: SpawnData):
	## Spawn a regular (non-painting) wall object using the original logic
	
	print("DEBUG GenerateWallObjects: Spawning regular wall object")
	_spawn_regular_wall_object_with_texture(data, pillar_data, spawn_data, "")


func _spawn_regular_wall_object_with_texture(data: WorldData, pillar_data: Dictionary, spawn_data: SpawnData, texture_path: String):
	## Common wall object spawning logic with optional texture application
	
	# Position wall object on the pillar side using PillarPlacementCellFilter helper methods
	var pillar_position = pillar_data.position as Vector3
	var direction = pillar_data.direction as int
	var wall_offset = _pillar_filter.get_wall_offset_for_direction(direction)
	
	print("DEBUG GenerateWallObjects: Pillar position: %s" % pillar_position)
	print("DEBUG GenerateWallObjects: Wall direction: %d (%s)" % [
		direction,
		["NORTH", "EAST", "SOUTH", "WEST"][direction] if direction < 4 else "UNKNOWN"
	])
	print("DEBUG GenerateWallObjects: Wall offset vector: %s" % wall_offset)
	
	# Position slightly away from pillar surface and at proper wall mounting height
	# Add directional offset to ensure each pillar side maps to a unique cell
	var base_offset = wall_offset * (WorldData.CELL_SIZE * _wall_offset_multiplier)
	var directional_offset = _pillar_filter.get_directional_cell_offset(direction, pillar_data.pillar_x, pillar_data.pillar_z)
	var object_position = pillar_position + base_offset + directional_offset
	object_position.y += _wall_mount_height  # Mount at proper height above floor
	print("DEBUG GenerateWallObjects: Calculated object position: %s (raised %fm for wall mounting)" % [object_position, _wall_mount_height])
	print("DEBUG GenerateWallObjects: Base offset: %s, Directional offset: %s" % [base_offset, directional_offset])
	
	spawn_data.set_position_in_cell(object_position)
	
	# DEBUG: Log detailed spawn positioning
	print("SPAWN DEBUG - Final object_position set in spawn_data: ", object_position)
	print("SPAWN DEBUG - _wall_offset_multiplier: ", _wall_offset_multiplier)
	print("SPAWN DEBUG - WorldData.CELL_SIZE: ", WorldData.CELL_SIZE)
	print("SPAWN DEBUG - Calculated base_offset magnitude: ", base_offset.length())
	
	# Rotate to face outward from pillar
	var rotation_angle = _get_rotation_for_direction(direction)
	spawn_data.set_y_rotation(rotation_angle)
	print("DEBUG GenerateWallObjects: Set rotation angle: %f radians (%f degrees)" % [
		rotation_angle, rad_to_deg(rotation_angle)
	])
	
	# Store wall direction and position info for the wall object to use
	spawn_data.set_custom_property("wall_direction", direction)
	spawn_data.set_custom_property("pillar_position", pillar_position)
	spawn_data.set_custom_property("wall_offset", wall_offset)
	
	# Store texture path if provided (for paintings)
	if not texture_path.is_empty():
		print("DEBUG GenerateWallObjects: ✓ Setting painting texture path in spawn data: %s" % texture_path)
		spawn_data.set_custom_property("painting_texture_path", texture_path)
		print("DEBUG GenerateWallObjects: ✓ Successfully set painting texture path custom property")
	else:
		print("DEBUG GenerateWallObjects: ✗ No texture path provided (texture_path is empty)")
	
	print("DEBUG GenerateWallObjects: Set custom properties - wall_direction: %d" % direction)
	
	# Get the target cell index for placement using the adjusted position
	var target_cell_index = CellFilter.get_cell_from_local_position(data, object_position)
	var pillar_x = pillar_data.pillar_x as int
	var pillar_z = pillar_data.pillar_z as int
	
	print("DEBUG GenerateWallObjects: Target cell index: %d (from position %s)" % [target_cell_index, object_position])
	
	# Check if target cell is valid and free
	if target_cell_index != -1 and CellFilter.get_cell_type(data, target_cell_index) == data.CellType.CORRIDOR:
		# Check if this specific cell+direction combination is already occupied
		var existing_objects = data.get_objects_to_spawn()
		var cell_occupied = existing_objects.has(target_cell_index)
		
		if not cell_occupied:
			data.set_object_spawn_data_to_cell(target_cell_index, spawn_data)
			print("DEBUG GenerateWallObjects: ✓ Successfully placed wall object spawn data at cell %d" % target_cell_index)
			print("DEBUG GenerateWallObjects: Final SpawnData: %s" % spawn_data.to_string())
			
			# Apply texture if this is a painting
			if not texture_path.is_empty():
				print("DEBUG GenerateWallObjects: Texture will be applied during object instantiation")
		else:
			print("DEBUG GenerateWallObjects: Cell %d already has an object, trying nearby cells" % target_cell_index)
			_try_place_in_nearby_cell(data, spawn_data, object_position, direction, pillar_x, pillar_z)
	else:
		print("ERROR GenerateWallObjects: Cannot place wall object - target cell %d is invalid or not a corridor" % target_cell_index)
	
	print("DEBUG GenerateWallObjects: === END WALL OBJECT SPAWN ===")

func _scan_painting_images():
	## Scan paintings directory using ResourceLoader.list_directory for build compatibility
	## Supports recursive scanning of subdirectories for .jpg, .jpeg, .png files
	
	print("Scanning for painting images in: %s" % paintings_directory)
	_painting_image_paths.clear()
	
	# Start recursive scanning from the base directory
	_scan_directory_with_resource_loader(paintings_directory)
	
	print("Found %d painting images total" % _painting_image_paths.size())
	if _painting_image_paths.size() > 0:
		for path in _painting_image_paths:
			var aspect_ratio: String = _detect_image_aspect_ratio(path)
			print("  - %s [%s]" % [path, aspect_ratio])
	else:
		print("No painting images found during scanning")


func _scan_directory_with_resource_loader(directory_path: String):
	## Recursively scan directory using ResourceLoader.list_directory
	## This method works in exported builds unlike DirAccess
	
	print("Scanning directory: %s" % directory_path)
	
	# List all files in directory
	var files: PackedStringArray
	files = ResourceLoader.list_directory(directory_path)
	
	print("Found ", files.size(), " files/directories in directory:")
	for i in range(files.size()):
		print("  [", i, "] ", files[i])
	
	# Supported image extensions
	var supported_extensions: Array[String] = [".jpg", ".jpeg", ".png"]
	
	# Process each file
	for file in files:
		# Skip directories (they end with "/")
		if file.ends_with("/"):
			print("Skipping directory: ", file)
			# Recursively scan subdirectory
			var subdirectory_path: String = directory_path + file
			_scan_directory_with_resource_loader(subdirectory_path)
			continue
			
		# Check if file has supported image extension
		var file_lower: String = file.to_lower()
		var is_image: bool = false
		
		for ext in supported_extensions:
			if file_lower.ends_with(ext):
				is_image = true
				break
		
		if not is_image:
			print("Skipping non-image file: ", file)
			continue
		
		# Create full path
		var full_path: String = directory_path + file
		print("Processing image file: ", file, " -> ", full_path)
		
		_painting_image_paths.append(full_path)
		print("Found painting image: ", file)


func _detect_image_aspect_ratio(image_path: String) -> String:
	## Detect aspect ratio category of an image file
	## Returns: "portrait", "square", "landscape", or "wide_landscape"
	## Fallback: Returns "square" if image loading fails
	
	print("DEBUG: Loading image for aspect ratio detection: %s" % image_path)
	
	var image: Image = Image.new()
	var error: Error = image.load(image_path)
	
	if error != OK:
		print("ERROR: Failed to load image for aspect ratio detection: %s (Error: %d)" % [image_path, error])
		return "square"  # Fallback to square for failed loads
	
	var width: int = image.get_width()
	var height: int = image.get_height()
	print("DEBUG: Image dimensions: %dx%d" % [width, height])
	
	# Free the image to avoid memory leaks
	image = null
	
	# Handle edge case of zero dimensions
	if width <= 0 or height <= 0:
		print("ERROR: Invalid image dimensions for %s: %dx%d" % [image_path, width, height])
		return "square"
	
	# Calculate aspect ratio (width/height)
	var aspect_ratio: float = float(width) / float(height)
	print("DEBUG: Calculated aspect ratio: %.3f" % aspect_ratio)
	
	# Apply classification logic from specifications:
	# - Portrait: height > width * 1.2 (aspect_ratio < 1/1.2 ≈ 0.833)
	# - Square: 0.85 <= width/height <= 1.15
	# - Landscape: width > height * 1.2 AND width < height * 1.8 (1.2 < aspect_ratio < 1.8)
	# - Wide Landscape: width >= height * 1.8 (aspect_ratio >= 1.8)
	
	var category: String
	if aspect_ratio < (1.0 / 1.2):  # Portrait: height > width * 1.2
		category = "portrait"
	elif aspect_ratio >= 0.85 and aspect_ratio <= 1.15:  # Square
		category = "square"
	elif aspect_ratio > 1.2 and aspect_ratio < 1.8:  # Landscape
		category = "landscape"
	elif aspect_ratio >= 1.8:  # Wide Landscape
		category = "wide_landscape"
	else:
		# Edge case: falls between portrait and square thresholds
		category = "square"  # Default fallback
	
	print("DEBUG: Classified as: %s" % category)
	return category


# Legacy texture application method removed - texture application is now handled
# by the WallObjectRigid itself via set_painting_texture_path() and _apply_painting_texture()
# This eliminates duplicate albedo_texture setting and centralizes the logic


func _cleanup_painting_textures():
	## Clean up loaded painting textures to prevent memory leaks
	## Unreferences all loaded textures and clears the array
	
	print("DEBUG: Cleaning up %d loaded painting textures" % _loaded_painting_textures.size())
	
	# Unreference all loaded textures
	for texture in _loaded_painting_textures:
		if texture:
			# The texture will be garbage collected when no longer referenced
			pass
	
	# Clear the array
	_loaded_painting_textures.clear()
	
	print("DEBUG: Painting texture cleanup complete")

### -----------------------------------------------------------------------------------------------
