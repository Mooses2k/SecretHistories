extends Control

## Dynamic background system that displays multiple images with fading transitions
##
## This script manages a collection of background images that fade in and out
## with overlapping transitions, creating a dynamic visual effect.


# Exported parameters for customization
@export var fade_duration: float = 1.5  ## Duration of fade in/out animations
@export var display_time: float = 5.0  ## Time each image is displayed before transitioning
@export var background_directory: String = "resources/art/title_backgrounds/"  ## Directory containing background images
@export var zoom_scale: float = 1.3  ## Scale factor for zoom effect
@export var max_images: int = 3  ## Maximum number of images on screen at once
@export var target_image_scale = 0.6  # Use 67% of screen size (roughly 2/3)

# Special image handling
@export var special_image_path: String = "res://resources/art/title_backgrounds/title_cathedral_photo.jpg"
var special_image_shown: bool = false  ## Track if special image has been displayed

# Internal variables
var background_images: Array[String] = []  ## List of available background image paths (excluding special image)
var current_images: Array[Control] = []  ## Currently displayed images
var previous_image: String = ""  ## Last displayed image to prevent immediate repetition
var rng: RandomNumberGenerator = RandomNumberGenerator.new()  ## Random number generator for positioning
var active_tweens: Array[Tween] = []  ## Active tweens for memory management
var pan_tweens: Array[Tween] = []  ## Active panning tweens for smooth movement

# Node references
@onready var background_container: Node = $BackgroundContainer
@onready var image_container: Control = $BackgroundContainer/ImageContainer
@onready var transition_timer: Timer = $TransitionTimer


# Lifecycle methods
func _ready() -> void:
	## Initialize the dynamic background system
	load_background_images()
	rng.randomize()
	
	# Connect timer signal
	transition_timer.timeout.connect(_on_transition_timer_timeout)
	
	# Start the transition cycle
	transition_timer.wait_time = display_time
	transition_timer.start()
	
	# Show special cathedral image immediately without fade-in
	show_special_image()


func load_background_images() -> void:
	## Load all background images from the predefined list, excluding the special image
	print("Loading background images from: ", background_directory)
	
	# Predefined list of background image filenames to avoid DirAccess method not working in builds
	var image_filenames: Array[String] = [
		"06-00391-2082957616.png",
		"00008-787729727.png",
		"00009-1236426289.png",
		"00014-720767209.png",
		"00015-1928675650.png",
		"00020-187638769.png",
		"00035-3305186785.png",
		"00044-1825481839.png",
		"00054-3758638628.png",
		"00236-1921911877.png",
		"00305-2505864101.png",
		"00306-2505864102.png",
		"00318-252378031.png",
		"00332-3766491186.png",
		"00352-3959123771.png",
		"00373-2075715374.png",
		"00382-848652815.png",
		"00404-908592793.png",
		"00659-3865673013.png",
		"00787-2213723471.png",
		"00848-2078861591.png",
		"00852-1050146515.png",
		"00880-2251940560.png",
		"01036-2370997828.png",
	]
	
	# Convert to full paths and verify each image can be loaded
	for filename in image_filenames:
		var full_path: String = "res://" + background_directory + filename
		
		# Exclude the special cathedral image from random selection
		if full_path != special_image_path:
			# Verify the image can be loaded
			var test_image: Texture2D = load(full_path)
			if test_image:
				background_images.append(full_path)
				print("Found background image: ", filename)
			else:
				push_warning("Failed to load background image: " + full_path)
	
	print("Total background images found (excluding special): ", background_images.size())
	if background_images.is_empty():
		push_warning("No background images found in " + background_directory)


