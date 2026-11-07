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

# Breathing loop (3.x Stamina node port: same heavy_breath asset, loudness
# tracks low stamina). Player-only: in 3.x only the player scene carried the
# Stamina node.
const BREATHING_STREAM : AudioStream = preload("res://resources/sounds/breathing/heavy_breath.mp3")
const BREATHING_FULL_DB : float = -16.0   # 3.x tired() volume at full stamina
const BREATHING_EMPTY_DB : float = 14.0   # 3.x tired() volume at zero stamina
# Issue #179: shared room reverb system (one "Reverb" bus, re-parameterized
# from the room the player stands in). Preloaded, not via the global class
# name, because headless runs do not refresh the global class cache.
const RoomReverbAreaScript : GDScript = preload("res://scenes/effects/room_reverb_area.gd")
var _breathing_audio : AudioStreamPlayer
var _land_clamber_audio : AudioStreamPlayer3D

@onready var speech_audio = $Speech as AudioStreamPlayer3D
@onready var manipulation_audio = $Manipulation as AudioStreamPlayer3D
@onready var movement_audio = $Movement as AudioStreamPlayer3D

var last_speech_type   # Tracked to avoid interrupting self to say same type of thing
@onready var last_speech_line   # Tracked to avoid repeating the same line


func _ready():
	# Movement audio
	load_sounds("resources/sounds/jumping_landing/landing", 2)

	_route_speech_to_reverb()
	_setup_land_clamber_send()
	choose_voice()   # Choose one from the appropriate voices for this character
	pitch_alter_voice()   # Randomly alter pitch of this character's voice up or down some

	if owner is Player:
		_setup_breathing()


## Loads every wav/ogg/mp3 under sound_dir into the array selected by type.
## 3.x port (origin/main character_audio.gd): 1 clamber in/out, 2 landing,
## 3-9 footstep materials. Footsteps live in AudioLibrary now; this loader
## serves the arrays play_land_sound/play_clamber_sound read.
func load_sounds(sound_dir : String, type : int) -> void:
	if sound_dir == "" or _current_sound_dir == sound_dir:
		return
	_current_sound_dir = sound_dir
	if sound_dir.ends_with("/"):
		sound_dir = sound_dir.left(sound_dir.length() - 1)
	if not sound_dir.begins_with("res://"):
		sound_dir = "res://" + sound_dir
	var dir := DirAccess.open(sound_dir)
	if dir == null:
		push_warning("CharacterAudio: sound dir not found: " + sound_dir)
		return
	dir.list_dir_begin()
	var sound := dir.get_next()
	while sound != "":
		if not sound.ends_with(".import") and (sound.ends_with(".wav") or sound.ends_with(".ogg") or sound.ends_with(".mp3")):
			var stream := load(sound_dir + "/" + sound)
			match type:
				1:
					if "in" in sound:
						_clamber_sounds["in"].append(stream)
					elif "out" in sound:
						_clamber_sounds["out"].append(stream)
				2:
					_landing_sounds.append(stream)
		sound = dir.get_next()


## 3.x Stamina node behavior: breathing always runs while alive, volume
## interpolating from quiet at full stamina to loud at empty.
func _setup_breathing() -> void:
	# Issue #179: breathing rides the one shared "Reverb" bus so the room the
	# player stands in re-parameterizes the reverb tail (was: bus Effects).
	# Reverb sends onward to Effects, so the Effects Volume slider still
	# applies. The default-params reset also clears stale params carried over
	# from the previous floor at every player spawn.
	RoomReverbAreaScript.ensure_reverb_bus()
	RoomReverbAreaScript.apply_reverb_params(RoomReverbAreaScript.default_params())
	_breathing_audio = AudioStreamPlayer.new()
	_breathing_audio.stream = BREATHING_STREAM
	_breathing_audio.bus = RoomReverbAreaScript.BUS_NAME
	add_child(_breathing_audio)


func play_breathing(stamina_ratio : float) -> void:
	if _breathing_audio == null:
		return
	_breathing_audio.volume_db = lerpf(BREATHING_EMPTY_DB, BREATHING_FULL_DB, clampf(stamina_ratio, 0.0, 1.0))
	if not _breathing_audio.playing:
		_breathing_audio.play()


## Issue #179: cultist speech rides the one shared "Reverb" bus, whose effect
## is re-parameterized by the room the listener stands in. The bus reverb's
## dry is 1.0, so the dry voice stays at full volume and only the room's wet
## tail is added. The bus sends onward to Effects, so speech now follows the
## existing Effects Volume slider. Ensure-only: this never resets the room
## params, so a cultist spawn cannot stomp the player's current room.
func _route_speech_to_reverb() -> void:
	RoomReverbAreaScript.ensure_reverb_bus()
	speech_audio.bus = RoomReverbAreaScript.BUS_NAME


