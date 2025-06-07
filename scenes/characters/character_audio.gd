class_name CharacterAudio
extends Node3D

# TODO: Save the Audio node with the child nodes as a scene, so as to avoid the possibility 
#       of human error when creating new characters
#       Move voice lines to a separate node and script. 
#		Currently possible issue: can't play movement audio at the same time as voice lines

var _landing_sounds : Array = []
var _clamber_sounds : Dictionary = {
	"in" : [],
	"out" : []
}

# Speech
@export var voice_actor : AudioLibrary.VOICE_ACTOR = AudioLibrary.VOICE_ACTOR.Dylanb_vo # fallback to dylan
@export var enemy_type: AudioLibrary.ENEMY_TYPE = AudioLibrary.ENEMY_TYPE.Neophyte

var _reload_sounds : Array = []
var _out_of_ammo_sounds : Array = []
var _dialog_q_sounds : Array = []
var _dialog_a_sounds : Array = []
var _dialog_sequence_sounds : Array = []

var _current_sound_dir : String = ""

@onready var speech_audio = $Speech as AudioStreamPlayer3D
@onready var manipulation_audio = $Manipulation as AudioStreamPlayer3D
@onready var movement_audio = $Movement as AudioStreamPlayer3D

var last_speech_type   # Tracked to avoid interrupting self to say same type of thing
@onready var last_speech_line   # Tracked to avoid repeating the same line


func _ready():
	# Movement audio	
	#load_sounds("resources/sounds/breathing/breathe", 1)
	#load_sounds("resources/sounds/jumping_landing/landing", 2)

	choose_voice()   # Choose one from the appropriate voices for this character
	pitch_alter_voice()   # Randomly alter pitch of this character's voice up or down some


### Speech

# Once per character, randomly choose an appropriate voice for this character
func choose_voice():
	if owner is Cultist:   # Later: Neophyte, later more types
		var choose = randi() % 2
		match choose:
			0:
				voice_actor = AudioLibrary.VOICE_ACTOR.Dylanb_vo
			1:
				voice_actor = AudioLibrary.VOICE_ACTOR.Deanbrignell
			pass
		

func pitch_alter_voice():
	speech_audio.set_pitch_scale(randf_range(0.8, 1.1))


func play_idle_sound():
	# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
	if speech_audio.is_playing() == true:
#		print("Sound already playing (idle called this)")
		return
	# Tracked to avoid repeating the same line
	var sound = AudioLibrary.get_voicelines(enemy_type, voice_actor, AudioLibrary.CULTIST_VOICE_TYPE.IDLE).pick_random()
	speech_audio.stream = sound
	# Don't replay the last line
	if last_speech_line == speech_audio.stream:
		return
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.IDLE
	speech_audio.play()
	print("Played idle sound")


func play_alert_sound():
	if last_speech_type == AudioLibrary.CULTIST_VOICE_TYPE.ALERT or last_speech_type == AudioLibrary.CULTIST_VOICE_TYPE.DETECTION or last_speech_type == AudioLibrary.CULTIST_VOICE_TYPE.FIGHT:
		# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
		if speech_audio.is_playing() == true:
#			print("Sounds already playing (alert called this)")
			return
	var sound: AudioStream = AudioLibrary.get_voicelines(enemy_type, voice_actor, AudioLibrary.CULTIST_VOICE_TYPE.ALERT).pick_random()
	speech_audio.stream = sound
	if last_speech_line == speech_audio.stream:   # This is not working to stop duplicate lines =/
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.ALERT
	speech_audio.play()
	print_debug("Played alert sound")
	

func get_player() -> Player:
	var players := get_tree().get_nodes_in_group("Player")
	return players[0] if !players.is_empty() else null


func play_detection_sound() -> void:
	if last_speech_type == AudioLibrary.CULTIST_VOICE_TYPE.ALERT or last_speech_type == AudioLibrary.CULTIST_VOICE_TYPE.DETECTION or last_speech_type == AudioLibrary.CULTIST_VOICE_TYPE.FIGHT:
		# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
		if speech_audio.is_playing() == true:
#			print("Sounds already playing (detection called this)")
			return
	if is_instance_valid(get_player()) and get_player().inventory.bulky_equipment is ShardOfTheComet:
		var sound = AudioLibrary.get_voicelines(enemy_type, voice_actor, AudioLibrary.CULTIST_VOICE_TYPE.COMET).pick_random()
		speech_audio.stream = sound
	else:
		var sound = AudioLibrary.get_voicelines(enemy_type, voice_actor, AudioLibrary.CULTIST_VOICE_TYPE.DETECTION).pick_random()
		speech_audio.stream = sound
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.DETECTION
	speech_audio.play()
	print("Played detection sound")


