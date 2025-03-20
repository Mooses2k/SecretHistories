extends Node
##Generic autoload, to be used as central location to grab any sound collections that are used by many objects. 
##Loading only once, it helps not access the disk every time an object using them is spawned

enum AUDIO_TYPE {FOOTSTEPS} 
##Add more types as required
enum FOOTSTEP_TYPES{STONE, GRAVEL, CARPET}
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
