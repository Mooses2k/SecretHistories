class_name AIStateApproach
extends AIState

## Close distance on the current target, refreshing the goal every tick as
## the target moves. Hands off through the table when inside attack range;
## the usual rows are to GunAttack on guard_in_shoot_range and to MeleeAttack
## on guard_weapon_melee when in reach.


@export var hold_distance := 0.3


func enter() -> void:
	super.enter()
	_approach()


func tick(_delta: float) -> void:
	_approach()


func guard_in_shoot_range() -> bool:
	return has_target() and distance_to_target() <= hold_distance


func _approach() -> void:
	if not has_target():
		move_direction = Vector3.ZERO
		return
	brain.navigation.go_to(current_target_position())
	move_direction = brain.navigation.move_intent()
	if not move_direction.is_equal_approx(Vector3.ZERO):
		face_direction = move_direction