func show_special_image() -> void:
	## Show the special cathedral image immediately without fade-in, properly scaled to fit screen
	print("Showing special cathedral image immediately...")
	
	# Create a container for the special image
	var container: Control = Control.new()
	container.anchor_left = 0.0
	container.anchor_top = 0.0
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.modulate = Color(1, 1, 1, 1)  # Start fully visible (no fade-in)
	container.z_index = -1
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create the special image TextureRect
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.anchor_left = 0.0
	texture_rect.anchor_top = 0.0
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load and set the special image
	var image: Texture2D = load(special_image_path)
	if image:
		texture_rect.texture = image
		
		# Mark as special image
		container.set_meta("is_special", true)
		
		# Add TextureRect to container
		container.add_child(texture_rect)
		
		# Add to containers
		image_container.add_child(container)
		current_images.append(container)
		special_image_shown = true
		
		# Schedule fade out after display_time
		var special_timer = Timer.new()
		special_timer.wait_time = display_time
		special_timer.one_shot = true
		special_timer.timeout.connect(_on_special_image_timeout.bind(container, special_timer))
		add_child(special_timer)
		special_timer.start()
		
		print("Special cathedral image displayed successfully, will fade out in ", display_time, " seconds")
	else:
		push_warning("Failed to load special cathedral image: " + special_image_path)


func _on_special_image_timeout(texture_rect: Control, timer: Timer) -> void:
	## Handle special image timeout to fade it out and immediately transition to next image
	if is_instance_valid(texture_rect):
		start_fade_out(texture_rect)
		current_images.erase(texture_rect)
		special_image_shown = false
		print("Special cathedral image fading out, immediately transitioning to next image")
		
		# Immediately create and fade in next image
		var new_image: Control = create_new_image()
		start_fade_in(new_image)
	
	# Clean up timer
	if is_instance_valid(timer):
		timer.queue_free()


func create_new_image() -> Control:
	## Create a new TextureRect with a randomly selected background image, properly scaled
	print("Creating new background image...")
	
	# Create a container for the image
	var container: Control = Control.new()
	container.anchor_left = 0.0
	container.anchor_top = 0.0
	container.anchor_right = 0.0
	container.anchor_bottom = 0.0
	container.modulate = Color(1, 1, 1, 1)  # Keep container modulate at full opacity
	container.z_index = -1
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create the main image TextureRect
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.anchor_left = 0.0
	texture_rect.anchor_top = 0.0
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create material with shader for fade effect
	var material = ShaderMaterial.new()
	material.shader = preload("res://resources/shaders/edge_fade.gdshader")
	material.set_shader_parameter("overall_alpha", 0.0)  # Start transparent for fade in
	texture_rect.material = material
	
	# Add the image to container first
	container.add_child(texture_rect)
	
	# Select a random image that's not the same as the previous one
	var image_path: String = select_random_image()
	print("Selected image path: ", image_path)
	
	if image_path != "":
		var image: Texture2D = load(image_path)
		if image:
			texture_rect.texture = image
			
			# Scale to about 67% of screen size while maintaining aspect ratio
			var screen_size: Vector2 = Vector2(get_viewport().size)
			var target_scale = 0.6
			var scale_factor = min(
				target_image_scale * screen_size.x / image.get_size().x,
				target_image_scale * screen_size.y / image.get_size().y
			)
			container.size = image.get_size() * scale_factor
			
			# Position randomly within the left 2/3 of the screen with strong bias toward top areas
			var left_zone_width = screen_size.x * (1.0 / 2.0)  # Left half of screen width
			var pan_margin = container.size * 0.1  # Smaller margin for more positioning freedom
			
			# Calculate available space with large bottom margin to prevent going off-screen
			var max_x = left_zone_width - container.size.x - pan_margin.x
			var bottom_margin = container.size.y * 0.4  # Large bottom margin (40% of image height)
			var max_y = screen_size.y - container.size.y - bottom_margin
			
			# Clamp to ensure we don't go negative
			max_x = max(0, max_x)
			max_y = max(0, max_y)
			
			# X position - random across left zone
			var random_x = rng.randf_range(pan_margin.x, pan_margin.x + max_x)
			
			# Y position - heavily favor top areas of screen
			var top_quarter = screen_size.y * 0.25  # Top 1/4 of screen
			var middle_half = screen_size.y * 0.5   # Middle half of screen
			
			var random_y: float
			var rand_val = rng.randf()
			if rand_val < 0.5:  # 50% chance to place in top 1/4
				random_y = rng.randf_range(0, min(top_quarter, max_y))
			elif rand_val < 0.8:  # 30% chance to place in upper middle
				var start_y = min(top_quarter, max_y * 0.3)
				var end_y = min(middle_half, max_y * 0.7)
				random_y = rng.randf_range(start_y, end_y)
			else:  # 20% chance to place in lower areas
				var start_y = min(middle_half, max_y * 0.5)
				random_y = rng.randf_range(start_y, max_y)
			
			container.position = Vector2(random_x, random_y)
			print("DEBUG: Positioned image at: ", container.position, " (screen height: ", screen_size.y, ", top quarter: ", top_quarter, ")")
			
			previous_image = image_path
			print("Successfully loaded texture: ", image_path, " size: ", image.get_size(), " scaled to: ", container.size)
		else:
			print("ERROR: Failed to load texture: ", image_path)
	else:
		print("ERROR: No image path selected")
	
	# Add to containers
	image_container.add_child(container)
	current_images.append(container)
	print("Added new image container. Total images: ", current_images.size())
	
	return container


