class_name CharacterAudio
extends Spatial


var _footstep_sounds : Array = []
var _stone_footstep_sounds : Array = []
var _wood_footstep_sounds : Array = []
var _carpet_footstep_sounds : Array = []
var _water_footstep_sounds : Array = []
var _gravel_footstep_sounds : Array = []
var _metal_footstep_sounds : Array = []
var _tile_footstep_sounds : Array = []

var _landing_sounds : Array = []
var _clamber_sounds : Dictionary = {
	"in" : [],
	"out" : []
}

# Speech
export var character_voice_path : String = "res://resources/sounds/voices/cultists/neophyte/dylanb_vo/"   # "res:// path to folder structure of this voice pack?"

var _idle_sounds : Array = []
var _alert_sounds : Array = []
var _detection_sounds : Array = []
var _ambush_sounds : Array = []
var _chase_sounds : Array = []
var _fight_sounds : Array = []
var _reload_sounds : Array = []
var _flee_sounds : Array = []
var _dialog_q_sounds : Array = []
var _dialog_a_sounds : Array = []
var _dialog_sequence_sounds : Array = []
var _surprised_sounds : Array = []
var _fire_sounds : Array = []
var _snake_sounds : Array = []
var _bomb_sounds : Array = []

var _current_sound_dir : String = ""

onready var speech_audio = $Speech
onready var manipulation_audio = $Manipulation
onready var movement_audio = $Movement

onready var last_speech_line = speech_audio.stream # tracked to avoid repeating the same line


func _ready():
	choose_voice()


func load_sounds(sound_dir, type : int) -> void:
	if sound_dir == "":
		return

	if _current_sound_dir == sound_dir:
		return

	_current_sound_dir = sound_dir

	if sound_dir.ends_with("/"):
		sound_dir.erase(sound_dir.length() - 1, 1)

	if not "res://" in sound_dir:
		sound_dir = "res://" + sound_dir

	var snd_dir = Directory.new()
	snd_dir.open(sound_dir)
	snd_dir.list_dir_begin(true)

	var sound = snd_dir.get_next()
	while sound != "":
		if not sound.ends_with(".import") and sound.ends_with(".wav"):
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
				3:
					_stone_footstep_sounds.append(load(sound_dir + "/" + sound))
				4:
					_wood_footstep_sounds.append(load(sound_dir + "/" + sound))
				5:
					_water_footstep_sounds.append(load(sound_dir + "/" + sound))
				6:
					_gravel_footstep_sounds.append(load(sound_dir + "/" + sound))
				7:
					_carpet_footstep_sounds.append(load(sound_dir + "/" + sound))
				8:
					_metal_footstep_sounds.append(load(sound_dir + "/" + sound))
				9:
					_tile_footstep_sounds.append(load(sound_dir + "/" + sound))
					
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
					_flee_sounds.append(load(sound_dir + "/" + sound))
				21:
					_dialog_q_sounds.append(load(sound_dir + "/" + sound))
				22:
					_dialog_a_sounds.append(load(sound_dir + "/" + sound))
				23:
					_dialog_sequence_sounds.append(load(sound_dir + "/" + sound))
				24:
					_surprised_sounds.append(load(sound_dir + "/" + sound))
				25:
					_fire_sounds.append(load(sound_dir + "/" + sound))
				26:
					_snake_sounds.append(load(sound_dir + "/" + sound))
				27:
					_bomb_sounds.append(load(sound_dir + "/" + sound))
					
		sound = snd_dir.get_next()


#Speech

# Once per character, randomly choose one of the appropriate voices for this character
func choose_voice():
	pass


func play_idle_sound():
	_idle_sounds.shuffle()
	speech_audio.stream = _idle_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()
	print("played idle sound")


func play_alert_sound():
	_alert_sounds.shuffle()
	speech_audio.stream = _alert_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_detection_sound():
	_detection_sounds.shuffle()
	speech_audio.stream = _detection_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_ambush_sound():
	_ambush_sounds.shuffle()
	speech_audio.stream = _ambush_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_chase_sound():
	_chase_sounds.shuffle()
	speech_audio.stream = _chase_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_fight_sound():
	_fight_sounds.shuffle()
	speech_audio.stream = _fight_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_reload_sound():
	_reload_sounds.shuffle()
	speech_audio.stream = _reload_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_flee_sound():
	_flee_sounds.shuffle()
	speech_audio.stream = _flee_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


# needs logic for categories of question lines
func play_dialog_q_sound():
	_dialog_q_sounds.shuffle()
	speech_audio.stream = _dialog_q_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


# needs logic for categories of response lines
func play_dialog_a_sound():
	_dialog_a_sounds.shuffle()
	speech_audio.stream = _dialog_a_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


# needs logic for each sequence
func play_dialog_sequence_sound():
	_dialog_sequence_sounds.shuffle()
	speech_audio.stream = _dialog_sequence_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_surprised_sound():
	_surprised_sounds.shuffle()
	speech_audio.stream = _surprised_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_fire_sound():
	_fire_sounds.shuffle()
	speech_audio.stream = _fire_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_snake_sound():
	_snake_sounds.shuffle()
	speech_audio.stream = _snake_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


func play_bomb_sound():
	_bomb_sounds.shuffle()
	speech_audio.stream = _bomb_sounds.front()
	if last_speech_line == speech_audio.stream:
		return # instead of playing
	last_speech_line = speech_audio.stream # tracked to avoid repeating the same line
	speech_audio.play()


# Signalled from the idle loop Wait Random
func _on_BT_Wait_Random_cultist_idled():
	play_idle_sound()


# Movement

func play_footstep_sound(rate : float = 0.0, pitch : float = 1.0, volume : float = 0.0):
	movement_audio.unit_db = rate
	movement_audio.pitch_scale = pitch
	movement_audio.unit_db = volume
	if _footstep_sounds.size() > 0:
		_footstep_sounds.shuffle()
		movement_audio.stream = _footstep_sounds.front()
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
