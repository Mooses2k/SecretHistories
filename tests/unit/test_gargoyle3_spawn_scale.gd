# Regression pin: statue_gargoyle_3 keeps its authored 0.36 scale through the
# REAL cell spawn path (GameWorld._spawn_world_data_objects -> SpawnData.spawn_item_in).
#
# Root cause this guards: the fix at 22932da8 put scale 0.36 on the scene ROOT
# node. SpawnData.spawn_item_in does `node3d_item.transform = _transforms[index]`
# and wholesale replaces the root transform with an identity-basis placement
# transform, discarding the authored scale, so in-game the statue spawned giant
# (~6.1 m tall) even though the scene file read right in the editor.
#
# Intended size (docs/research/statue-trophy-placement-scale-fix.md): footprint
# about 1.37 x 2.20 x 0.76 m; measured preview height 2.203 m. The pedestal is
# 1.37 m tall, so the statue reads as a normal trophy piece next to it.
extends GutTest

const GARGOYLE_3_SCENE := "res://scenes/objects/large_objects/statuary/statue_gargoyle_3.tscn"
const INTENDED_HEIGHT_M := 2.203
const HEIGHT_TOLERANCE_RATIO := 0.10
const INTENDED_MESH_SCALE := 0.36


func test_gargoyle3_keeps_authored_scale_through_real_spawn_path() -> void:
	var scene: PackedScene = load(GARGOYLE_3_SCENE)
	assert_not_null(scene, "statue_gargoyle_3.tscn loads")

	var holder := Node3D.new()
	autofree(holder)
	add_child(holder)

	# Mirror generate_trophy_room._set_statue_spawn_data + game_world spawn:
	# position in cell, y rotation, then SpawnData.spawn_item_in.
	var sd := SpawnData.new()
	autofree(sd)
	sd.scene_path = GARGOYLE_3_SCENE
	sd.amount = 1
	sd.set_position_in_cell(Vector3(12.0, 0.0, 12.0))
	sd.set_y_rotation(0.5)
	sd.spawn_item_in(holder, false)

	await get_tree().process_frame

	var spawned := _find_spawned(holder)
	assert_not_null(spawned, "statue spawned through SpawnData")
	if spawned == null:
		return

	var mesh := spawned.find_child("MeshInstance3D", true, false) as MeshInstance3D
	assert_not_null(mesh, "statue has a MeshInstance3D")
	if mesh == null:
		return

	var mesh_scale := mesh.global_transform.basis.get_scale()
	assert_almost_eq(mesh_scale.x, INTENDED_MESH_SCALE, 0.01,
			"mesh global scale must keep the authored 0.36 through the spawn path")
	assert_almost_eq(mesh_scale.y, INTENDED_MESH_SCALE, 0.01,
			"mesh global y scale must keep the authored 0.36")

	var world_aabb: AABB = mesh.global_transform * mesh.mesh.get_aabb()
	var height := world_aabb.size.y
	var tolerance := INTENDED_HEIGHT_M * HEIGHT_TOLERANCE_RATIO
	assert_almost_eq(height, INTENDED_HEIGHT_M, tolerance,
			"spawned statue visual height must match the intended ~2.2 m (pedestal-scale), was %.3f" % height)


func _find_spawned(parent: Node) -> Node:
	for child in parent.get_children():
		if child.scene_file_path == GARGOYLE_3_SCENE:
			return child
	return null
