extends GutTest
## Gunshot noise formula A (owner-approved): noise = 30 + round(damage / 2),
## pellet ammo uses the total payload (damage * pellet_count), and the
## barrel-shortness modifier applies after the transform (damage_offset is
## negative for shortened barrels, so subtracting it adds noise).

const GunItemScript = preload("res://scenes/objects/pickable_items/equipment/ranged/gun_item.gd")
const AmmunitionDataScript = preload("res://resources/tiny_items/ammunition/ammunition_data.gd")


func _ammo(damage : int, pellet_count : int = 1) -> Resource:
	var ammo : Resource = AmmunitionDataScript.new()
	ammo.damage = damage
	ammo.pellet_count = pellet_count
	autofree(ammo)
	return ammo


func test_linear_mapping_tracks_damage_half_up() -> void:
	assert_eq(GunItemScript.gunshot_noise_for(_ammo(20), 0), 40.0,
		"30 + round(20 / 2) = 40")


func test_odd_damage_rounds_to_nearest() -> void:
	assert_eq(GunItemScript.gunshot_noise_for(_ammo(13), 0), 37.0,
		"30 + round(6.5) = 37 (round-half-away-from-zero)")


func test_pellet_total_uses_damage_times_pellet_count() -> void:
	# Shotgun shell 8 x 9 = 72 -> 30 + 36 = 66
	assert_eq(GunItemScript.gunshot_noise_for(_ammo(8, 9), 0), 66.0,
		"a shotgun shell measures its total payload")


func test_barrel_shortness_applies_after_the_transform() -> void:
	# khyber_pass_martini damage_offset -10: the subtraction adds +10 noise.
	assert_eq(GunItemScript.gunshot_noise_for(_ammo(20), -10), 50.0,
		"a shortened barrel is louder by -damage_offset")
	assert_eq(GunItemScript.gunshot_noise_for(_ammo(8, 9), -10), 76.0,
		"the modifier applies after the pellet total, not to it")
