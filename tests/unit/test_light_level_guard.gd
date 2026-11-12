extends GutTest
## Pins the held-light visibility floor: a held lit lantern forces the
## holder's light_level to at least 0.01 so the holder stays visible to the
## sight gate. That floor is dev4-native (3.x made holder visibility emerge
## from the lantern's OmniLight sampled by the LightDetection viewports;
## dev4 lanterns emit through Spotlight3D, which does not light the holder).
## Owners without the property are skipped instead of erroring every frame.

const LanternScene = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/starstuff_lantern/starstuff_lantern.tscn")


class LitOwnerStub extends Node:
	var light_level := 0.0


func _make_lit_lantern() -> LanternItem:
	var lantern : LanternItem = add_child_autofree(LanternScene.instantiate())
	lantern.light()
	return lantern


func test_lit_lantern_forces_holder_light_level_to_0_01() -> void:
	var lantern := _make_lit_lantern()
	var holder : LitOwnerStub = autofree(LitOwnerStub.new())
	lantern.owner_character = holder

	lantern._process(0.016)

	assert_almost_eq(holder.light_level, 0.01, 0.0001,
		"a held lit lantern keeps the holder visible: light_level forced to at least 0.01")


func test_lit_lantern_skips_owners_without_the_light_level_property() -> void:
	# The guard: before it, this _process read spammed
	# "Invalid access to property or key 'light_level'" every frame with a
	# humanoid holder (audit M3 probe). Humanoid owners carry light_level
	# now, so the skip path is pinned with a holder that has no property,
	# which must not error or kill the burn.
	var holder : Node3D = autofree(Node3D.new())
	var lantern := _make_lit_lantern()
	lantern.owner_character = holder

	lantern._process(0.016)

	assert_true(lantern.is_lit, "the lantern keeps burning: the missing property is skipped, not fatal")
