# Tests for melee_item.gd damage invariants (Brooks Wave 1 row 3). Pins:
# 1. repeated body contacts never mutate the exported damage values (the old
#    primary_damage1 /= 2 self-halving bug), and
# 2. a cut hit applies secondary_damage1 then secondary_damage2, each exactly
#    once, never primary damage twice, with the values equal to the authored
#    exports.
# The melee script's attack entry points need its scene's audio/timer nodes, so
# the test drives the attack state flags directly, matching what attack_cut sets.
extends GutTest

const MeleeItemScript = preload("res://scenes/objects/pickable_items/equipment/melee/melee_item.gd")

const AUTHORED_P1 := 3
const AUTHORED_P1_TYPE := 1
const AUTHORED_P2 := 4
const AUTHORED_P2_TYPE := 2
const AUTHORED_S1 := 5
const AUTHORED_S1_TYPE := 3
const AUTHORED_S2 := 9
const AUTHORED_S2_TYPE := 4


# Stand-in for a hittable target: records every damage(amount, type) call.
class DamageTarget extends Node:
	var damage_calls := []

	func damage(amount, type):
		damage_calls.append([amount, type])


# Stand-in for the Hitbox hit argument: dev4 melee damage routes through the
# Hurtbox (hitbox.gd only ever passes Hurtbox areas), so the proxy extends
# Hurtbox and forwards its damage() to the hittable target, keeping the
# assertions on target.damage_calls. owner_node mirrors the @onready field the
# production hurtbox gets from its scene owner.
class HitProxy extends Hurtbox:
	var target : Node = null

	func damage(amount : int, type : GlobalConsts.AttackTypes, direction := Vector3.ZERO, origin := Vector3.ZERO):
		target.damage(amount, type)


func _make_melee() -> MeleeItem:
	var item = MeleeItemScript.new()
	item.primary_damage1 = AUTHORED_P1
	item.primary_damage_type1 = AUTHORED_P1_TYPE
	item.primary_damage2 = AUTHORED_P2
	item.primary_damage_type2 = AUTHORED_P2_TYPE
	item.secondary_damage1 = AUTHORED_S1
	item.secondary_damage_type1 = AUTHORED_S1_TYPE
	item.secondary_damage2 = AUTHORED_S2
	item.secondary_damage_type2 = AUTHORED_S2_TYPE
	return item


func _make_hit(target : Node) -> Hurtbox:
	var proxy = HitProxy.new()
	proxy.target = target
	proxy.owner_node = target
	autofree(proxy)
	return proxy


func test_exported_damage_values_equal_the_authored_values():
	var item = _make_melee()
	assert_eq(item.primary_damage1, 3, "authored primary1")
	assert_eq(item.primary_damage2, 4, "authored primary2")
	assert_eq(item.secondary_damage1, 5, "authored secondary1")
	assert_eq(item.secondary_damage2, 9, "authored secondary2")
	item.free()


func test_primary_damage1_unchanged_across_repeated_body_contacts():
	var item = _make_melee()
	var body = Node.new()
	for i in range(5):
		item._on_Hitbox_body_entered(body)
	assert_eq(item.primary_damage1, 3, "body contacts must not halve or otherwise mutate primary_damage1")
	assert_eq(item.primary_damage2, 4, "primary_damage2 also stays authored")
	assert_eq(item.secondary_damage1, 5, "secondary_damage1 stays authored")
	assert_eq(item.secondary_damage2, 9, "secondary_damage2 stays authored")
	# Contacts plus an actual cut attack must still leave the exports intact.
	var target = DamageTarget.new()
	autofree(target)
	item.can_hit = true
	item.did_a_cut = true
	item._on_Hitbox_hit(_make_hit(target))
	assert_eq(item.primary_damage1, 3, "a delivered cut does not mutate primary_damage1 either")
	autofree(body)
	item.free()


func test_cut_applies_secondary_damage_not_primary_twice():
	var item = _make_melee()
	var target = DamageTarget.new()
	autofree(target)
	item.can_hit = true
	item.did_a_cut = true
	item.did_a_thrust = false

	item._on_Hitbox_hit(_make_hit(target))

	assert_eq(target.damage_calls, [[AUTHORED_S1, AUTHORED_S1_TYPE], [AUTHORED_S2, AUTHORED_S2_TYPE]],
		"cut deals secondary1 then secondary2, once each, with the authored values")
	assert_false(item.can_hit, "one hit consumes can_hit so a cut cannot strike twice")
	item.free()


func test_cut_does_not_carry_primary_damage_or_repeat_secondary2():
	var item = _make_melee()
	var target = DamageTarget.new()
	autofree(target)
	item.can_hit = true
	item.did_a_cut = true

	item._on_Hitbox_hit(_make_hit(target))

	for call in target.damage_calls:
		assert_ne(call[0], AUTHORED_P1, "cut must not apply primary_damage1")
		assert_ne(call[0], AUTHORED_P2, "cut must not apply primary_damage2")
	var secondary2_count := 0
	for call in target.damage_calls:
		if call[0] == AUTHORED_S2:
			secondary2_count += 1
	assert_eq(secondary2_count, 1, "secondary_damage2 is applied exactly once per cut")
	item.free()
