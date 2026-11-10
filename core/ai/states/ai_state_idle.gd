class_name AIStateIdle
extends AIState

## Stand still, face the last stimulus if there is one, and wait a random
## 5 to 15 s before handing back through the table (3.x SEQ_Idle wait
## parity). The usual handoff is to Patrol for the next pick.


@export var wait_min := 5.0
@export var wait_max := 15.0

var wait_time := 0.0
var elapsed := 0.0


func enter() -> void:
	super.enter()
	elapsed = 0.0
	wait_time = brain.rng.randf_range(wait_min, wait_max)
	var current_board := board()
	if current_board != null and current_board.last_stimulus != null:
		var to_stimulus := current_board.last_stimulus.position - character_position()
		if not to_stimulus.is_equal_approx(Vector3.ZERO):
			face_direction = to_stimulus


func tick(delta: float) -> void:
	elapsed += delta


func guard_wait_elapsed() -> bool:
	return elapsed >= wait_time
