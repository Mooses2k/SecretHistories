class_name BT_Sound_Listener
extends BT_Node


export var listener : NodePath
onready var _listener : SoundListener = get_node(listener) as SoundListener


func tick(state : CharacterState) -> int:
	if not _listener.player_sight_sensor.is_player_detected():
		if not _listener.is_sound_detected():
			return Status.FAILURE
		state.target_position = _listener.get_measured_position()
	
	return Status.SUCCESS
