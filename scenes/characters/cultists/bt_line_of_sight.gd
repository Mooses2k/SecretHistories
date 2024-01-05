extends BTCheck

export(NodePath) onready var visual_sensor = get_node(visual_sensor) as VisualSensor

func tick(state: CharacterState) -> int:
	if visual_sensor.line_of_sight:
		return OK
	return FAILED
