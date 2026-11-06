extends GutTest

## Pins the placement rest-orientation data mechanism: class defaults,
## per-item overrides, identity for non-weapons, and local-space application
## that preserves the yaw authored by the generation steps.

const PlacementOrientationDataScript = preload("res://scenes/worlds/procedural_world/placement_orientation_data.gd")
const MELEE_SCRIPT_PATH = "res://scenes/objects/pickable_items/equipment/melee/melee_item.gd"
const GUN_SCRIPT_PATH = "res://scenes/objects/pickable_items/equipment/ranged/gun_item.gd"
const MACE_SCENE_PATH = "res://scenes/objects/pickable_items/equipment/melee/mace/mace.tscn"


func _make_item_with_script(script_path: String) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(load(script_path))
	return body


func test_default_table_has_melee_and_gun_class_defaults() -> void:
	var table := PlacementOrientationDataScript.default_data()
	assert_not_null(table, "default placement orientation table loads")
	assert_true(table.class_defaults.has("MeleeItem"), "MeleeItem class default present")
	assert_true(table.class_defaults.has("GunItem"), "GunItem class default present")
	assert_eq(Vector3(table.class_defaults["MeleeItem"]), Vector3(-90, 0, 0), "melee default is a 90 degree flip")
	assert_eq(Vector3(table.class_defaults["GunItem"]), Vector3(-90, 0, 0), "gun default is a 90 degree flip")


func test_default_table_overrides_mace_pitchfork_halberd() -> void:
	var table := PlacementOrientationDataScript.default_data()
	for item_path in [
		"res://scenes/objects/pickable_items/equipment/melee/mace/mace.tscn",
		"res://scenes/objects/pickable_items/equipment/melee/pitchfork/pitchfork.tscn",
		"res://scenes/objects/pickable_items/equipment/melee/halberd/halberd.tscn",
	]:
		assert_true(table.item_overrides.has(item_path), "override present for %s" % item_path)


func test_melee_item_resolves_class_default() -> void:
	var table := PlacementOrientationDataScript.default_data()
	var item := _make_item_with_script(MELEE_SCRIPT_PATH)
	assert_eq(table.rest_offset_degrees_for(item, "res://any/path.tscn"), Vector3(-90, 0, 0))


func test_gun_item_resolves_class_default() -> void:
	var table := PlacementOrientationDataScript.default_data()
	var item := _make_item_with_script(GUN_SCRIPT_PATH)
	assert_eq(table.rest_offset_degrees_for(item, "res://any/path.tscn"), Vector3(-90, 0, 0))


func test_gun_subclass_resolves_parent_class_default() -> void:
	var table := PlacementOrientationDataScript.default_data()
	var item := _make_item_with_script("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/revolver_item.gd")
	assert_eq(table.rest_offset_degrees_for(item, "res://any/path.tscn"), Vector3(-90, 0, 0))


func test_override_wins_over_class_default() -> void:
	var table := PlacementOrientationDataScript.default_data()
	var item := _make_item_with_script(MELEE_SCRIPT_PATH)
	var overridden := table.rest_offset_degrees_for(item, MACE_SCENE_PATH)
	assert_eq(overridden, Vector3(table.item_overrides[MACE_SCENE_PATH]))
	assert_eq(overridden, Vector3(-90, 0, 0))


func test_scriptless_node_resolves_identity() -> void:
	var table := PlacementOrientationDataScript.default_data()
	var node := Node3D.new()
	assert_eq(table.rest_offset_degrees_for(node, "res://any/path.tscn"), Vector3.ZERO)
	node.free()


func test_unknown_script_class_resolves_identity() -> void:
	var table := PlacementOrientationDataScript.default_data()
	var node := Node3D.new()
	assert_eq(table.rest_offset_degrees_for(node, "res://any/path.tscn"), Vector3.ZERO)
	node.free()


func test_apply_to_item_preserves_authored_yaw_and_lies_flat() -> void:
	var table := PlacementOrientationDataScript.default_data()
	var item := _make_item_with_script(MELEE_SCRIPT_PATH)
	var yaw := deg_to_rad(45.0)
	item.basis = Basis(Vector3.UP, yaw)
	PlacementOrientationDataScript.apply_to_item(item, "res://any/path.tscn")
	var rotated_up := item.basis.y
	assert_almost_eq(rotated_up.y, 0.0, 0.0001, "long axis lies flat after the flip")
	var expected_direction := (Basis(Vector3.UP, yaw) * Vector3(0, 0, -1))
	assert_almost_eq(rotated_up.dot(expected_direction), 1.0, 0.0001, "yaw authored by generation is preserved")


func test_apply_to_item_leaves_non_weapons_untouched() -> void:
	var node := Node3D.new()
	node.basis = Basis(Vector3.UP, deg_to_rad(30.0))
	PlacementOrientationDataScript.apply_to_item(node, "res://any/path.tscn")
	assert_eq(node.basis, Basis(Vector3.UP, deg_to_rad(30.0)), "identity for items without a matching entry")
	node.free()
