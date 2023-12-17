extends Node

export var impulse_position_1 : Vector3 = Vector3(0, 0.2, 0.1)
export var impulse_position_2 : Vector3 = Vector3(0, 0.2, 0.1)


var shotgun_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/shotgun_shells/12-gauge_shotgun_shell.tscn")

onready var shell_position_1 = $"%ShellPosition1"
onready var shell_position_2 = $"%ShellPosition2"

var all_shell_positions : Array = []

func expell_shotgun_shells():
	all_shell_positions.append(shell_position_1)
	all_shell_positions.append(shell_position_2)
	
	print("Expelling shotgun shells")
	var first_shell = shotgun_shell.instance() as RigidBody
	var second_shell = shotgun_shell.instance() as RigidBody
	
	var shell_position_1 = $"%ShellPosition1".global_translation
	var shell_position_2 =  $"%ShellPosition2".global_translation
	
	first_shell.rotation_degrees.z = 100.695
	second_shell.rotation_degrees.z = 100.695
	
	var world_scene
	if is_instance_valid(GameManager.game):
		world_scene = GameManager.game
	else:
		world_scene = owner.owner_character.owner as Spatial
	
	first_shell.translation = shell_position_1
	second_shell.translation = shell_position_2
	
	world_scene.add_child(first_shell)
	world_scene.add_child(second_shell)
	
	first_shell.apply_impulse(impulse_position_1, owner.owner_character.global_transform.basis.z * 3)
	second_shell.apply_impulse(impulse_position_2, owner.owner_character.global_transform.basis.z * 3)


func add_shells_to_slot():
	var added_new_shells = shotgun_shell.instance()
	added_new_shells.translation = Vector3(0.001, -0.035, 0)
	added_new_shells.rotation_degrees = Vector3(0, 0, -82.59)
	for shells_positions in all_shell_positions:
		if shells_positions.get_child_count() < 1:
			shells_positions.add_child(added_new_shells)


func clear_all_slots():
	var added_new_shells = shotgun_shell.instance()
	for shells_positions in all_shell_positions:
		for bullet_shells in shells_positions.get_children():
			bullet_shells.queue_free()


func player_add_shell():
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells(shotgun_shell, Vector3(), Vector3())

func player_clear_shell():
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()
