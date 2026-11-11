# Tests for the owner-ruled torch cut (melee parity lane, Gate 2). The 3.x
# torch had no melee; the owner ruled that a lit torch swings as a cut while a
# hold never swings. Pins:
# 1. The torch declares a held use, so item_controller routes holds into
#    set_held_use and taps into use_primary on release.
# 2. An unlit tap lights the torch and never arms an attack.
# 3. A lit tap cuts: cooldown starts, the hitbox arms, and the attack noise
#    and animation request go out with the 3.x cut values.
# 4. A tap during cooldown neither re-swings nor blows the torch out.
# 5. The cut delivers its damage pair through the Hurtbox path once each.
# 6. Raising the torch (set_held_use) is a no-op that never swings.
extends GutTest

const TORCH_SCENE := preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.tscn")

const CUT_D1 := 12
const CUT_D1_TYPE := 1
const CUT_D2 := 8
const CUT_D2_TYPE := 4


class RecordingCharacter extends Node:
	var melee_requests : Array = []
	var noises : Array = []

	func play_melee_attack(attack, left_hand, attack_speed = 1.0):
		melee_requests.append([attack, left_hand, attack_speed])

	func apply_attack_noise(level):
		noises.append(level)


class RecordingHurtbox extends Hurtbox:
	var damage_calls : Array = []

	func damage(amount : int, type : GlobalConsts.AttackTypes, direction := Vector3.ZERO, origin := Vector3.ZERO):
		damage_calls.append([amount, type])


func _make_torch() -> TorchItem:
	var torch : TorchItem = TORCH_SCENE.instantiate()
	add_child_autofree(torch)
	return torch


func test_torch_declares_a_held_use():
	var torch := _make_torch()
	assert_true(torch.has_held_use(), "the torch hold is the raise behavior, not a swing")


func test_unlit_tap_lights_and_never_arms_an_attack():
	var torch := _make_torch()
	torch._use_primary()
	assert_true(torch.is_lit, "an unlit tap lights the torch")
	assert_false(torch.on_cooldown, "lighting is not an attack and starts no cooldown")
	assert_false(torch.can_hit, "lighting arms no hitbox")


func test_lit_tap_cuts_with_cooldown_noise_and_request():
	var torch := _make_torch()
	var character : RecordingCharacter = RecordingCharacter.new()
	autofree(character)
	torch.owner_character = character
	torch._use_primary()
	assert_true(torch.is_lit, "precondition: the torch is lit")
	torch._use_primary()
	assert_true(torch.on_cooldown, "a lit tap swings and starts the cooldown")
	assert_true(torch.can_hit, "the swing arms the hitbox")
	assert_eq(character.melee_requests, [[&"attack_cut", false, 1.0]], "a lit tap requests the cut one-shot")
	assert_eq(character.noises, [10.0], "the cut raises the 3.x cut noise level")


func test_lit_tap_during_cooldown_neither_reswings_nor_blow_out():
	var torch := _make_torch()
	torch._use_primary()
	torch._use_primary()
	assert_true(torch.on_cooldown, "precondition: the torch is on cooldown")
	torch._use_primary()
	assert_true(torch.is_lit, "a cooldown tap does not blow the torch out")
	assert_true(torch.on_cooldown, "a cooldown tap does not restart the swing")


func test_cut_delivers_the_damage_pair_through_the_hurtbox():
	var torch := _make_torch()
	var victim : Node = Node.new()
	autofree(victim)
	var hurtbox : RecordingHurtbox = RecordingHurtbox.new()
	hurtbox.owner_node = victim
	autofree(hurtbox)
	torch._use_primary()
	torch._use_primary()
	torch._on_Hitbox_hit(hurtbox)
	assert_eq(hurtbox.damage_calls, [[CUT_D1, CUT_D1_TYPE], [CUT_D2, CUT_D2_TYPE]],
		"the torch cut applies slashing then fire, once each")
	assert_false(torch.can_hit, "one hit consumes the swing")


func test_raising_the_torch_never_swings():
	var torch := _make_torch()
	torch.set_held_use(true)
	assert_false(torch.on_cooldown, "holding the torch starts no cooldown")
	assert_false(torch.can_hit, "holding the torch arms no hitbox")
	assert_false(torch.is_lit, "raising alone neither lights nor unlights")
