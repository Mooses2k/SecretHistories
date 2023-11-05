extends RigidBody

# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that


#onready var firelight = $FireOrigin/Fire/Light
#onready var burn_time = $Durability
#
#var has_ever_been_on = false 
#var is_lit = false
#
#
#func _process(delta):
#	if is_lit == true:
#		burn_time.pause_mode = false
#	else:
#		burn_time.pause_mode = true
#	if has_ever_been_on == false:
#			burn_time.start()
#			has_ever_been_on = true
#			firelight.visible = not firelight.visible
#			$AnimationPlayer.play("flicker")
#			$FireOrigin/Fire.emitting = true
#			$FireOrigin/EmberDrip.emitting = true
#			$FireOrigin/Smoke.emitting = true
#			is_lit = true
#	else:
#		is_lit = false
#
#
#func _use_primary():
#	if !burn_time.is_stopped():
#		firelight.visible = not firelight.visible
#		$AnimationPlayer.play("flicker")
#		$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
#		$FireOrigin/EmberDrip.emitting = not $FireOrigin/EmberDrip.emitting
#		$FireOrigin/Smoke.emitting = not $FireOrigin/Smoke
#	else:
#		firelight.visible = false
#		$AnimationPlayer.stop()
#		$FireOrigin/Fire.emitting = false
#		$FireOrigin/EmberDrip.emitting = false
#		$FireOrigin/Smoke.emitting = false
#
#
#func _on_Durability_timeout():
#	firelight.visible = false
#	$AnimationPlayer.stop()
#	$FireOrigin/Fire.emitting = false
#	$FireOrigin/EmberDrip.emitting = false
#	$FireOrigin/Smoke.emitting = false

onready var item_drop_sound : AudioStream = load("res://resources/sounds/impacts/metal_and_gun/414848__link-boy__metal-bang.wav")
onready var audio_player = get_node("DropSound")
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 5
var item_drop_sound_level = 20
var item_drop_pitch_level = 10
var is_soundplayer_ready = false


func _enter_tree():
	if not audio_player:
		var drop_sound = AudioStreamPlayer3D.new()
		drop_sound.name = "DropSound"
		drop_sound.bus = "Effects"
		add_child(drop_sound)
	
	is_soundplayer_ready = true


func _ready():
	connect("body_entered", self, "play_drop_sound")


func play_drop_sound(body):
	print("candelabra dropped")
#	if self.item_drop_sound and self.audio_player and self.linear_velocity.length() > 0.2 and self.is_soundplayer_ready:
	if self.item_drop_sound and self.audio_player and self.is_soundplayer_ready:
		self.audio_player.stream = self.item_drop_sound
		print("velo = " + str(self.linear_velocity.length()))
		self.item_drop_sound_level = self.linear_velocity.length() * 2.0
		self.item_drop_pitch_level = self.linear_velocity.length() * 0.4
			
		self.audio_player.unit_db = clamp(self.item_drop_sound_level, 5.0, 20.0)   # This should eventually be based on speed
		self.audio_player.pitch_scale = clamp(self.item_drop_pitch_level, 0.85, 1.0)
		self.audio_player.bus = "Effects"
		self.audio_player.play()
		self.noise_level = clamp((self.item_max_noise_level * self.linear_velocity.length()), 1.0, 5.0)   # This should eventually be based on speed\
		print("noise_level == " + str(self.noise_level))
		self.is_soundplayer_ready = false
		start_delay()


func start_delay():
	yield(get_tree().create_timer(0.2), "timeout")
	self.is_soundplayer_ready = true
