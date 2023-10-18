extends RigidBody


var drop_sound_scene = preload("res://scenes/objects/large_objects/sarcophagi/drop_sound.tscn")
var sound_vol : float = 10
var noise_level : float = 0
var item_max_noise_level : int = 40
var drop_sound_level : float = 60
var is_soundplayer_ready = true 
var drag_audio_player = null
#var drop_audio_player = null
export var item_drag_sound : AudioStream
export var item_drop_sound : AudioStream


func _enter_tree():
	if self.drag_audio_player == null:
		var drag_sound = AudioStreamPlayer3D.new()
		drag_sound.name = "DragSound"
		drag_sound.stream = item_drag_sound
		drag_sound.unit_db = sound_vol
		drag_sound.bus = "Effects"
		self.add_child(drag_sound)
	
#	if self.drop_audio_player == null:
#		var drop_sound = AudioStreamPlayer3D.new()
#		drop_sound.name = "DropSound"
#		drop_sound.stream = item_drop_sound
#		drop_sound.unit_db = sound_vol
#		drop_sound.bus = "Effects"
#		self.add_child(drop_sound)
	
#	self.drop_audio_player = self.get_node("DropSound")
	self.drag_audio_player = self.get_node("DragSound")
	
	self.drag_audio_player.stream = self.item_drag_sound
#	self.drop_audio_player.stream = self.item_drop_sound


func _ready():
	connect("body_entered", self, "play_drop_sound")
	self.is_soundplayer_ready = true


func _integrate_forces(state):
	if self.drag_audio_player:
		if state.linear_velocity.length() > (7 / self.mass):
			sound_vol = state.linear_velocity.length()
			if sound_vol < 0.1:
				sound_vol = -(0.1 / sound_vol)
			else:
				sound_vol *= 10
			
			self.drag_audio_player.unit_db = clamp(sound_vol, 40.0, 60.0)
			self.noise_level = 3 * self.drag_audio_player.unit_db     # noise is detection by enemies
			
			if not self.drag_audio_player.is_playing():
				self.drag_audio_player.play()
		else:
			self.drag_audio_player.stop()


func play_drop_sound(body):
	print("hulog")
	if self.item_drop_sound and self.is_soundplayer_ready:
		var drop_audio_player = drop_sound_scene.instance()
		drop_audio_player.stream = item_drop_sound
		drop_audio_player.bus = "Effects"
		self.drop_sound_level = self.linear_velocity.length() * 150
		drop_audio_player.unit_db = clamp(self.drop_sound_level, 30.0, 100.0)
		self.noise_level = item_max_noise_level
		self.add_child(drop_audio_player)
		self.is_soundplayer_ready = false
		start_delay()


func start_delay():
	yield(get_tree().create_timer(0.2), "timeout")
	self.is_soundplayer_ready = true
