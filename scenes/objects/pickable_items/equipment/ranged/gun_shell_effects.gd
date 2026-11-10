## Base for the per-gun reload shell effect nodes. A reload press opens the
## action and ejects the gun's spent cases as world physics debris; each gun
## script owns its casing scene, chamber markers, and impulses, and adds the
## per-round insertion visuals (Phase 3) on top. Extending scripts reference
## this file by path: a new class_name stays invisible to headless runs until
## the editor regenerates the global class cache.
extends Node


## Eject up to count spent cases into world_parent. Per-gun scripts override
## this; the base does nothing so an unconfigured gun stays silent.
func expell_shells(_count : int, _world_parent : Node) -> void:
	pass


## Eject up to count unfired rounds as loose-ammo pickup items into
## world_parent (realistic ejection mode: every chamber empties, and each
## live round lands in the world for the group pickup to gather). Per-gun
## scripts override this with their gun's loose round scene; the base does
## nothing so an unconfigured gun stays silent.
func expell_live_rounds(_count : int, _world_parent : Node) -> void:
	pass


## Spawn one casing scene as world debris at the given position, with the
## shooter-forward impulse and an offset that makes the casing tumble.
func spawn_casing(casing_scene : PackedScene, world_parent : Node, spawn_position : Vector3, rotation_z_degrees : float = 0.0, impulse : Vector3 = Vector3.ZERO, impulse_offset : Vector3 = Vector3.ZERO) -> void:
	if world_parent == null or casing_scene == null:
		return
	var casing := casing_scene.instantiate() as RigidBody3D
	if casing == null:
		push_warning("Casing scene has no RigidBody3D root: " + casing_scene.resource_path)
		return
	casing.rotation_degrees.z = rotation_z_degrees
	world_parent.add_child(casing)
	casing.global_position = spawn_position
	if impulse != Vector3.ZERO:
		casing.apply_impulse(impulse, impulse_offset)
