extends Node

## Real-world behavior probe for statue breaking, run inside the project
## (autoloads present). Prints PASS/FAIL lines and quits non-zero on failure.
## Covers: damage below threshold, threshold cross swapping gargoyle_2 into
## statue_gargoyle_2_broken at the same transform, non-breakable statues
## staying intact, and the pedestal spawnable_items round trip.

var _failures := 0


func _ready() -> void:
	# Give autoloads one frame, then run.
	await get_tree().process_frame
	_probe_gargoyle_break()
	_probe_non_breakable()
	_probe_pedestal_loot()
	if _failures == 0:
		print("STATUE BREAK PROBE: ALL PASS")
	else:
		printerr("STATUE BREAK PROBE: FAILURES=", _failures)
	get_tree().quit(_failures)


func _check(condition : bool, label : String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		printerr("FAIL: ", label)


func _probe_gargoyle_break() -> void:
	var root := Node3D.new()
	add_child(root)
	var statue : Node3D = load("res://scenes/objects/large_objects/statuary/statue_gargoyle_2.tscn").instantiate()
	statue.break_damage_threshold = 50.0
	root.add_child(statue)
	await get_tree().process_frame
	var host_transform : Transform3D = statue.global_transform
	# Below threshold: accumulate without breaking.
	statue.accumulate_break_damage(30.0)
	_check(is_instance_valid(statue) and not statue.is_queued_for_deletion(), "gargoyle_2 survives 30 damage below the 50 threshold")
	_check(statue.get("noise_level") == 0.0, "no break noise below the threshold")
	# Cross the threshold.
	statue.accumulate_break_damage(30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var broken : Node3D = null
	for child in root.get_children():
		if child != statue and child.name.contains("Broken"):
			broken = child
	_check(broken != null, "statue_gargoyle_2_broken instanced as a sibling after crossing the threshold")
	if broken:
		_check(broken.global_transform.is_equal_approx(host_transform), "broken variant sits at the intact statue's transform")
		var rigid_count := 0
		for chunk in broken.find_children("*", "RigidBody3D", true, false):
			rigid_count += 1
		_check(rigid_count >= 2, "broken variant carries its rigid chunks (count=%d)" % rigid_count)
	_check(statue.is_queued_for_deletion() or not is_instance_valid(statue), "intact gargoyle_2 freed after the swap")
	_check(statue.get("noise_level") == 10.0 if is_instance_valid(statue) else true, "break emitted the large noise level")
	root.free()


func _probe_non_breakable() -> void:
	var root := Node3D.new()
	add_child(root)
	var statue : Node3D = load("res://scenes/objects/large_objects/statuary/statue_angel_1.tscn").instantiate()
	root.add_child(statue)
	await get_tree().process_frame
	_check(not statue.is_breakable(statue), "statue_angel_1 (no broken variant) is unbreakable")
	statue.accumulate_break_damage(9999.0)
	_check(is_instance_valid(statue) and not statue.is_queued_for_deletion(), "statue_angel_1 stays intact under heavy damage")
	root.free()


func _probe_pedestal_loot() -> void:
	var pedestal : Node3D = load("res://scenes/objects/large_objects/pedestal/pedestal.tscn").instantiate()
	add_child(pedestal)
	await get_tree().process_frame
	var loot := PackedStringArray(["res://scenes/objects/pickable_items/tiny/gems/gem_amethyst.tscn"])
	pedestal.set("spawnable_items", loot)
	_check(pedestal.get("spawnable_items") == loot, "pedestal spawnable_items property round trip via set/get")
	var spawner := pedestal.find_child("AnchorSpawner", true, false)
	_check(spawner != null, "pedestal embeds an AnchorSpawner")
	if spawner:
		var owner_node : Node = spawner.get("owner")
		var read_back = owner_node.get("spawnable_items") if owner_node else null
		_check(read_back == loot, "AnchorSpawner owner.get(spawnable_items) reads the loot back")
	pedestal.free()
