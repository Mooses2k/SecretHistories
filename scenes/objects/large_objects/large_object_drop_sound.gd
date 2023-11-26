class_name LargeObjectDropSound
extends RigidBody


var drop_sound_scene = preload("res://scenes/objects/large_objects/sarcophagi/drop_sound.tscn")
var item_drop_sound : AudioStream 
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 0
var item_drop_sound_level = 0
var item_drop_pitch_level = 0
var is_soundplayer_ready = false
var oldCount = 0


func _enter_tree():
	is_soundplayer_ready = true


func _integrate_forces(state):
	if !is_instance_valid(LoadScene.loadscreen):   # If it's at least a few seconds after level load
		if state.get_contact_count() > 0:
			if state.get_contact_count() > oldCount and state.linear_velocity.length() > 0.4:
				play_drop_sound(state.linear_velocity.length(), false)
		
	oldCount = state.get_contact_count()


func play_drop_sound(linear_velo, is_heavy):
	if self.item_drop_sound and self.is_soundplayer_ready:
		var drop_audio_player = drop_sound_scene.instance()
		drop_audio_player.stream = self.item_drop_sound
		drop_audio_player.bus = "Effects"
	
		if is_heavy:
			self.item_drop_sound_level = self.linear_velocity.length() * 10
			drop_audio_player.unit_db = clamp(self.item_drop_sound_level, 5.0, 50.0)
		else:
			self.item_drop_sound_level = linear_velo * 2.0
			self.item_drop_pitch_level = linear_velo * 0.4
			drop_audio_player.unit_db = clamp(self.item_drop_sound_level, 1.0, 20.0)
		
		self.noise_level = clamp((self.item_max_noise_level * linear_velo), 1.0, 5.0)
		self.add_child(drop_audio_player)
		self.is_soundplayer_ready = false
		self.start_delay()


func start_delay():
	yield(get_tree().create_timer(0.2), "timeout")
	self.is_soundplayer_ready = true
