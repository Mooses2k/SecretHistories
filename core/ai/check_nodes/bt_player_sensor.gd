class_name BT_Player_Sensor
extends BT_Node


signal character_detected

export var sensor : NodePath
onready var _sensor : PlayerSensor = get_node(sensor) as PlayerSensor


func tick(state : CharacterState) -> int:
	if _sensor.is_player_detected():
#		return Status.FAILURE
		state.target_position = _sensor.get_measured_position()
		emit_signal("character_detected")
	return Status.SUCCESS
