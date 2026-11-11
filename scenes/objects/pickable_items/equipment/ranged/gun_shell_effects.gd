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


## The landed reload round's insertion visual: the live round appears in the
## character's left hand (3.x player_add_shell, when the per-gun script
## defines it) and one chamber visual fills the gun's cylinder or breech
## slots (3.x add_shells_to_slot, when defined). The per-gun scripts declare
## exactly the methods their 3.x method tracks called; the khyber defines
## only the hand pair (its 3.x track never filled a slot), so discovery by
## has_method keeps an unconfigured gun silent.
func insert_landed_round() -> void:
	if has_method("player_add_shell"):
		call("player_add_shell")
	if has_method("add_shells_to_slot"):
		call("add_shells_to_slot")


## Empties every insertion visual: the hand shell (3.x player_clear_shell)
## plus all chamber slot visuals (3.x clear_all_slots). GunItem calls this
## when the reload fully ends, natural completion and abort alike, so the
## inserted and pending visuals clear with the close beat.
func clear_insertion_visuals() -> void:
	if has_method("player_clear_shell"):
		call("player_clear_shell")
	if has_method("clear_all_slots"):
		call("clear_all_slots")


## The character's left-hand shell holder (the GunReloadShells node on the
## humanoid base scene), or null when the character carries none: a missing
## holder drops the hand visual but never the chamber slot visuals.
func _shell_holder() -> Node:
	var gun := owner as GunItem
	if gun == null or gun.owner_character == null:
		return null
	return (gun.owner_character as Node).get_node_or_null("GunReloadShells")


## Pins an insertion visual in place: a loose round scene spawns in the
## DROPPED physics state and would fall off the hand or the chamber marker.
## The visual is never a live pickup while inserted, so it rides its parent
## frozen and uncollidable until the clear frees it.
func _pin_insertion_visual(shell : Node) -> void:
	var body := shell as RigidBody3D
	if body == null:
		return
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