func select_random_image() -> String:
	## Select a random image from the available pool, avoiding immediate repetition
	if background_images.is_empty():
		return ""
	
	# If we only have one image, just return it
	if background_images.size() == 1:
		return background_images[0]
	
	# Try to find a different image than the previous one
	var attempts: int = 0
	var max_attempts: int = background_images.size()
	var selected_image: String = ""
	
	while attempts < max_attempts:
		var random_index: int = rng.randi_range(0, background_images.size() - 1)
		selected_image = background_images[random_index]
		
		# If we have more than one image, avoid the previous one
		if selected_image != previous_image or background_images.size() <= 1:
			break
		
		attempts += 1
	
	return selected_image


func start_zoom_in_effect(texture_rect: Control, duration: float) -> void:
	## Start zoom-in effect that continues through fade duration
	if not is_instance_valid(texture_rect):
		return
	
	# Calculate initial scale (start slightly zoomed out)
	var initial_scale = 1.0
	var final_scale = zoom_scale
	
	# Create zoom tween
	var zoom_tween: Tween = create_tween()
	zoom_tween.tween_property(texture_rect, "scale", 
		Vector2(final_scale, final_scale), duration)
	zoom_tween.set_trans(Tween.TRANS_LINEAR)
	
	active_tweens.append(zoom_tween)
	zoom_tween.finished.connect(_on_tween_finished.bind(zoom_tween))


func start_fade_in(texture_rect: Control) -> void:
	## Start the fade in animation for an image using Tween
	if not is_instance_valid(texture_rect):
		print("ERROR: Invalid texture_rect in start_fade_in")
		return
	
	texture_rect.show()
	var actual_texture_rect: TextureRect = texture_rect.get_child(0) as TextureRect
	var texture_name = actual_texture_rect.texture.resource_path if actual_texture_rect and actual_texture_rect.texture else "none"
	print("DEBUG: Starting fade in for container: ", texture_rect, " with texture: ", texture_name)
	print("DEBUG: Initial modulate: ", texture_rect.modulate, " fade_duration: ", fade_duration)
	
	# Start zoom effect that spans entire display time (fade_in + display + fade_out)
	if not texture_rect.has_meta("is_special"):
		start_continuous_zoom_effect(texture_rect)
	
	# Create a tween for fade in
	var tween: Tween = create_tween()
	# Get the actual TextureRect child from the container
	var fade_texture_rect: TextureRect = texture_rect.get_child(0) as TextureRect
	var material = fade_texture_rect.material if fade_texture_rect else null
	
	# Animate the shader's overall_alpha parameter if shader is present, otherwise use modulate
	if material is ShaderMaterial:
		tween.tween_property(material, "shader_parameter/overall_alpha", 1.0, fade_duration)
	else:
		# Fallback to modulate for images without shader (like special image)
		tween.tween_property(texture_rect, "modulate", Color(1, 1, 1, 1), fade_duration)
	
	# Store active tween for memory management
	active_tweens.append(tween)
	
	# Clean up tween when finished
	tween.finished.connect(_on_tween_finished.bind(tween))
	
	# Debug: Log when fade in completes
	tween.finished.connect(func(): print("DEBUG: Fade in completed for ", texture_rect))


