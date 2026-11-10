class_name AIStateMeleeAttack
extends AIState

## Chop with a cooldown; thrust when the equipped item exposes the thrust
## attack and the thrust_ratio roll picks it (owner ruling: simple chop,
## maybe thrust; the ratio defaults to chop-only until tuning). Reach and
## cadence are tuning values, phase-4 territory. The weapon is injected by
## the controller and exposes the MeleeItem surface (attack_cut,
## attack_thrust).


@export var reach := 1.5
@export var attack_wait_min := 0.75
@export var attack_wait_max := 1.55
@export_range(0.0, 1.0) var thrust_ratio := 0.0

var weapon: Object = null

var cooldown := 0.0


func enter() -> void:
	super.enter()
	cooldown = 0.0


func tick(delta: float) -> void:
	_face_target()
	move_direction = Vector3.ZERO
	if weapon == null or not is_instance_valid(weapon):
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if brain.rng.randf() < thrust_ratio and weapon.has_method("attack_thrust"):
		weapon.attack_thrust()
		anim_event.emit(&"attack_thrust")
	else:
		weapon.attack_cut()
		anim_event.emit(&"attack_cut")
	cooldown = brain.rng.randf_range(attack_wait_min, attack_wait_max)


func guard_in_reach() -> bool:
	return has_target() and distance_to_target() <= reach


func _face_target() -> void:
	if has_target():
		face_direction = current_target_position() - character_position()
