extends BTCheck


@export var visual_sensor : VisualSensor
@export var touch_sensor : TouchSensor


func tick(state: CharacterState) -> int:
	if is_instance_valid(visual_sensor) and is_instance_valid(touch_sensor):
		if visual_sensor.line_of_sight or touch_sensor.player_touching:
			return OK
	return FAILED
