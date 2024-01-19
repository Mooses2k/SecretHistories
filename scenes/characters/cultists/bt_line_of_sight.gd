extends BTCheck


@export(NodePath) onready var visual_sensor = get_node(visual_sensor) as VisualSensor
@export(NodePath) onready var touch_sensor = get_node(touch_sensor) as TouchSensor


func tick(state: CharacterState) -> int:
	if is_instance_valid(visual_sensor) and is_instance_valid(touch_sensor):
		if visual_sensor.line_of_sight or touch_sensor.player_touching:
			return OK
	return FAILED
