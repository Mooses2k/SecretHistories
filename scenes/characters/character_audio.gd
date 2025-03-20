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
@export var character_voice_path : String = ""   # "res:// path to folder structure of this voice pack"

enum SpeechType {
	IDLE,
	ALERT,
	DETECTION,
	AMBUSH,
	CHASE,
	FIGHT,
	RELOAD,
	FLEE,
	DIALOG_Q,
	DIALOG_A,
	DIALOG_SEQUENCE,
	SURPRISED,
	FIRE,
	SNAKE,
	BOMB,
	COMET
}

var _idle_sounds : Array = []
var _alert_sounds : Array = []
var _detection_sounds : Array = []
var _ambush_sounds : Array = []
var _chase_sounds : Array = []
var _fight_sounds : Array = []
var _reload_sounds : Array = []
var _out_of_ammo_sounds : Array = []
var _flee_sounds : Array = []
var _dialog_q_sounds : Array = []
var _dialog_a_sounds : Array = []
var _dialog_sequence_sounds : Array = []
var _surprised_sounds : Array = []
var _fire_sounds : Array = []
var _snake_sounds : Array = []
var _bomb_sounds : Array = []
var _comet_sounds : Array = []

var _current_sound_dir : String = ""

@onready var speech_audio = $Speech as AudioStreamPlayer3D
@onready var manipulation_audio = $Manipulation as AudioStreamPlayer3D
@onready var movement_audio = $Movement as AudioStreamPlayer3D

var last_speech_type   # Tracked to avoid interrupting self to say same type of thing
@onready var last_speech_line   # Tracked to avoid repeating the same line


func _ready():
	# Movement audio	
	load_sounds("resources/sounds/breathing/breathe", 1)
	load_sounds("resources/sounds/jumping_landing/landing", 2)

	choose_voice()   # Choose one from the appropriate voices for this character
	pitch_alter_voice()   # Randomly alter pitch of this character's voice up or down some


func load_sounds(sound_dir, type : int) -> void:
	if sound_dir == "":
		return

	if _current_sound_dir == sound_dir:
		return

	_current_sound_dir = sound_dir

	if sound_dir.ends_with("/"):
		sound_dir.erase(sound_dir.length() - 1, 1)

	if !sound_dir.begins_with("res://"):
		sound_dir = "res://" + sound_dir
	
	
	var snd_dir = DirAccess.open(sound_dir)
	
	if not is_instance_valid(snd_dir):
		push_error("Unable to open sound directory :", sound_dir)
		return
	
	snd_dir.include_hidden = false
	snd_dir.include_navigational = false
	snd_dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547

	var sound = snd_dir.get_next()
	while sound != "":
		if not sound.ends_with(".import") and (sound.ends_with(".wav") or sound.ends_with(".ogg") or sound.ends_with(".mp3")):
			match type:
				# Movement
#				0:
					# old footstep
				1:
					if "in" in sound:
						_clamber_sounds["in"].append(load(sound_dir + "/" + sound))
					elif "out" in sound:
						_clamber_sounds["out"].append(load(sound_dir + "/" + sound))
				2:
					_landing_sounds.append(load(sound_dir + "/" + sound))
				# Speech
				13:
					_idle_sounds.append(load(sound_dir + "/" + sound))
				14:
					_alert_sounds.append(load(sound_dir + "/" + sound))
				15:
					_detection_sounds.append(load(sound_dir + "/" + sound))
				16:
					_ambush_sounds.append(load(sound_dir + "/" + sound))
				17:
					_chase_sounds.append(load(sound_dir + "/" + sound))
				18:
					_fight_sounds.append(load(sound_dir + "/" + sound))
				19:
					_reload_sounds.append(load(sound_dir + "/" + sound))
				20:
					_out_of_ammo_sounds.append(load(sound_dir + "/" + sound))
				21:
					_flee_sounds.append(load(sound_dir + "/" + sound))
				22:
					_dialog_q_sounds.append(load(sound_dir + "/" + sound))
				23:
					_dialog_a_sounds.append(load(sound_dir + "/" + sound))
				24:
					_dialog_sequence_sounds.append(load(sound_dir + "/" + sound))
				25:
					_surprised_sounds.append(load(sound_dir + "/" + sound))
				26:
					_fire_sounds.append(load(sound_dir + "/" + sound))
				27:
					_snake_sounds.append(load(sound_dir + "/" + sound))
				28:
					_bomb_sounds.append(load(sound_dir + "/" + sound))
				29:
					_comet_sounds.append(load(sound_dir + "/" + sound))
					
		sound = snd_dir.get_next()


### Speech

