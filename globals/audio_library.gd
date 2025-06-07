extends Node
##Generic autoload, to be used as central location to grab any sound collections that are used by many objects. 
##Loading only once, it helps not access the disk every time an object using them is spawned

enum AUDIO_TYPE {
	FOOTSTEPS,
	CULTIST_VOICES,
	PLAYER_VOICES
}


##Add more types as required
enum FOOTSTEP_TYPES{
	STONE,
	GRAVEL,
	CARPET
}

enum ENEMY_TYPE {
	Neophyte
}

enum VOICE_ACTOR {
	Dylanb_vo,
	Deanbrignell
}
	
enum CULTIST_VOICE_TYPE {
	IDLE,
	ALERT,
	DETECTION,
	AMBUSH,
	CHASE,
	FIGHT,
	RELOAD,
	OUT_OF_AMMO,
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

##Add more, as they become available
var library:Dictionary = {
	##Structure: library[AUDIO_TYPE][Optional subtype] = [list of audio streams]
	AUDIO_TYPE.FOOTSTEPS: {
		FOOTSTEP_TYPES.STONE: [
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_1.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_2.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_3.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_4.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_5.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_6.wav") as AudioStream
		],
		FOOTSTEP_TYPES.GRAVEL: [
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel1.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel2.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel3.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel4.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel5.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel6.wav") as AudioStream
		],
		FOOTSTEP_TYPES.CARPET: [
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet1.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet2.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet3.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet4.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet5.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet6.wav") as AudioStream
		]
	},
}


func _ready() -> void:
	var voices: Dictionary = {} # Structure: ENEMY_TYPE -> VOICE_ACTOR -> VOICE_TYPE
	
	for enemy_type: int in ENEMY_TYPE.values():
		var enemy_type_name: String = ENEMY_TYPE.keys()[enemy_type] # we cant go the other way around (get int from name) cause its not possible to index an array by a string
		if not voices.has(enemy_type):
			voices[enemy_type] = {}
		
		for voice_actor: int in VOICE_ACTOR.values():
			var voice_actor_name: String = VOICE_ACTOR.keys()[voice_actor]
			if not voices[enemy_type].has(voice_actor):
				voices[enemy_type][voice_actor] = {}
			
			for voice_type: int in CULTIST_VOICE_TYPE.values():
				var voice_type_name: String = CULTIST_VOICE_TYPE.keys()[voice_type]
				var path = "res://resources/sounds/voices/cultists/"+enemy_type_name.to_lower()+"/" + voice_actor_name.to_lower() + "/" + voice_type_name.to_lower()
				voices[enemy_type][voice_actor][voice_type] = load_cultists_voicelines(path)
	
	library[AUDIO_TYPE.CULTIST_VOICES] = voices
	print("Loaded voicelines")
	print_debug(library[AUDIO_TYPE.CULTIST_VOICES])


func get_footsteps(material: FOOTSTEP_TYPES) -> Array:
	##Add more methods like this, as more audio types are added to this file
	##If there is no subtype, don't add it
	##Alternative if memory usage at start is in question, lazy loading version:
	##    get_<audio type>(<optional subtype>: <subtype enum>):
	##        if (library[<audio type>] == null):
	##            library[<audio type>] = <if using subtypes, {}, otherwise, []>
	##        if (library[<audio type>][<optional subtype> == null or library[<audio type>][<optional subtype>].is_empty()):
	##            library[<audio type>][<optional subtype>] = []
	##            library[<audio type>][<optional subtype>].append(load("res://resources/sounds/<audio type>/<optional subtype>/file1.extension"))
	##            library[<audio type>][<optional subtype>].append(load("res://resources/sounds/<audio type>/<optional subtype>/file2.extension"))
	##            etc
	##        return library[<audio type>][<optional subtype>]
	return library[AUDIO_TYPE.FOOTSTEPS][material]


func get_voicelines(enemy_type: ENEMY_TYPE, voice_actor: VOICE_ACTOR ,voice_tag: CULTIST_VOICE_TYPE) -> Array:
	if !library[AUDIO_TYPE.CULTIST_VOICES].has(enemy_type):
		return []
		
	if !library[AUDIO_TYPE.CULTIST_VOICES][enemy_type].has(voice_actor):
		return []
		
	if !library[AUDIO_TYPE.CULTIST_VOICES][enemy_type][voice_actor].has(voice_tag):
		push_error("voiceline " + str(voice_tag) + " does not exists to voice actor" + str(voice_actor))
		return []
	
	return library[AUDIO_TYPE.CULTIST_VOICES][enemy_type][voice_actor][voice_tag]

## Returns an aray with all voicelines in sound_dir
func load_cultists_voicelines(sound_dir: String) -> Array[AudioStream]:
	var loaded_audios: Array[AudioStream] = []

	if sound_dir == "":
		return []

	if sound_dir.ends_with("/"):
		sound_dir.erase(sound_dir.length() - 1, 1)

	if !sound_dir.begins_with("res://"):
		sound_dir = "res://" + sound_dir


	var snd_dir = DirAccess.open(sound_dir)

	if not is_instance_valid(snd_dir):
		push_error("Unable to open sound directory :", sound_dir)
		return []

	snd_dir.include_hidden = false
	snd_dir.include_navigational = false
	snd_dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547

	var sound = snd_dir.get_next()
	while sound != "":
		if not sound.ends_with(".import") and (sound.ends_with(".wav") or sound.ends_with(".ogg") or sound.ends_with(".mp3")):
			loaded_audios.append(load(sound_dir + "/" + sound))

		sound = snd_dir.get_next()

	return loaded_audios
