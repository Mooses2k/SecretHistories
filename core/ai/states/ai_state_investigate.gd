class_name AIStateInvestigate
extends AIState

## Go to the last stimulus, search briefly on arrival, and decay back
## through the table: either the search ends or alertness decays below the
## investigate bar mid-goto (the give-up rule: searching persists for a
## tracked duration, then the creature returns to patrol).


@export var search_time := 3.0

var arrived := false
var search_elapsed := 0.0


func enter() -> void:
	super.enter()
	arrived = false
	search_elapsed = 0.0
	var current_board := board()
	if current_board != null and current_board.last_stimulus != null:
		brain.navigation.go_to(current_board.last_stimulus.position)


func tick(delta: float) -> void:
	if not arrived and brain.navigation.at_destination():
		arrived = true
		move_direction = Vector3.ZERO
	if arrived:
		search_elapsed += delta
	else:
		move_direction = brain.navigation.move_intent()


func guard_search_elapsed() -> bool:
	return arrived and search_elapsed >= search_time