# Once per character, randomly choose an appropriate voice for this character
func choose_voice():
	if owner is Cultist:   # Later: Neophyte, later more types
	
		var choose = randi() % 2
		match choose:
			0:
				character_voice_path = "res://resources/sounds/voices/cultists/neophyte/dylanb_vo/"
			1:
				character_voice_path = "res://resources/sounds/voices/cultists/neophyte/deanbrignell/"
		
		# Speech audio - these should eventually be moved to each enemy's script or character audio
		# and the paths adjusted to the correct voice
		load_sounds(character_voice_path + "idle", 13)
		load_sounds(character_voice_path + "alert", 14)
		load_sounds(character_voice_path + "detection", 15)
		load_sounds(character_voice_path + "ambush", 16)
		load_sounds(character_voice_path + "chase", 17)
		load_sounds(character_voice_path + "fight", 18)
		load_sounds(character_voice_path + "reload", 19)
		load_sounds(character_voice_path + "out_of_ammo", 20)
		load_sounds(character_voice_path + "flee", 21)
		load_sounds(character_voice_path + "dialog_q", 22)
		load_sounds(character_voice_path + "dialog_a", 23)
		load_sounds(character_voice_path + "dialog_sequence", 24)
		load_sounds(character_voice_path + "surprised", 25)
		load_sounds(character_voice_path + "fire", 26)
		load_sounds(character_voice_path + "snake", 27)
		load_sounds(character_voice_path + "bomb", 28)
		load_sounds(character_voice_path + "comet", 29)


func pitch_alter_voice():
	speech_audio.set_pitch_scale(randf_range(0.8, 1.1))


func play_idle_sound():
	# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
	if speech_audio.is_playing() == true:
#		print("Sound already playing (idle called this)")
		return
	# Tracked to avoid repeating the same line
	_idle_sounds.shuffle()
	speech_audio.stream = _idle_sounds.front()
	# Don't replay the last line
	if last_speech_line == speech_audio.stream:
		return
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.IDLE
	speech_audio.play()
	print("Played idle sound")


func play_alert_sound():
	if last_speech_type == SpeechType.ALERT or last_speech_type == SpeechType.DETECTION or last_speech_type == SpeechType.FIGHT:
		# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
		if speech_audio.is_playing() == true:
#			print("Sounds already playing (alert called this)")
			return
	_alert_sounds.shuffle()
	speech_audio.stream = _alert_sounds.front()
	if last_speech_line == speech_audio.stream:   # This is not working to stop duplicate lines =/
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.ALERT
	speech_audio.play()
	print("Played alert sound")
	

func get_player() -> Player:
	var players := get_tree().get_nodes_in_group("Player")
	return players[0] if !players.is_empty() else null


func play_detection_sound() -> void:
	if last_speech_type == SpeechType.ALERT or last_speech_type == SpeechType.DETECTION or last_speech_type == SpeechType.FIGHT:
		# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
		if speech_audio.is_playing() == true:
#			print("Sounds already playing (detection called this)")
			return
	if is_instance_valid(get_player()) and get_player().inventory.bulky_equipment is ShardOfTheComet:
		_comet_sounds.shuffle()
		speech_audio.stream = _comet_sounds.front()
	else:
		_detection_sounds.shuffle()
		speech_audio.stream = _detection_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.DETECTION
	speech_audio.play()
	print("Played detection sound")


func play_ambush_sound():
	_ambush_sounds.shuffle()
	speech_audio.stream = _ambush_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.AMBUSH
	speech_audio.play()


func play_chase_sound():
	_chase_sounds.shuffle()
	speech_audio.stream = _chase_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.CHASE
	speech_audio.play()


func play_fight_sound():
	if last_speech_type == SpeechType.FIGHT:   # Anything but fight
		# This means he doesn't interrupt itself - for detection lines, they should, but not idles, reloads, etc
		if speech_audio.is_playing() == true:
			return
	_fight_sounds.shuffle()
	speech_audio.stream = _fight_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.FIGHT
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
	last_speech_type = SpeechType.RELOAD
	speech_audio.play()


func play_flee_sound():
	_flee_sounds.shuffle()
	speech_audio.stream = _flee_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.FLEE
	speech_audio.play()


# Needs logic for categories of question lines
func play_dialog_q_sound():
	_dialog_q_sounds.shuffle()
	speech_audio.stream = _dialog_q_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.DIALOG_Q
	speech_audio.play()


# Needs logic for categories of response lines
func play_dialog_a_sound():
	_dialog_a_sounds.shuffle()
	speech_audio.stream = _dialog_a_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.DIALOG_A
	speech_audio.play()


# Needs logic for each sequence
func play_dialog_sequence_sound():
	_dialog_sequence_sounds.shuffle()
	speech_audio.stream = _dialog_sequence_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.DIALOG_SEQUENCE
	speech_audio.play()


func play_surprised_sound():
	_surprised_sounds.shuffle()
	speech_audio.stream = _surprised_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.SURPRISED
	speech_audio.play()


func play_fire_sound():
	_fire_sounds.shuffle()
	speech_audio.stream = _fire_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.FIRE
	speech_audio.play()


func play_snake_sound():
	_snake_sounds.shuffle()
	speech_audio.stream = _snake_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.SNAKE
	speech_audio.play()


func play_bomb_sound():
	_bomb_sounds.shuffle()
	speech_audio.stream = _bomb_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.BOMB
	speech_audio.play()


func play_comet_sound():
	_comet_sounds.shuffle()
	speech_audio.stream = _comet_sounds.front()
	if last_speech_line == speech_audio.stream:
		return 
	last_speech_line = speech_audio.stream   # Tracked to avoid repeating the same line
	last_speech_type = SpeechType.COMET
	speech_audio.play()


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
