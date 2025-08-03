class_name LargeObject
extends RigidBody3D


var drop_sound_scene = preload("res://scenes/effects/drop_sound.tscn")
var item_drop_sound : AudioStream
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 0
var item_drop_sound_level = 0
var item_drop_pitch_level = 0
var is_soundplayer_ready = false
var old_contact_count = 0
var impact_impulse_threshold : float = mass/8.0  ## Minimum impulse magnitude to trigger sound
var old_velocity : float = 0.0  ## Track previous velocity for change detection
var velocity_change_threshold : float = 0.17  ## Minimum velocity change to trigger sound
var cooldown_time : float = 0.05  ## Time between allowed collision sounds


func _enter_tree():
	is_soundplayer_ready = true


func _integrate_forces(state):
	if !LoadScene.loading:   # If it's at least a few seconds after level load
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
			and velocity_change > velocity_change_threshold
			and is_soundplayer_ready):
			var impact_intensity = min(max_impulse_magnitude, 10.0)  # Cap for volume calculation
			play_drop_sound(impact_intensity, false)
			print("Impulse impact detected - Max impulse: ", max_impulse_magnitude, " Velocity change: ", velocity_change, " Total impulse: ", total_impulse.length())
		
		old_velocity = current_velocity
	
	old_contact_count = state.get_contact_count()


func play_drop_sound(linear_velo, is_heavy = false):
	prints("Is_soundplayer_ready:", is_soundplayer_ready)
	if self.item_drop_sound and self.is_soundplayer_ready:
		# Create a simple AudioStreamPlayer3D directly instead of using the scene
		var drop_audio_player = AudioStreamPlayer3D.new()
		drop_audio_player.stream = self.item_drop_sound
		drop_audio_player.bus = "Effects" 

		prints("AUDIO DEBUG - Object position:", self.global_position)
		prints("AUDIO DEBUG - Final volume_db:", drop_audio_player.volume_db)
		
		self.noise_level = clamp((self.item_max_noise_level * linear_velo), 1.0, 5.0)
		self.add_child(drop_audio_player)
		
		# Connect the finished signal to clean up
		drop_audio_player.finished.connect(_on_drop_sound_finished.bind(drop_audio_player))
		
		drop_audio_player.play()
		
		self.is_soundplayer_ready = false
		self.start_delay()


func start_delay():
	var timer = get_tree().create_timer(cooldown_time)
	timer.timeout.connect(_on_delay_finished)


func _on_delay_finished():
	prints("DELAY DEBUG - Resetting is_soundplayer_ready to true")
	self.is_soundplayer_ready = true


func _on_drop_sound_finished(audio_player):
	prints("DROP SOUND DEBUG - Sound finished playing")
	if audio_player and is_instance_valid(audio_player):
		audio_player.queue_free()