func play_ambush_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.AMBUSH)


func play_chase_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.CHASE)


func play_fight_sound():
	if last_speech_type == AudioLibrary.CULTIST_VOICE_TYPE.FIGHT:   # Anything but fight
		# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
		if speech_audio.is_playing() == true:
			return
	var sound = AudioLibrary.get_voicelines(enemy_type, voice_actor, AudioLibrary.CULTIST_VOICE_TYPE.FIGHT).pick_random()
	speech_audio.stream = sound
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.FIGHT
	speech_audio.play()
	print("Played fight sound")


func play_reload_sound():
	# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
	if speech_audio.is_playing() == true:
		return
	_reload_sounds.shuffle()
	speech_audio.stream = _reload_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.RELOAD
	speech_audio.play()


func play_flee_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.FLEE)


# Needs logic for categories of question lines
func play_dialog_q_sound():
	_dialog_q_sounds.shuffle()
	speech_audio.stream = _dialog_q_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.DIALOG_Q
	speech_audio.play()


# Needs logic for categories of response lines
func play_dialog_a_sound():
	_dialog_a_sounds.shuffle()
	speech_audio.stream = _dialog_a_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.DIALOG_A
	speech_audio.play()


# Needs logic for each sequence
func play_dialog_sequence_sound():
	_dialog_sequence_sounds.shuffle()
	speech_audio.stream = _dialog_sequence_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = AudioLibrary.CULTIST_VOICE_TYPE.DIALOG_SEQUENCE
	speech_audio.play()


func play_surprised_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.SURPRISED)


func play_fire_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.FIRE)


func play_snake_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.SNAKE)


func play_bomb_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.BOMB)


func play_comet_sound():
	_play_sound_from_library(AudioLibrary.CULTIST_VOICE_TYPE.COMET)


# Signalled from the idle loop Wait Random
func _on_BT_Wait_Random_character_idled():
	play_idle_sound()


func _on_BT_Sound_Listener_unseen_sound_heard():
	play_alert_sound()


func _on_BT_Player_Sensor_character_detected():
	play_detection_sound()


func _on_BT_Shoot_fighting():
	play_fight_sound()


func _on_BT_Reload_Gun_character_reloaded():
	play_reload_sound()


# Movement
# TODO: Set terrain type on the tile collision data/metadata so that you can decide which type
#       of terrain it's walking on when calling this method
func play_footstep_sound(rate : float = 0.0, pitch : float = 1.0, volume : float = 0.0, material:AudioLibrary.FOOTSTEP_TYPES = AudioLibrary.FOOTSTEP_TYPES.STONE):
	if(movement_audio.playing):
		return
	movement_audio.volume_db = rate
	movement_audio.pitch_scale = pitch
	## Why is there a volume AND a rate? 
	#movement_audio.volume_db = rate

	match material:
		AudioLibrary.FOOTSTEP_TYPES.STONE:
			if AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.STONE).size() > 0:
				AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.STONE).shuffle()
				movement_audio.stream = AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.STONE).front()
		AudioLibrary.FOOTSTEP_TYPES.CARPET:
			if AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.CARPET).size() > 0:
				AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.CARPET).shuffle()
				movement_audio.stream = AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.CARPET).front()
		AudioLibrary.FOOTSTEP_TYPES.GRAVEL:
			if AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.GRAVEL).size() > 0:
				AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.GRAVEL).shuffle()
				movement_audio.stream = AudioLibrary.get_footsteps(AudioLibrary.FOOTSTEP_TYPES.GRAVEL).front()
	movement_audio.play()


func play_land_sound():
	_landing_sounds.shuffle()
	movement_audio.stream = _landing_sounds.front()
	movement_audio.play()


func play_clamber_sound(clamber_in : bool) -> void:
	if clamber_in:
		if not movement_audio.stream in _clamber_sounds["in"]:
				_clamber_sounds["in"].shuffle()
				movement_audio.stream = _clamber_sounds["in"].front()
				movement_audio.play()
	else:
		if !movement_audio.playing:
				_clamber_sounds["out"].shuffle()
				movement_audio.stream = _clamber_sounds["out"].front()
				movement_audio.play()


func on_player_detected(_player, _position) -> void:
	play_detection_sound()

## Generic function used to play a sound from the AudioLibrary
func _play_sound_from_library(cultist_voice_type: AudioLibrary.CULTIST_VOICE_TYPE) -> void:
	var sound = AudioLibrary.get_voicelines(enemy_type, voice_actor, cultist_voice_type).pick_random()
	speech_audio.stream = sound
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = cultist_voice_type
	speech_audio.play()
