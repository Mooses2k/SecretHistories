# Tests for the torch light hold-up (melee2 lane). The owner ruling: holding
# the use key on a torch raises the light and never swings; the 3.x torch had
# no hold behavior at all and no 4.x light hold-up ever existed, so this pins
# the raise seam landed in this lane:
# 1. A hold raises the light through the character seam, once, main hand.
# 2. The hold never swings: no cooldown, no armed hitbox, no light change.
# 3. Releasing lowers the light back down.
# 4. A character without the seam (duck-typed guard) takes no raise and the
#    hold still never swings.
extends GutTest

const TORCH_SCENE := preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.tscn")


class RecordingCharacter extends Node:
	var raise_calls : Array = []

	func set_light_hold_up(enabled : bool) -> void:
		raise_calls.append(enabled)


func _make_torch() -> TorchItem:
	var torch : TorchItem = TORCH_SCENE.instantiate()
	add_child_autofree(torch)
	return torch


func test_hold_raises_the_light_in_the_main_hand():
	var torch := _make_torch()
	var character : RecordingCharacter = RecordingCharacter.new()
	autofree(character)
	torch.owner_character = character
	torch.set_held_use(true)
	assert_eq(character.raise_calls, [true], "a main-hand hold raises the light once")
	assert_false(torch.on_cooldown, "raising starts no cooldown")
	assert_false(torch.can_hit, "raising arms no hitbox")
	assert_false(torch.is_lit, "raising neither lights nor unlights")
	assert_true(torch.is_held(), "the held flag tracks the hold")


func test_release_lowers_the_light_back_down():
	var torch := _make_torch()
	var character : RecordingCharacter = RecordingCharacter.new()
	autofree(character)
	torch.owner_character = character
	torch.set_held_use(true)
	torch.set_held_use(false)
	assert_eq(character.raise_calls, [true, false], "release lowers the light once")


func test_character_without_the_seam_never_swings_and_never_crashes():
	var torch := _make_torch()
	var character : Node = Node.new()
	autofree(character)
	torch.owner_character = character
	torch.set_held_use(true)
	assert_false(torch.on_cooldown, "a hold on a seam-less character never swings")
	assert_false(torch.can_hit, "a hold on a seam-less character arms no hitbox")
