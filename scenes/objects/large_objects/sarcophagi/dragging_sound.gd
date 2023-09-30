extends RigidBody


var sound_vol : float = 10
var noise_level : float = 0
var item_max_noise_level : int = 40
var drop_sound_level : float = 60
export var item_drag_sound : AudioStream
export var item_drop_sound : AudioStream
onready var drag_audio_player = get_node("DragSound")
onready var drop_audio_player = get_node("DropSound")


func _enter_tree():
	if not drag_audio_player:
		var drag_sound = AudioStreamPlayer3D.new()
		drag_sound.name = "DragSound"
		add_child(drag_sound)
		drag_sound.stream = item_drag_sound
		drag_sound.unit_db = sound_vol
		drag_sound.bus = "Effects"
	
	if not drop_audio_player:
		var drop_sound = AudioStreamPlayer3D.new()
		drop_sound.name = "DropSound"
		add_child(drop_sound)
		drop_sound.stream = item_drop_sound
		drop_sound.unit_db = sound_vol
		drop_sound.bus = "Effects"


func _ready():
	connect("body_entered", self, "play_drop_sound")


func _integrate_forces(state):
	if self.drag_audio_player.stream != self.item_drag_sound:
		self.drag_audio_player.stream = self.item_drag_sound
		
	if self.drag_audio_player:
		if state.angular_velocity.abs().length() > 0.046:
			sound_vol = state.angular_velocity.abs().length()
			if sound_vol < 0.1:
				sound_vol = -(0.1 / sound_vol)
			else:
				sound_vol *= 10
			
			self.drag_audio_player.unit_db = clamp(sound_vol, 40.0, 60.0)
			noise_level = 3 * self.drag_audio_player.unit_db     # noise is detection by enemies
			
			if not self.drag_audio_player.is_playing():
				self.drag_audio_player.play()
		else:
			self.drag_audio_player.stop()


func play_drop_sound(body):
#	if body is KinematicBody or body is StaticBody:
#		return
	print("hit " + str(body))
	print("velocity length  " + str(self.linear_velocity))
	
	if self.linear_velocity.length() > 0.1 and self.item_drop_sound and self.drop_audio_player:
		if self.drop_audio_player.is_playing():
			self.drop_audio_player.stop()
		self.drop_audio_player.stream = self.item_drop_sound
		drop_sound_level = self.linear_velocity.length() * 150
		self.drop_audio_player.unit_db = clamp(drop_sound_level, 30.0, 100.0)
		self.drop_audio_player.play()
		print("ayun nahulog")
		self.noise_level = item_max_noise_level
