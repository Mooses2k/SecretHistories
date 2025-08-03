class_name LargeObject
extends RigidBody3D

#const ImpactAudioManager = preload("res://scenes/audio/impact_audio_manager.gd")

var drop_sound_scene = preload("res://scenes/effects/drop_sound.tscn")
var item_drop_sound : AudioStream
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 0

@onready var impact_audio_manager : ImpactAudioManager


func _enter_tree():
	# Create and configure the impact audio manager
	impact_audio_manager = ImpactAudioManager.new()
	add_child(impact_audio_manager)
	impact_audio_manager.configure_for_object_type("large_object")


func _ready():
	# Configure the audio manager with our sound and noise settings
	# Use call_deferred with a slight delay to ensure child classes have set their values first
	await get_tree().process_frame
	_configure_audio_manager()


func _configure_audio_manager():
	prints("LARGE OBJECT DEBUG - Configuring audio manager")
	prints("LARGE OBJECT DEBUG - impact_audio_manager:", impact_audio_manager)
	prints("LARGE OBJECT DEBUG - item_drop_sound:", item_drop_sound)
	prints("LARGE OBJECT DEBUG - item_max_noise_level:", item_max_noise_level)
	
	if impact_audio_manager and item_drop_sound:
		impact_audio_manager.drop_sound = item_drop_sound
		impact_audio_manager.max_noise_level = item_max_noise_level
		prints("LARGE OBJECT DEBUG - Audio manager configured successfully")
	else:
		prints("LARGE OBJECT DEBUG - Failed to configure audio manager!")


func _integrate_forces(state):
	# Delegate impact detection to the audio manager
	if impact_audio_manager:
		impact_audio_manager.process_impact_detection(state)


## Method for the audio manager to set noise level
func set_noise_level(level: float):
	noise_level = level
