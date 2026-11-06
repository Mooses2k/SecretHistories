extends SceneTree

## Headless verification: spawn weapons and non-weapons through the real
## generation placement path (ItemSpawnData.spawn_item_in) and dump each
## item's world basis. Weapons must lie flat (long axis horizontal);
## non-weapons keep identity. Quit when done.

const PlacementOrientationDataScript = preload("res://scenes/worlds/procedural_world/placement_orientation_data.gd")

const WEAPONS := [
	"res://scenes/objects/pickable_items/equipment/melee/mace/mace.tscn",
	"res://scenes/objects/pickable_items/equipment/melee/pitchfork/pitchfork.tscn",
	"res://scenes/objects/pickable_items/equipment/melee/halberd/halberd.tscn",
	"res://scenes/objects/pickable_items/equipment/melee/cavalry_sabre/cavalry_sabre_item.tscn",
	"res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn",
]

const NON_WEAPONS := [
	"res://scenes/objects/pickable_items/equipment/containers/bottle_long_medieval.tscn",
	"res://scenes/objects/pickable_items/equipment/components/bones_and_bodies/human_skeleton/jawbone.tscn",
	"res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var all_items := WEAPONS + NON_WEAPONS
	for index in all_items.size():
		var scene_path: String = all_items[index]
		var spawn_data := ItemSpawnData.new()
		spawn_data.scene_path = scene_path
		spawn_data.amount = 1
		spawn_data.set_position_in_cell(Vector3(index * 2.0, 1.0, 0.0))
		spawn_data.set_y_rotation(deg_to_rad(45.0))
		spawn_data.spawn_item_in(root, false)

	await process_frame
	await process_frame

	for child in root.get_children():
		if child is not Node3D:
			continue
		var node3d := child as Node3D
		var basis := node3d.global_basis
		var long_axis_y := basis.y
		var is_weapon: bool = WEAPONS.has(node3d.scene_file_path)
		var lying := absf(long_axis_y.y) < 0.01
		var yaw_kept: bool = is_equal_approx(basis.get_euler().y, deg_to_rad(45.0)) if is_weapon else true
		var status := "PASS"
		if is_weapon and not (lying and yaw_kept):
			status = "FAIL"
			_failures += 1
		print("VERIFY %s | weapon=%s | scene=%s | basis.y=%s | euler_deg=%s" % [
			status, is_weapon, node3d.scene_file_path, long_axis_y,
			node3d.global_basis.get_euler() * (180.0 / PI)
		])

	print("VERIFY TOTAL FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)
