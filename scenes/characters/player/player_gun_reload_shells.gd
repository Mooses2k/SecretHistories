tool
extends Node

func clear_shotgun_shells() -> void:
	for current_first_shells in $"%ShellSpawnPosition".get_children():
		current_first_shells.queue_free()


func spawn_bullet_shells(bullet_shell, spawn_position : Vector3, spawn_rotation : Vector3) -> void:
	var new_gun_shell = bullet_shell.instance() as RigidBody
	var guns_shell_mesh = new_gun_shell.get_node("MeshInstance") as MeshInstance
	clear_shotgun_shells()
	
	$"%ShellSpawnPosition".add_child(new_gun_shell)

	new_gun_shell.translation = spawn_position
	new_gun_shell.rotation_degrees = spawn_rotation
