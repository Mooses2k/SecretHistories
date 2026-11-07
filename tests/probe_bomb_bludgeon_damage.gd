## Headless behavior probe for the bomb and bludgeoning melee damage entries
## on rigid large objects. Uses real scenes end to end: the real _bomb.tscn
## (whose Explosion child carries explosions.gd and the BlastRadius area with
## collision_mask 766, matching the statues' collision_layer 512), the real
## detonation handler _on_Bomb_explosion, the real mace scene's melee_item.gd
## body-contact handler (mace.tscn: secondary_damage1 = 51, primary 20),
## statue_gargoyle_2 (rigid, breakable) and statue_angel_1 (static).
## Damage convention: grenade bomb_damage 150 with the /(1 + distance)
## falloff the explosion already applies to characters.
extends Node

var _failures : int = 0


func _check(condition : bool, label : String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		printerr("FAIL: ", label)


func _spawn_statue(scene_path : String, position : Vector3) -> Node3D:
	var statue : Node3D = load(scene_path).instantiate()
	statue.position = position
	add_child(statue)
	return statue


func _make_bomb(bomb_damage : float) -> RigidBody3D:
	var bomb : RigidBody3D = load("res://scenes/objects/pickable_items/equipment/consumable/bomb/_bomb.tscn").instantiate()
	bomb.set("bomb_damage", bomb_damage)
	add_child(bomb)
	return bomb


func _detonate(bomb : RigidBody3D, position : Vector3) -> void:
	bomb.position = position
	var explosion := bomb.get_node("Explosion") as Node3D
	# Let physics register the blast area overlap before the detonation fires.
	for i in 3:
		await get_tree().physics_frame
	var blast := explosion.get_node("BlastRadius") as Area3D
	print("DEBUG detonate at ", position, " overlaps=", blast.get_overlapping_bodies().map(func(b): return b.name))
	# Real detonation path: the same handler the bomb countdown timeout calls.
	explosion.call("_on_Bomb_explosion")


func _run_mace_hit(mace : Node3D, target : Node3D) -> void:
	# Real melee contact event: _on_Hitbox_body_entered on an armed cut swing
	# (attack_cut needs the character sound rig, so arm the flags directly).
	mace.set("can_hit", true)
	mace.set("did_a_cut", true)
	mace.call("_on_Hitbox_body_entered", target)


func _accumulated(statue : Node3D) -> float:
	var shared : Variant = statue.get("_shared")
	if shared == null:
		return -1.0
	return shared.call("get_break_accumulated_damage")


func _dump_children(label : String) -> void:
	print("DEBUG children at ", label, ":")
	for child in get_children():
		var pos : Vector3 = child.position if child is Node3D else Vector3.INF
		print("  ", child.name, " pos=", pos, " queued=", child.is_queued_for_deletion())


func _run() -> void:
	print("=== PROBE BOMB BLUDGEON DAMAGE START ===")

	# (a) Bomb close to statue_gargoyle_2 shatters it. Grenade convention:
	# bomb_damage 150 with /(1 + distance) falloff; at near-zero distance the
	# blast applies floor(150) = 150, over the default threshold 100.
	var close_statue := _spawn_statue("res://scenes/objects/large_objects/statuary/statue_gargoyle_2.tscn", Vector3.ZERO)
	var bomb_a := _make_bomb(150.0)
	await get_tree().process_frame
	var close_pos : Vector3 = close_statue.global_position
	# Detonate beside the statue's live position: the probe world has no
	# floor, so both bodies free-fall; anchoring to the statue keeps the
	# blast offset stable. The gargoyle's convex hull reaches about 0.6 m
	# from the body origin at that height, so 1.0 m puts the bomb just
	# outside the hull, ~0.45 m from its surface, like a bomb landing
	# against the statue's side (damage floor(150 / 1.45) = 103, breaks).
	await _detonate(bomb_a, close_statue.global_position + Vector3(1.0, 0.0, 0.0))
	print("DEBUG close accumulated after detonate: ", _accumulated(close_statue) if is_instance_valid(close_statue) else "freed")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var close_broken : Node3D = null
	for child in get_children():
		if child is Node3D and child.name.contains("Broken") and (child as Node3D).position.distance_to(close_pos) < 1.0:
			close_broken = child
	_check(close_broken != null, "close bomb shatters statue_gargoyle_2 into a broken variant at the same spot")
	_check(not is_instance_valid(close_statue) or close_statue.is_queued_for_deletion(), "intact statue_gargoyle_2 freed after the close blast")
	_dump_children("close bomb")

	# (b) Bomb far away does not shatter a fresh statue. At 5 m the blast
	# applies floor(150 / 6) = 25 damage, under the threshold.
	var far_statue := _spawn_statue("res://scenes/objects/large_objects/statuary/statue_gargoyle_2.tscn", Vector3(50.0, 0.0, 0.0))
	var bomb_b := _make_bomb(150.0)
	await get_tree().process_frame
	await _detonate(bomb_b, far_statue.global_position + Vector3(5.0, 0.0, 0.0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_instance_valid(far_statue) and not far_statue.is_queued_for_deletion(), "bomb 5 m away does not shatter statue_gargoyle_2")
	_check(_accumulated(far_statue) > 0.0 and _accumulated(far_statue) < 100.0, "far bomb applies falloff damage below the threshold, got " + str(_accumulated(far_statue)))

	# (c) Mace-quality melee hits (secondary_damage1 = 51) accumulate past the
	# threshold and break: two hits of 51 cross 100.
	var mace_statue := _spawn_statue("res://scenes/objects/large_objects/statuary/statue_gargoyle_2.tscn", Vector3(100.0, 0.0, 0.0))
	var mace : Node3D = load("res://scenes/objects/pickable_items/equipment/melee/mace/mace.tscn").instantiate()
	add_child(mace)
	await get_tree().process_frame
	print("DEBUG mace_statue global pos before hit1: ", mace_statue.global_position)
	_run_mace_hit(mace, mace_statue)
	print("DEBUG accumulated after hit1: ", _accumulated(mace_statue) if is_instance_valid(mace_statue) else "freed")
	_run_mace_hit(mace, mace_statue)
	print("DEBUG accumulated after hit2: ", _accumulated(mace_statue) if is_instance_valid(mace_statue) else "freed")
	await get_tree().process_frame
	await get_tree().process_frame
	var mace_broken : Node3D = null
	for child in get_children():
		# The second broken variant gets an auto-renamed name (sibling name
		# collision with the close bomb's broken variant), so detect by
		# position rather than by name, excluding the mace itself.
		if child is Node3D and child.name != "Mace" and not (child as Node3D).is_class("RigidBody3D") and (child as Node3D).position.distance_to(Vector3(100.0, 0.0, 0.0)) < 1.0:
			mace_broken = child
	_check(mace_broken != null, "mace-quality melee hits break statue_gargoyle_2")
	_check(not is_instance_valid(mace_statue) or mace_statue.is_queued_for_deletion(), "intact statue freed after the mace hits")
	_dump_children("mace hits")

	# (d) A sub-15 melee hit never registers (below the shared bludgeoning bar).
	var light_statue := _spawn_statue("res://scenes/objects/large_objects/statuary/statue_gargoyle_2.tscn", Vector3(150.0, 0.0, 0.0))
	await get_tree().process_frame
	mace.set("secondary_damage1", 10)
	_run_mace_hit(mace, light_statue)
	_run_mace_hit(mace, light_statue)
	_check(is_instance_valid(light_statue) and not light_statue.is_queued_for_deletion(), "sub-15 melee hits do not damage the statue")
	_check(_accumulated(light_statue) == 0.0, "sub-15 melee hits accumulate nothing, got " + str(_accumulated(light_statue)))

	# (e) angel_1 is static with no broken variant: both entries are no-ops.
	var angel := _spawn_statue("res://scenes/objects/large_objects/statuary/statue_angel_1.tscn", Vector3(200.0, 0.0, 0.0))
	var bomb_c := _make_bomb(150.0)
	await get_tree().process_frame
	await _detonate(bomb_c, angel.global_position + Vector3(1.0, 0.0, 0.0))
	mace.set("secondary_damage1", 51)
	_run_mace_hit(mace, angel)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_instance_valid(angela_guard()) and not angela_guard().is_queued_for_deletion(), "static angel_1 survives the close bomb blast and the bludgeoning melee hit")

	print("=== PROBE BOMB BLUDGEON DAMAGE: FAILURES = ", _failures, " ===")
	if _failures == 0:
		print("PROBE BOMB BLUDGEON DAMAGE: ALL PASS")
	get_tree().quit(1 if _failures > 0 else 0)


# angel_1 root; a guard accessor so a queue_free flush does not trip a stale
# reference mid-probe.
func angela_guard() -> Node:
	for child in get_children():
		if child.name.begins_with("StatueAngel1"):
			return child
	return null


func _ready() -> void:
	_run.call_deferred()
