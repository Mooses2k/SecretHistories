extends Node

export var impulse_position : Vector3 = Vector3(0, 0.2, 0.1)
export var impulse_value : Vector3 = Vector3(0, 0.3, 0.2)

var webley_expell_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/shotgun_shells/12-gauge_shotgun_shell.tscn")
var webley_reload_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/martini-henry/martini-henry_round.tscn")


func expell_shells():
	print("Expelling shotgun shells")
	var first_shell = webley_expell_shell.instance() as RigidBody

	var shell_position_1 = $"%DropShellPosition".global_translation
	
	first_shell.rotation_degrees.z = 100.695
	
	var world_scene
	if is_instance_valid(GameManager.game):
		world_scene = GameManager.game
	else:
		world_scene = owner.owner_character.owner as Spatial
	
	first_shell.translation = shell_position_1
	world_scene.add_child(first_shell)
	first_shell.apply_impulse(impulse_position, impulse_value)


func player_add_shell():
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells(webley_reload_shell, Vector3(0.003, -0.006, -0.019), Vector3(-1.448, -16.595, -77.987))


func player_clear_shell():
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()
