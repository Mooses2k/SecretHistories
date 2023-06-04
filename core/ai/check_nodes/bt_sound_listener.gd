class_name BT_Sound_Listener
extends BT_Node


signal unseen_sound_heard

export var direct_player_sight : NodePath
onready var _direct_player_sight : PlayerSensor = get_node(direct_player_sight) as PlayerSensor
export var listener : NodePath
onready var _listener : SoundListener = get_node(listener) as SoundListener


func tick(state : CharacterState) -> int:
#	if not _listener.player_sight_sensor.is_player_detected():
	if not _direct_player_sight.is_player_detected():
		
		if not _listener.is_sound_detected():
			return Status.FAILURE
		emit_signal("unseen_sound_heard")
		print("Unseen sound heard")
		state.target_position = _listener.get_measured_position()
	
	return Status.SUCCESS
