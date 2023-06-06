class_name BT_Collision_Sensor
extends BT_Player_Sensor


#signal character_detected   # For signalling speech

#export var sensor : NodePath
#onready var _sensor : PlayerSensor = get_node(sensor) as PlayerSensor


func tick(state : CharacterState) -> int:
	if _sensor.is_player_detected():
		state.target_position = _sensor.get_measured_position()
		emit_signal("character_detected")
		return Status.SUCCESS
	return Status.FAILURE
