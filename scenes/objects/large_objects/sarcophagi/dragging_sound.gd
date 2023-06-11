extends RigidBody


var sound_vol : float = 10
var noise_level : float = 0
var item_max_noise_level : int = 40
var item_sound_level : float = 60
export var item_drag_sound : AudioStream
export var item_drop_sound : AudioStream
onready var audio_player = get_node("DragDropSound")


func _enter_tree():
	if not audio_player:
		var drag_sound = AudioStreamPlayer3D.new()
		drag_sound.name = "DragDropSound"
		add_child(drag_sound)
		drag_sound.stream = item_drag_sound
		drag_sound.unit_db = sound_vol


func _ready():
	connect("body_entered", self, "play_drop_sound")


func _integrate_forces(state):
	if self.audio_player.stream != self.item_drag_sound:
		self.audio_player.stream = self.item_drag_sound
		
	if self.audio_player:
		if state.angular_velocity.abs().length() > 0.046:
			sound_vol = state.angular_velocity.abs().length()
			if sound_vol < 0.1:
				sound_vol = -(0.1 / sound_vol)
			else:
				sound_vol *= 10
			
			self.audio_player.unit_db = clamp(sound_vol, 40.0, 60.0)
			noise_level = 3 * self.audio_player.unit_db     # noise is detection by enemies
			
			if not self.audio_player.is_playing():
				self.audio_player.play()
		else:
			self.audio_player.stop()


func play_drop_sound(body):
	if self.item_drop_sound and self.audio_player:
		if self.audio_player.is_playing():
			self.audio_player.stop()
		self.audio_player.stream = self.item_drop_sound
		self.audio_player.unit_db = item_sound_level
		self.audio_player.play()
		self.noise_level = item_max_noise_level
