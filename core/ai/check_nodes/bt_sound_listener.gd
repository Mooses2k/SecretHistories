class_name BTSoundListener
extends BTNode


signal unseen_sound_heard   # For signalling speech

export var direct_player_sight : NodePath
onready var _direct_player_sight : PlayerSensor = get_node(direct_player_sight) as PlayerSensor
export var listener : NodePath
onready var _listener : SoundListener = get_node(listener) as SoundListener


func tick(state : CharacterState) -> int:
	return Status.FAILURE
	var speech_chance = randf()
#	if not _listener.player_sight_sensor.is_player_detected():
#	if not _direct_player_sight.is_player_detected():
	if _listener.is_sound_detected():
		if _listener.player_inside_listener:
			if (speech_chance > 0.99):
				emit_signal("unseen_sound_heard")
			state.target_position = _listener.get_measured_position()
			print("Sound at :", state.target_position)
			return Status.SUCCESS
	
	return Status.FAILURE
