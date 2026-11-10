class_name AIStatePatrol
extends AIState

## Walk to a random point 1 to 15 m away, mirroring the 3.x
## BTSelectRandomTarget radius, then hand back through the table (usually to
## Idle for the wait cadence). The goal goes through the navigation adapter,
## so the walkable-cell clamp applies.


@export var minimum_radius := 1.0
@export var maximum_radius := 15.0


func enter() -> void:
	super.enter()
	_pick_target()


func tick(_delta: float) -> void:
	move_direction = brain.navigation.move_intent()
	if not move_direction.is_equal_approx(Vector3.ZERO):
		face_direction = move_direction


func guard_arrived() -> bool:
	return brain.navigation.at_destination()


func _pick_target() -> void:
	var radius := brain.rng.randf_range(minimum_radius, maximum_radius)
	var angle := brain.rng.randf_range(0.0, TAU)
	var offset := (Vector3.FORWARD * radius).rotated(Vector3.UP, angle)
	brain.navigation.go_to(character_position() + offset)
