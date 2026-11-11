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
## Distance past which the gun hands back to Approach (3.x re-approached
## every tick while the target drifted out).
@export var shoot_distance := 0.3
## Share of shots that announce the fight voice line (3.x BTShoot parity).
@export_range(0.0, 1.0) var fight_line_chance := 0.25

var weapon: Object = null
var ammo_source: Object = null

var cooldown := 0.0
## One reload announcement per dry period: the real GunItem's staged reload
## no-ops on re-entry, and the reload voice and clip must not restart every
## tick while the rounds land.
var _reload_announced := false


func enter() -> void:
	super.enter()
	cooldown = brain.rng.randf_range(shot_wait_min, shot_wait_max)
	_reload_announced = false
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
	_reload_announced = false
	if cooldown <= 0.0:
		weapon._use_primary()
		if brain.rng.randf() < fight_line_chance:
			anim_event.emit(&"shot")
		cooldown = brain.rng.randf_range(shot_wait_min, shot_wait_max)


## The 3.x melee-fallback rule: MeleeAttack is entered when the mainhand is
## melee or the gun is dry and no ammo exists.
func guard_gun_unusable() -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if int(weapon.current_ammo) >= 1:
		return false
	return not _reserve_exists()


## The target drifted out while shooting: hand back to Approach, the 3.x
## per-tick re-approach.
func guard_out_of_range() -> bool:
	return has_target() and distance_to_target() > shoot_distance


func _reload() -> void:
	var types: Array = weapon.ammo_types
	for ammo_type in types:
		if _reserve_count(ammo_type) > 0:
			weapon.reload()
			if not _reload_announced:
				_reload_announced = true
				_play_reload_clip()
				anim_event.emit(&"reload")
			return


func _play_reload_clip() -> void:
	var gun := weapon as GunItem
	if gun == null or gun.animation_player == null:
		return
	var player := gun.animation_player as AnimationPlayer
	if player.has_animation("reload"):
		player.play("reload")


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
