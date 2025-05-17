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
	
	# TODO - for now we have just one type of enemy so its okay to hardcode voices, but a PR to make it dynamic is welcome
	# See character_audio.gd - choose_voice()
	AUDIO_TYPE.CULTIST_VOICES: {
		VOICE_ACTOR.Dylanb_vo: {
			CULTIST_VOICE_TYPE.IDLE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/idle"),
			CULTIST_VOICE_TYPE.ALERT: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/alert"),
			CULTIST_VOICE_TYPE.DETECTION: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/detection"),
			CULTIST_VOICE_TYPE.AMBUSH: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/ambush"),
			CULTIST_VOICE_TYPE.CHASE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/chase"),
			CULTIST_VOICE_TYPE.FIGHT: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/fight"),
			CULTIST_VOICE_TYPE.RELOAD: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/reload"),
			CULTIST_VOICE_TYPE.OUT_OF_AMMO: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/out_of_ammo"),
			CULTIST_VOICE_TYPE.FLEE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/flee"),
			CULTIST_VOICE_TYPE.DIALOG_Q: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/dialog_q"),
			CULTIST_VOICE_TYPE.DIALOG_A: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/dialog_a"),
			CULTIST_VOICE_TYPE.DIALOG_SEQUENCE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/dialog_sequence"),
			CULTIST_VOICE_TYPE.SURPRISED: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/surprised"),
			CULTIST_VOICE_TYPE.FIRE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/fire"),
			CULTIST_VOICE_TYPE.SNAKE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/snake"),
			CULTIST_VOICE_TYPE.BOMB: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/bomb"),
			CULTIST_VOICE_TYPE.COMET: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/dylanb_vo/comet")
		 },
		 VOICE_ACTOR.Deanbrignell: {
			CULTIST_VOICE_TYPE.IDLE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle"),
			CULTIST_VOICE_TYPE.ALERT: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert"),
			CULTIST_VOICE_TYPE.DETECTION: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection"),
			CULTIST_VOICE_TYPE.AMBUSH: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush"),
			CULTIST_VOICE_TYPE.CHASE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/chase"),
			CULTIST_VOICE_TYPE.FIGHT: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight"),
			CULTIST_VOICE_TYPE.RELOAD: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/reload"),
			CULTIST_VOICE_TYPE.OUT_OF_AMMO: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/out_of_ammo"),
			CULTIST_VOICE_TYPE.FLEE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee"),
			CULTIST_VOICE_TYPE.DIALOG_Q: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/dialog_q"),
			CULTIST_VOICE_TYPE.DIALOG_A: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/dialog_a"),
			CULTIST_VOICE_TYPE.DIALOG_SEQUENCE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/dialog_sequence"),
			CULTIST_VOICE_TYPE.SURPRISED: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/surprised"),
			CULTIST_VOICE_TYPE.FIRE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire"),
			CULTIST_VOICE_TYPE.SNAKE: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/snake"),
			CULTIST_VOICE_TYPE.BOMB: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/bomb"),
			CULTIST_VOICE_TYPE.COMET: load_cultists_voicelines("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet")
		 },
	}
}

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


func get_voicelines(voice_actor: VOICE_ACTOR ,voice_tag: CULTIST_VOICE_TYPE) -> Array:
	if !library[AUDIO_TYPE.CULTIST_VOICES].has(voice_actor):
		return []
		
	if !library[AUDIO_TYPE.CULTIST_VOICES][voice_actor].has(voice_tag):
		push_error("voiceline " + str(voice_tag) + " does not exists to voice actor" + str(voice_actor))
		return []
	
	return library[AUDIO_TYPE.CULTIST_VOICES][voice_actor][voice_tag]


func load_cultists_voicelines(sound_dir) -> Array[AudioStream]:
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
