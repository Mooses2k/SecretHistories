tool
extends Node

#export var spawn_bullet_shells_tool = true setget spawn_bullet_shells
#export var clear_shotgun_shells = true setget clear_shotgun_shells

var shotgun_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/shotgun_shells/12-gauge_shotgun_shell.tscn")



func clear_shotgun_shells():
#	if not Engine.editor_hint:
#		return
	for current_first_shells in $"%ShellSpawnPosition".get_children():
		current_first_shells.queue_free()


func spawn_bullet_shells():
#	if not Engine.editor_hint:
#		return
	var new_shotgun_shell = shotgun_shell.instance() as RigidBody

	for current_first_shells in $"%ShellSpawnPosition".get_children():
		current_first_shells.queue_free()
		

	$"%ShellSpawnPosition".add_child(new_shotgun_shell)
