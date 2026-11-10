class_name AIStateSuspicious
extends AIState

## Face the stimulus and hold briefly: the reaction when alertness is below
## the investigate bar. Exits through the table once the hold elapses or
## alertness rises into the investigate band.


@export var hold_time := 2.0

var elapsed := 0.0


func enter() -> void:
	super.enter()
	elapsed = 0.0
	var current_board := board()
	if current_board != null and current_board.last_stimulus != null:
		var to_stimulus := current_board.last_stimulus.position - character_position()
		if not to_stimulus.is_equal_approx(Vector3.ZERO):
			face_direction = to_stimulus


func tick(delta: float) -> void:
	elapsed += delta


func guard_hold_elapsed() -> bool:
	return elapsed >= hold_time
