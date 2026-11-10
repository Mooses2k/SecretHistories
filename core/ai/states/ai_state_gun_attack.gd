class_name AIStateGunAttack
extends AIState

## Face the target, reload the mainhand gun when it is dry and the inventory
## holds matching ammo, and fire with a random 0.75 to 1.55 s between shots
## (3.x parity). The weapon and ammo source are injected by the controller:
## the weapon exposes the GunItem surface (current_ammo, ammo_types, reload,
## _use_primary), the ammo source exposes the Inventory surface (tiny_items).
## Leaves through the table when the gun is unusable (dry, no reserve) or the
## target is gone.


@export var shot_wait_min := 0.75
@export var shot_wait_max := 1.55

var weapon: Object = null
var ammo_source: Object = null

var cooldown := 0.0


func enter() -> void:
	super.enter()
	cooldown = brain.rng.randf_range(shot_wait_min, shot_wait_max)
	_face_target()


func tick(delta: float) -> void:
	_face_target()
	move_direction = Vector3.ZERO
	if weapon == null or not is_instance_valid(weapon):
		return
	cooldown -= delta
	if int(weapon.current_ammo) < 1:
		_reload()
		return
	if cooldown <= 0.0:
		weapon._use_primary()
		cooldown = brain.rng.randf_range(shot_wait_min, shot_wait_max)


## The 3.x melee-fallback rule: MeleeAttack is entered when the mainhand is
## melee or the gun is dry and no ammo exists.
func guard_gun_unusable() -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if int(weapon.current_ammo) >= 1:
		return false
	return not _reserve_exists()


func _reload() -> void:
	var types: Array = weapon.ammo_types
	for ammo_type in types:
		if _reserve_count(ammo_type) > 0:
			weapon.reload()
			anim_event.emit(&"reload")
			return


func _reserve_count(ammo_type: Object) -> int:
	if ammo_source == null or not is_instance_valid(ammo_source):
		return 0
	var tiny: Dictionary = ammo_source.tiny_items
	if not tiny.has(ammo_type):
		return 0
	return int(tiny[ammo_type])


func _reserve_exists() -> bool:
	var types: Array = weapon.ammo_types
	for ammo_type in types:
		if _reserve_count(ammo_type) > 0:
			return true
	return false


func _face_target() -> void:
	if has_target():
		face_direction = current_target_position() - character_position()
