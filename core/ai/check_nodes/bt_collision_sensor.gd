class_name BTCollisionSensor
extends BTPlayerSensor

# Kinesthetic sense. Bumping up against something.


#export var sensor : NodePath
#onready var _sensor : PlayerSensor = get_node(sensor) as PlayerSensor


func tick(state : CharacterState) -> int:
	if _sensor.is_player_detected():
		state.target_position = _sensor.get_measured_position()
		return Status.SUCCESS
	return Status.FAILURE
