# Unit tests for the non-kick damage entries into the large object break
# surface: LargeObjectShared.accumulate_bludgeoning_damage, the caller-side
# guard shared by explosions (explosions.gd) and melee (melee_item.gd).
# Kick wiring (humanoid_character.gd) is covered by its own lane.
extends GutTest

const LARGE_OBJECT_SCRIPT := preload("res://scenes/objects/large_objects/large_object.gd")
const STATIC_LARGE_OBJECT_SCRIPT := preload("res://scenes/objects/large_objects/static_large_object.gd")
const TARGET_SCENE := "res://tests/fixtures/break_probe_target.tscn"

var _root : Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func _make_rigid() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(LARGE_OBJECT_SCRIPT)
	# Point the broken-variant lookup at a path with a "_broken" sibling so
	# the runtime-built host resolves as breakable like a real statue scene.
	body.scene_file_path = TARGET_SCENE
	_root.add_child(body)
	return body


func _make_static() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_script(STATIC_LARGE_OBJECT_SCRIPT)
	body.scene_file_path = "res://tests/fixtures/no_broken_variant.tscn"
	_root.add_child(body)
	return body


func test_rigid_breakable_accumulates_bludgeoning_damage() -> void:
	var body := _make_rigid()
	LargeObjectShared.accumulate_bludgeoning_damage(body, 51.0)
	assert_eq(body.get_break_accumulated_damage(), 51.0, "bludgeoning hit over the bar lands on the rigid host")


func test_sub_bar_damage_never_accumulates() -> void:
	var body := _make_rigid()
	LargeObjectShared.accumulate_bludgeoning_damage(body, 14.9)
	assert_eq(body.get_break_accumulated_damage(), 0.0, "damage below the bludgeoning bar is ignored")


func test_static_body_is_a_no_op() -> void:
	var body := _make_static()
	LargeObjectShared.accumulate_bludgeoning_damage(body, 150.0)
	assert_false(body.is_breakable(), "static host without a broken variant stays unbreakable")
	assert_true(is_instance_valid(body) and not body.is_queued_for_deletion(), "static host survives bludgeoning damage")


func test_rigid_without_break_method_is_ignored_safely() -> void:
	var plain := RigidBody3D.new()
	_root.add_child(plain)
	LargeObjectShared.accumulate_bludgeoning_damage(plain, 51.0)
	assert_true(is_instance_valid(plain), "plain rigid body without accumulate_break_damage is skipped without error")
