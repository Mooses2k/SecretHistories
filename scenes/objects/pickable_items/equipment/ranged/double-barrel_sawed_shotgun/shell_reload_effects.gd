tool
extends Node

export var expell_shells = true setget expell_shotgun_shells_tools
export var clear_shotgun_shells = true setget clear_shotgun_shells

var shotgun_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/shotgun_shells/12-gauge_shotgun_shell.tscn")

onready var shell_position_1 = $"%ShellPosition1"
onready var shell_position_2 = $"%ShellPosition2"


func clear_shotgun_shells(value):
	clear_shotgun_shells = value
	if not Engine.editor_hint:
		return
	for current_first_shells in $"%ShellPosition1".get_children():
		current_first_shells.queue_free()
		
	for current_first_shells in $"%ShellPosition2".get_children():
		current_first_shells.queue_free()


func expell_shotgun_shells_tools(value):
	expell_shells = true
	if not Engine.editor_hint:
		return
	var first_shell = shotgun_shell.instance() as RigidBody
	var second_shell = shotgun_shell.instance() as RigidBody

	for current_first_shells in $"%ShellPosition1".get_children():
		current_first_shells.queue_free()
		
	for current_first_shells in $"%ShellPosition2".get_children():
		current_first_shells.queue_free()
	
	first_shell.rotation_degrees.z = 100.695
	second_shell.rotation_degrees.z = 100.695
	$"%ShellPosition1".add_child(first_shell)
	$"%ShellPosition2".add_child(second_shell)
	
#	first_shell.apply_impulse(Vector3(0, 0, 0), Vector3(0, 90, 0) * 90)
#	second_shell.apply_impulse(Vector3(0, 0, 0), Vector3(0, 90, 0) * 90)


func expell_shotgun_shells():
	print("Expelling shotgun shells")
	var first_shell = shotgun_shell.instance() as RigidBody
	var second_shell = shotgun_shell.instance() as RigidBody

	var shell_position_1 = $"%ShellPosition1".global_translation
	var shell_position_2 =  $"%ShellPosition2".global_translation
	
	first_shell.rotation_degrees.z = 100.695
	second_shell.rotation_degrees.z = 100.695
	var world_scene = owner.owner_character.owner as Spatial
	print("Shell position 1 is: ", shell_position_1)
	print("Shell position 2 is: ", shell_position_1)
	first_shell.translation = shell_position_1
	second_shell.translation = shell_position_2
	world_scene.add_child(first_shell)
	world_scene.add_child(second_shell)
	print("World Scene is: ", world_scene)
	
	first_shell.apply_torque_impulse(Vector3(0, 0.2, 0) * 0.3)
	second_shell.apply_torque_impulse(Vector3(0, 0.2, 0) * 0.3)
#	first_shell.apply_central_impulse(Vector3(0, 2, 0) * 2)
#	second_shell.apply_central_impulse(Vector3(0, 2, 0) * 2)


func player_add_shell():
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells()

func player_clear_shell():
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()

func delete_clear_shell():
	pass

