extends "res://scenes/objects/large_objects/large_object_drop_sound.gd"


var spawnable_items : PackedStringArray
var sound_vol : float = 10
var drag_noise_level : float = 0
var drag_audio_player = null
@export var item_drag_sound : AudioStream
@export var sarco_lid_drop_sound : AudioStream


func _enter_tree():
	if self.drag_audio_player == null:
		var drag_sound = AudioStreamPlayer3D.new()
		drag_sound.name = "DragSound"
		drag_sound.stream = item_drag_sound
		drag_sound.volume_db = sound_vol
		drag_sound.bus = "Effects"
		self.add_child(drag_sound)
	
	self.drag_audio_player = self.get_node("DragSound")
	self.drag_audio_player.stream = self.item_drag_sound


func _ready():
	self.item_max_noise_level = 40
	self.item_drop_sound = sarco_lid_drop_sound


func _integrate_forces(state):
	if state.get_contact_count() > 0:
		if state.get_contact_count() > self.oldCount and state.linear_velocity.length() > 0.7:
			super.play_drop_sound(state.linear_velocity.length(), true)
		
	self.oldCount = state.get_contact_count()
	
	if self.drag_audio_player:
		if state.linear_velocity.length() > (7 / self.mass):
			sound_vol = state.linear_velocity.length()
			if sound_vol < 0.1:
				sound_vol = -(0.1 / sound_vol)
			else:
				sound_vol *= 10
			
			self.drag_audio_player.volume_db = clamp(sound_vol, 40.0, 60.0)
			self.drag_noise_level = 3 * self.drag_audio_player.volume_db     # noise is detection by enemies
			
			if not self.drag_audio_player.is_playing():
				self.drag_audio_player.play()
		else:
			self.drag_audio_player.stop()
