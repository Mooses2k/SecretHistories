extends Node

export var impulse_position : Vector3 = Vector3(0, 0.2, 0.1)
export var impulse_value : Vector3 = Vector3(0, 0.3, 0.2)

var shotgun_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/shotgun_shells/12-gauge_shotgun_shell.tscn")

onready var shell_position_1 = $"%ShellPosition1"
onready var shell_position_2 = $"%ShellPosition2"

func expell_shotgun_shells():
	print("Expelling shotgun shells")
	var first_shell = shotgun_shell.instance() as RigidBody
	var second_shell = shotgun_shell.instance() as RigidBody

	var shell_position_1 = $"%ShellPosition1".global_translation
	var shell_position_2 =  $"%ShellPosition2".global_translation
	
	first_shell.rotation_degrees.z = 100.695
	second_shell.rotation_degrees.z = 100.695
	var world_scene = owner.owner_character.owner as Spatial
	first_shell.translation = shell_position_1
	second_shell.translation = shell_position_2
	
	world_scene.add_child(first_shell)
	world_scene.add_child(second_shell)
	
	first_shell.apply_impulse(impulse_position, impulse_value)
	second_shell.apply_impulse(impulse_position, impulse_value)


func player_add_shell():
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells()

func player_clear_shell():
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()