func start_continuous_zoom_effect(texture_rect: Control) -> void:
	## Start zoom effect that spans the entire time the image is shown with more noticeable scaling
	if not is_instance_valid(texture_rect):
		return

	# Start with a smaller scale to make zoom more noticeable
	texture_rect.scale = Vector2(0.93, 0.93)
	
	# Calculate total duration: fade_in + display_time + fade_out
	var total_duration = fade_duration * 2 + display_time
	
	# Create continuous zoom tween with linear movement and ease in/out
	var zoom_tween: Tween = create_tween()
	zoom_tween.set_trans(Tween.TRANS_QUART)
	zoom_tween.set_ease(Tween.EASE_OUT)
	zoom_tween.tween_property(texture_rect, "scale",
		Vector2(zoom_scale, zoom_scale), total_duration)
	
	active_tweens.append(zoom_tween)
	zoom_tween.finished.connect(_on_tween_finished.bind(zoom_tween))


func start_fade_out(texture_rect: Control) -> void:
	## Start the fade out animation for an image using Tween
	if not is_instance_valid(texture_rect):
		return
	
	print("DEBUG: Starting fade out for container: ", texture_rect, " current modulate: ", texture_rect.modulate)
	
	# Create a tween for fade out
	var tween: Tween = create_tween()
	# Get the actual TextureRect child from the container
	var fade_out_texture_rect: TextureRect = texture_rect.get_child(0) as TextureRect
	var material = fade_out_texture_rect.material if fade_out_texture_rect else null
	
	# Animate the shader's overall_alpha parameter if shader is present, otherwise use modulate
	if material is ShaderMaterial:
		tween.tween_property(material, "shader_parameter/overall_alpha", 0.0, fade_duration)
	else:
		# Fallback to modulate for images without shader (like special image)
		tween.tween_property(texture_rect, "modulate", Color(1, 1, 1, 0), fade_duration)
	
	# Store active tween for memory management
	active_tweens.append(tween)
	
	# Clean up image when tween finishes
	tween.finished.connect(_on_fade_out_finished.bind(texture_rect, tween))
	
	# Debug: Log when fade out completes
	tween.finished.connect(func(): print("DEBUG: Fade out completed for ", texture_rect))


func _on_transition_timer_timeout() -> void:
	## Handle transition timer timeout to manage image transitions
	# Skip if special image is currently showing
	if special_image_shown:
		return
	
	# Always start fade out for the oldest image when timer triggers
	if current_images.size() > 0:
		var oldest_image: Control = current_images[0]
		start_fade_out(oldest_image)
		current_images.pop_front()
	
	# Always create and fade in a new image immediately
	var new_image: Control = create_new_image()
	start_fade_in(new_image)


func _on_fade_out_finished(texture_rect: Control, tween: Tween) -> void:
	## Handle fade out completion to clean up the image
	_on_tween_finished(tween)  # Clean up the tween first
	
	if is_instance_valid(texture_rect):
		texture_rect.queue_free()
		if current_images.has(texture_rect):
			current_images.erase(texture_rect)


func _on_tween_finished(tween: Tween) -> void:
	## Handle tween completion to clean up references
	if active_tweens.has(tween):
		active_tweens.erase(tween)


func _on_pan_tween_finished(tween: Tween) -> void:
	## Handle pan tween completion to clean up references
	if pan_tweens.has(tween):
		pan_tweens.erase(tween)
