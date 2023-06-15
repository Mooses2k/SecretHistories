class_name BT_Player_Sensor
extends BT_Node


signal character_detected   # For signalling speech

export var sensor : NodePath
onready var _sensor : PlayerSensor = get_node(sensor) as PlayerSensor


func tick(state : CharacterState) -> int:
	var speech_chance = randf()
	if _sensor.is_player_detected():
		state.target_position = _sensor.get_measured_position()
		if (speech_chance > 0.99):
			emit_signal("character_detected")
		return Status.SUCCESS
	return Status.FAILURE