## Issue #179: landing and clamber one-shots ride the one shared "Reverb" bus,
## whose effect is re-parameterized by the room the listener stands in. They
## used to play on the Movement player shared with the footstep path, and
## rerouting that player would have given footsteps reverb too, so the
## one-shots play on this dedicated player instead. The bus reverb's dry is
## 1.0, so the dry one-shot stays at its full 3.x volume and only the room's
## wet tail is added. The bus sends onward to Effects. Ensure-only: this
## never resets the room params.
func _setup_land_clamber_send() -> void:
	RoomReverbAreaScript.ensure_reverb_bus()
	_land_clamber_audio = AudioStreamPlayer3D.new()
	_land_clamber_audio.bus = RoomReverbAreaScript.BUS_NAME
	add_child(_land_clamber_audio)


## Plays the Movement player's current one-shot state (stream plus the 3.x
## inherited pitch and volume the footstep path left behind) on the Reverb
## bus send player instead of the shared Movement player, so the footstep
## path itself stays untouched and nothing plays twice.
func _play_land_clamber_send() -> void:
	if _land_clamber_audio == null:
		return
	_land_clamber_audio.stream = movement_audio.stream
	_land_clamber_audio.pitch_scale = movement_audio.pitch_scale
	_land_clamber_audio.volume_db = movement_audio.volume_db
	_land_clamber_audio.play()


### Speech

# Once per character, randomly choose an appropriate voice for this character
func choose_voice():
	if owner is HumanoidCharacter and not Player:   # Later: Neophyte, later more types
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
	var players := get_tree().get_nodes_in_group("PLAYER")
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
## Resolves the footstep material for a world position from the level's
## WorldData surface types, the same source the 3.x character used.
## Falls back to Stone when there is no level, no world data, the position
## is out of bounds, or the surface type has no footstep clips
## (Wood, Water, Metal, Tile).
func resolve_footstep_material(global_pos : Vector3) -> AudioLibrary.FOOTSTEP_TYPES:
	if GameManager.game == null or GameManager.game.level == null or GameManager.game.level.world_data == null:
		return AudioLibrary.FOOTSTEP_TYPES.STONE
	var world_data : WorldData = GameManager.game.level.world_data
	var level : GameWorld = GameManager.game.level
	# A level outside the tree has no world placement, so its origin is zero.
	var local_pos : Vector3 = global_pos
	if level.is_inside_tree():
		local_pos -= level.global_position
	var surface_type : int = world_data.get_cell_surfacetype(world_data.get_cell_index_from_local_position(local_pos))
	match surface_type:
		WorldData.SurfaceType.CARPET:
			return AudioLibrary.FOOTSTEP_TYPES.CARPET
		WorldData.SurfaceType.GRAVEL:
			return AudioLibrary.FOOTSTEP_TYPES.GRAVEL
		_:
			return AudioLibrary.FOOTSTEP_TYPES.STONE


func play_footstep_sound(rate : float = 0.0, pitch : float = 1.0, volume : float = 0.0, material:AudioLibrary.FOOTSTEP_TYPES = AudioLibrary.FOOTSTEP_TYPES.STONE):
	if(movement_audio.playing):
		return
	movement_audio.volume_db = rate
	movement_audio.pitch_scale = pitch
	# 3.x parity (origin/main): unit_db was assigned twice, first rate then
	# the volume param, so walk/sprint footsteps ended at 0 dB and crouch at
	# -20 dB. The 4.x port dropped the second assignment, which made
	# footsteps 5 dB louder than 3.x and let footstep leftovers deform the
	# landing sound into something that reads as a wrong footstep clip.
	movement_audio.volume_db = volume

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
	# 3.x parity (origin/main): the land clip inherits the pitch and volume
	# the footstep path left on the shared Movement player. 3.x footsteps
	# always ended at 0 dB (walk/sprint) or -20 dB (crouch, effectively
	# silent), so landing played land_1.wav at natural pitch after walking
	# and at 1.5 after a sprint, which reads as the sharp heel clap the
	# owner remembers. The land_1.wav asset is blob-identical to 3.x main;
	# the wrong landing audio came from the dropped footstep volume reset.
	_landing_sounds.shuffle()
	movement_audio.stream = _landing_sounds.front()
	_play_land_clamber_send()


func play_clamber_sound(clamber_in : bool) -> void:
	if clamber_in:
		if not movement_audio.stream in _clamber_sounds["in"]:
				_clamber_sounds["in"].shuffle()
				movement_audio.stream = _clamber_sounds["in"].front()
				_play_land_clamber_send()
	else:
		if !movement_audio.playing:
				_clamber_sounds["out"].shuffle()
				movement_audio.stream = _clamber_sounds["out"].front()
				_play_land_clamber_send()


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


func _on_reload_ammo_character_reloaded() -> void:
	pass # Replace with function body.
