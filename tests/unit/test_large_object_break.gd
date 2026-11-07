# Unit tests for the shared large object break behavior
# (large_object_shared.gd forwarded by static_large_object.gd).
extends GutTest

const TARGET_SCENE := "res://tests/fixtures/break_probe_target.tscn"

var _root : Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func test_unbreakable_host_ignores_damage() -> void:
	var target : Node3D = load(TARGET_SCENE).instantiate()
	# Point the lookup at a path with no "_broken" sibling scene.
	target.scene_file_path = "res://tests/fixtures/no_broken_variant.tscn"
	_root.add_child(target)
	target.accumulate_break_damage(9999.0)
	assert_false(target.is_breakable(), "host without a broken variant is not breakable")
	assert_true(is_instance_valid(target) and not target.is_queued_for_deletion(), "host without a broken variant survives damage")


func test_damage_accumulates_below_threshold_without_breaking() -> void:
	var target : Node3D = load(TARGET_SCENE).instantiate()
	target.break_damage_threshold = 100.0
	_root.add_child(target)
	assert_true(target.is_breakable(), "host with a _broken sibling resolves as breakable")
	target.accumulate_break_damage(40.0)
	target.accumulate_break_damage(40.0)
	assert_eq(target.get("noise_level"), 0.0)
	assert_true(is_instance_valid(target) and not target.is_queued_for_deletion(), "host survives below-threshold damage")


func test_threshold_cross_swaps_into_broken_variant() -> void:
	var target : Node3D = load(TARGET_SCENE).instantiate()
	target.break_damage_threshold = 100.0
	_root.add_child(target)
	await get_tree().process_frame
	var host_transform : Transform3D = target.global_transform
	target.accumulate_break_damage(60.0)
	target.accumulate_break_damage(60.0)
	# The swap runs synchronously on the caller: the noise lands and the host
	# is marked for deletion before the deferred sibling add_child executes.
	assert_eq(target.get("noise_level"), 15.0, "breaking emits the large noise level")
	assert_true(target.is_queued_for_deletion(), "intact host freed after the swap")
	await get_tree().process_frame
	await get_tree().process_frame
	var broken : Node = _root.get_child(_root.get_child_count() - 1)
	assert_true(broken != null and broken.name.contains("Broken"), "broken variant instanced as a sibling")
	assert_eq(broken.global_transform, host_transform, "broken variant sits at the intact host's transform")
