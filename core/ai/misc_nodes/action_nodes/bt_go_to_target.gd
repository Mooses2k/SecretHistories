class_name BTGoToTarget extends BTAction


# Move to currently selected target position


@export var threshold : float = 0.5: set = set_threshold
var _thresold_squared : float = 0.25


func set_threshold(value : float):
	threshold = value
	_thresold_squared = value*value



func _tick(state : CharacterState) -> int:
	var character = state.character
	var target_delta : Vector3 = state.target_position - character.global_transform.origin
	target_delta.y = 0.0
	if target_delta.length_squared() <= _thresold_squared:
		# Stop moving after reaching destination
#		state.move_direction = Vector3.ZERO

		return BTResult.OK
	
	while state.path.size() > 0:
		var waypoint_delta : Vector3 = state.path[0] - character.global_transform.origin
		waypoint_delta.y = 0.0
		if waypoint_delta.length_squared() < _thresold_squared:
			state.path.pop_front()
		else:
			break
	
	if state.path.size() > 0:
		var waypoint_delta : Vector3 = state.path[0] - character.global_transform.origin
		waypoint_delta.y = 0.0
		state.move_direction = waypoint_delta
		state.face_direction = state.move_direction
		return BTResult.RUNNING

	return BTResult.FAILED
