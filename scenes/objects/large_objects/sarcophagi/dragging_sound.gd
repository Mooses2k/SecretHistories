extends RigidBody

var pos : Vector3
var pitch_val : float = 1
var multiplier : float = 1200
onready var audio_player = get_node("DragDropSound")
export var item_drag_sound : AudioStream
export var item_drop_sound : AudioStream
var noise_level = 0
var item_max_noise_level = 5
var item_sound_level = 10


func _enter_tree():
	if not audio_player:
		var drag_sound = AudioStreamPlayer3D.new()
		drag_sound.name = "DragDropSound"
		add_child(drag_sound)
		drag_sound.stream = item_drag_sound


func _ready():
	connect("body_entered", self, "play_drop_sound")
	pos = self.global_transform.origin 


func dragging():
	if self.audio_player.stream != self.item_drag_sound:
		self.audio_player.stream = self.item_drag_sound
	var diff1 = abs(pos.x - self.global_transform.origin.x)
	var diff2 = abs(pos.z - self.global_transform.origin.z)
	
	if diff1 > 0.00005 or diff2 > 0.00005:
		if diff1 * multiplier > diff2 * multiplier:
			pitch_val = clamp(diff1 * multiplier, 0.3, 1.2)
		else:
			pitch_val = clamp(diff2 * multiplier, 0.3, 1.2)
		
		if not self.audio_player.is_playing():
			self.audio_player.pitch_scale = pitch_val
			self.audio_player.play()
	else:
		self.audio_player.stop()
	
	pos = self.global_transform.origin



func play_drop_sound(body):
	if self.item_drop_sound and self.audio_player:
		if self.audio_player.is_playing():
			self.audio_player.stop()
		self.audio_player.stream = self.item_drop_sound
		self.audio_player.unit_db = item_sound_level
		self.audio_player.play()
		self.noise_level = item_max_noise_level
