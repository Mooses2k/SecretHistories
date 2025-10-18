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


## Add more, as they become available
var library:Dictionary = {
	## Structure: library[AUDIO_TYPE][Optional subtype] = [list of audio streams]
	AUDIO_TYPE.FOOTSTEPS: {
		# Will be populated dynamically in _ready()
	},
}


func _ready() -> void:
	# Load footsteps dynamically
	_load_footsteps()
	
	# Load cultist voices
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


func _load_footsteps() -> void:
	## Load footstep sounds dynamically using ResourceLoader
	
	library[AUDIO_TYPE.FOOTSTEPS][FOOTSTEP_TYPES.STONE] = \
		_scan_audio_directory_with_resource_loader("res://resources/sounds/footsteps/stone_footsteps")
	
	library[AUDIO_TYPE.FOOTSTEPS][FOOTSTEP_TYPES.GRAVEL] = \
		_scan_audio_directory_with_resource_loader("res://resources/sounds/footsteps/gravel_footsteps")
	
	library[AUDIO_TYPE.FOOTSTEPS][FOOTSTEP_TYPES.CARPET] = \
		_scan_audio_directory_with_resource_loader("res://resources/sounds/footsteps/carpet_footsteps")
	
	print("Loaded footsteps: Stone=%d, Gravel=%d, Carpet=%d" % [
		library[AUDIO_TYPE.FOOTSTEPS][FOOTSTEP_TYPES.STONE].size(),
		library[AUDIO_TYPE.FOOTSTEPS][FOOTSTEP_TYPES.GRAVEL].size(),
		library[AUDIO_TYPE.FOOTSTEPS][FOOTSTEP_TYPES.CARPET].size()
	])


func _scan_audio_directory_with_resource_loader(directory_path: String) -> Array[AudioStream]:
	## Recursively scan directory using ResourceLoader.list_directory
	## Works in exported builds unlike DirAccess
	
	var loaded_audios: Array[AudioStream] = []
	
	# Ensure proper path format
	if not directory_path.begins_with("res://"):
		directory_path = "res://" + directory_path
	
	if directory_path.ends_with("/"):
		directory_path = directory_path.substr(0, directory_path.length() - 1)
	
	# List all files in directory
	var files: PackedStringArray = ResourceLoader.list_directory(directory_path)
	
	# Supported audio extensions
	var supported_extensions: Array[String] = [".wav", ".ogg", ".mp3"]
	
	# Process each file
	for file in files:
		# Handle subdirectories (they end with "/")
		if file.ends_with("/"):
			var subdirectory_path: String = directory_path + "/" + file
			# Recursively scan subdirectory
			var subdir_audios = _scan_audio_directory_with_resource_loader(subdirectory_path)
			loaded_audios.append_array(subdir_audios)
			continue
		
		# Check if file has supported audio extension
		var file_lower: String = file.to_lower()
		var is_audio: bool = false
		
		for ext in supported_extensions:
			if file_lower.ends_with(ext):
				is_audio = true
				break
		
		if not is_audio:
			continue
		
		# Create full path and load
		var full_path: String = directory_path + "/" + file
		var audio: AudioStream = load(full_path)
		if audio:
			loaded_audios.append(audio)
		else:
			push_warning("Failed to load audio file: " + full_path)
	
	return loaded_audios


func get_footsteps(material: FOOTSTEP_TYPES) -> Array:
	## Add more methods like this, as more audio types are added to this file
	## If there is no subtype, don't add it
	## Alternative if memory usage at start is in question, lazy loading version:
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


## Returns an array with all voicelines in sound_dir
func load_cultists_voicelines(sound_dir: String) -> Array[AudioStream]:
	## Load voicelines using ResourceLoader for build compatibility
	
	if sound_dir.is_empty():
		return []
	
	return _scan_audio_directory_with_resource_loader(sound_dir)
