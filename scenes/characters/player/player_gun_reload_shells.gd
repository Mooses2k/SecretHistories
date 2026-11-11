extends Node
## Character-side reload shell holder (3.x parity port of
## player_gun_reload_shells.gd): the left hand's spawn point for the reload
## insertion visual. A gun's shell effect node spawns the live round visual
## here on each landed reload round; every spawn clears the previous shell,
## and the gun clears the holder together with the rest of the insertion
## visuals when the reload ends. Lives on the humanoid base scene as the
## GunReloadShells node; the spawn marker sits under the left hand's
## OffHandRoot (3.x: ShellSpawnPosition under the offhand bone attachment).


## Spawns one live round visual in the left hand and clears the previous one
## (3.x spawn_bullet_shells contract). Returns the spawned shell, or null
## when the marker or the scene is missing. The caller owns the shell's
## physics pinning; the shell must not fall off the hand.
func spawn_hand_shell(shell_scene : PackedScene, spawn_position : Vector3, spawn_rotation_degrees : Vector3) -> Node3D:
	var spawn_marker := get_node_or_null("%ShellSpawnPosition") as Marker3D
	if spawn_marker == null:
		push_warning("Reload shell holder has no ShellSpawnPosition marker: " + str(get_path()))
		return null
	if shell_scene == null:
		return null
	clear_hand_shells()
	var shell := shell_scene.instantiate() as Node3D
	if shell == null:
		push_warning("Hand shell scene has no Node3D root: " + shell_scene.resource_path)
		return null
	spawn_marker.add_child(shell)
	shell.position = spawn_position
	shell.rotation_degrees = spawn_rotation_degrees
	return shell


## Empties the hand's shell spawn point (3.x clear_shotgun_shells contract).
func clear_hand_shells() -> void:
	var spawn_marker := get_node_or_null("%ShellSpawnPosition") as Marker3D
	if spawn_marker == null:
		return
	for shell in spawn_marker.get_children():
		shell.queue_free()


## Whether a hand shell visual is currently showing.
func has_hand_shell() -> bool:
	var spawn_marker := get_node_or_null("%ShellSpawnPosition") as Marker3D
	if spawn_marker == null:
		return false
	return spawn_marker.get_child_count() > 0
