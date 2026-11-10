class_name AIStateFlee
extends AIState

## Move away from the threat (the current target if any, else the last
## stimulus position), re-picking the escape goal each time it is reached.
## Exits through the table, usually on guard_alert_below_investigate once
## the threat stops renewing alertness.


@export var flee_distance := 10.0


func enter() -> void:
	super.enter()
	_run()


func tick(_delta: float) -> void:
	if brain.navigation.at_destination():
		_run()
		return
	move_direction = brain.navigation.move_intent()
	if not move_direction.is_equal_approx(Vector3.ZERO):
		face_direction = move_direction


func _run() -> void:
	var away := character_position() - _threat_position()
	away.y = 0.0
	if away.is_equal_approx(Vector3.ZERO):
		away = Vector3.FORWARD
	brain.navigation.go_to(character_position() + away.normalized() * flee_distance)


func _threat_position() -> Vector3:
	if has_target():
		return current_target_position()
	var current_board := board()
	if current_board != null and current_board.last_stimulus != null:
		return current_board.last_stimulus.position
	return character_position()
