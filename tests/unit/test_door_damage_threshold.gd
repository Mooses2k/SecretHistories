# Tests for the damage threshold in base_kinematic_door.gd _damage:
# damage < 10 is a no-op on health, damage >= 10 deducts. The script hard
# depends on its scene's @onready audio nodes, so the real tscn is used.
extends GutTest

const DoorScene = preload("res://scenes/objects/large_objects/doors/base_kinematic_door.tscn")


func _make_door():
	var door = DoorScene.instantiate()
	add_child_autofree(door)
	return door


func test_damage_below_threshold_deducts_no_health():
	var door = _make_door()
	var health_before : float = door.health
	door._damage(5)
	assert_eq(door.health, health_before, "damage < 10 must not deduct health")
	assert_ne(door.door_state, door.DoorState.BROKEN, "door must not break below the threshold")


func test_damage_at_threshold_deducts_health():
	var door = _make_door()
	var health_before : float = door.health
	door._damage(10)
	assert_eq(door.health, health_before - 10.0, "damage == 10 is effective and deducts")


func test_damage_above_threshold_deducts_full_amount():
	var door = _make_door()
	var health_before : float = door.health
	door._damage(20)
	assert_eq(door.health, health_before - 20.0, "damage >= 10 deducts the full amount")
	assert_ne(door.door_state, door.DoorState.BROKEN, "door survives while health stays above zero")
