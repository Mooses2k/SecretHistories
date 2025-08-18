class_name ImpactAudioManager
extends Node

## Manages impact-based audio for physics objects
## Handles impact detection and plays sounds with volume/pitch scaling based on impact intensity


signal impact_detected(impact_intensity: float)

## Audio configuration
var drop_sound : AudioStream
var max_noise_level : float = 5.0
var bus_name : String = "Effects"

## Impact detection variables
var impact_impulse_threshold : float = 1.0  ## Minimum impulse magnitude to trigger sound
var old_velocity : float = 0.0  ## Track previous velocity for change detection
var velocity_change_threshold : float = 0.17  ## Minimum velocity change to trigger sound
var cooldown_time : float = 0.05  ## Time between allowed collision sounds
var max_impact_intensity : float = 10.0  ## Maximum impact intensity for scaling
var mass_divisor : float = 8.0  ## Divisor for calculating impact threshold from mass

## Volume and pitch scaling ranges
var volume_min_db : float = -20.0
var volume_max_db : float = 5.0
var pitch_min_scale : float = 0.8
var pitch_max_scale : float = 1.5

## Internal state
var is_soundplayer_ready : bool = false
var old_contact_count : int = 0
var parent_body : RigidBody3D


func _ready():
	parent_body = get_parent() as RigidBody3D
	if not parent_body:
		push_error("ImpactAudioManager must be a child of a RigidBody3D")
		return
	 
	# Set impact threshold based on parent mass (will be updated by configure_for_object_type)
	impact_impulse_threshold = parent_body.mass / mass_divisor
	is_soundplayer_ready = true


## Configure the audio manager for different object types
func configure_for_object_type(object_type: String):
	match object_type:
		"large_object":
			max_impact_intensity = 10.0
			velocity_change_threshold = 0.17
			volume_min_db = -20.0
			volume_max_db = 5.0
			pitch_min_scale = 0.8
			pitch_max_scale = 1.5
			mass_divisor = 10.0
		"pickable_item":
			max_impact_intensity = 5.0
			velocity_change_threshold = 0.17
			volume_min_db = -25.0
			volume_max_db = 10.0
			pitch_min_scale = 0.7
			pitch_max_scale = 1.6
			mass_divisor = 18.0
		_:
			push_warning("Unknown object type: " + object_type)
	
	# Recalculate impact threshold with new mass divisor
	if parent_body:
		impact_impulse_threshold = parent_body.mass / mass_divisor


## Call this from the parent's _integrate_forces method
func process_impact_detection(state: PhysicsDirectBodyState3D) -> void:
	if not parent_body or not is_soundplayer_ready:
		return
	
	if LoadScene.loading:  # Skip during level loading
		return
	
	var current_velocity = state.linear_velocity.length()
	var velocity_change = abs(current_velocity - old_velocity)
	
	# Check all contact points for significant impulses
	var max_impulse_magnitude = 0.0
	var total_impulse = Vector3.ZERO
	
	for i in state.get_contact_count():
		var impulse = state.get_contact_impulse(i)
		var impulse_magnitude = impulse.length()
		
		if impulse_magnitude > max_impulse_magnitude:
			max_impulse_magnitude = impulse_magnitude
		
		total_impulse += impulse
	
	# Play sound if impulse is significant AND there's a sudden velocity change
	if (max_impulse_magnitude > impact_impulse_threshold
		and velocity_change > velocity_change_threshold):
		var impact_intensity = min(max_impulse_magnitude, max_impact_intensity)
		play_impact_sound(impact_intensity)
		emit_signal("impact_detected", impact_intensity)
		print("Impact detected - Max impulse: ", max_impulse_magnitude, " Velocity change: ", velocity_change, " Total impulse: ", total_impulse.length())
	
	old_velocity = current_velocity
	old_contact_count = state.get_contact_count()


## Play impact sound with volume and pitch scaling
func play_impact_sound(impact_intensity: float) -> void:
	#prints("AUDIO DEBUG - play_impact_sound called with intensity:", impact_intensity)
	
	# Check if parent has item_drop_sound and use it dynamically
	var current_drop_sound = drop_sound
	if not current_drop_sound and parent_body.has_method("get") and parent_body.get("item_drop_sound"):
		current_drop_sound = parent_body.get("item_drop_sound")
		#prints("AUDIO DEBUG - Using parent's item_drop_sound:", current_drop_sound)
	
	#prints("AUDIO DEBUG - drop_sound:", current_drop_sound)
	#prints("AUDIO DEBUG - is_soundplayer_ready:", is_soundplayer_ready)
	
	if not current_drop_sound:
		#prints("AUDIO DEBUG - No drop_sound available!")
		return
		
	if not is_soundplayer_ready:
		prints("AUDIO DEBUG - Sound player not ready!")
		return
	
	# Create a simple AudioStreamPlayer3D directly
	var drop_audio_player = AudioStreamPlayer3D.new()
	drop_audio_player.stream = current_drop_sound
	drop_audio_player.bus = bus_name
	
	# Scale volume based on impact intensity
	var volume_scale = (impact_intensity / max_impact_intensity)  # Normalize to 0-1
	drop_audio_player.volume_db = lerp(volume_min_db, volume_max_db, volume_scale)
	
	# Scale pitch based on impact intensity (higher impact = higher pitch)
	var pitch_scale = lerp(pitch_min_scale, pitch_max_scale, volume_scale)
	drop_audio_player.pitch_scale = pitch_scale
	
	#prints("AUDIO DEBUG - Object position:", parent_body.global_position)
	#prints("AUDIO DEBUG - Impact intensity:", impact_intensity)
	#prints("AUDIO DEBUG - Final volume_db:", drop_audio_player.volume_db)
	#prints("AUDIO DEBUG - Final pitch_scale:", drop_audio_player.pitch_scale)
	#prints("AUDIO DEBUG - Audio stream valid:", drop_audio_player.stream != null)
	
	# Calculate noise level for AI detection
	var noise_level = clamp((max_noise_level * impact_intensity), 1.0, 5.0)
	if parent_body.has_method("set_noise_level"):
		parent_body.set_noise_level(noise_level)
	
	parent_body.add_child(drop_audio_player)
	
	# Connect the finished signal to clean up
	drop_audio_player.finished.connect(_on_drop_sound_finished.bind(drop_audio_player))
	
	prints("AUDIO DEBUG - About to play sound...")
	drop_audio_player.play()
	prints("AUDIO DEBUG - Sound play() called, is_playing:", drop_audio_player.is_playing())
	
	is_soundplayer_ready = false
	start_delay()


func start_delay():
	var timer = get_tree().create_timer(cooldown_time)
	timer.timeout.connect(_on_delay_finished)


func _on_delay_finished():
	prints("DELAY DEBUG - Resetting is_soundplayer_ready to true")
	is_soundplayer_ready = true


func _on_drop_sound_finished(audio_player):
	prints("DROP SOUND DEBUG - Sound finished playing")
	if audio_player and is_instance_valid(audio_player):
		audio_player.queue_free()
