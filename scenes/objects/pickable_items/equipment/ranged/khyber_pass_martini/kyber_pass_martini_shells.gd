extends "res://scenes/objects/pickable_items/equipment/ranged/gun_shell_effects.gd"

@export var impulse_position : Vector3 = Vector3(0, 0.2, 0.1)

var casing_scene = preload("res://scenes/objects/pickable_items/tiny/ammo/martini-henry/martini-henry_casing.tscn")
var reload_round_scene = preload("res://scenes/objects/pickable_items/tiny/ammo/martini-henry/martini-henry_round.tscn")


func expell_shells(count : int, world_parent : Node) -> void:
	if count <= 0:
		return
	var gun := owner as GunItem
	var character_forward := Vector3.ZERO
	if gun != null and gun.owner_character is Node3D:
		character_forward = (gun.owner_character as Node3D).global_transform.basis.z
	var marker := %DropShellPosition as Marker3D
	if marker == null:
		return
	spawn_casing(casing_scene, world_parent, marker.global_position, 100.695, character_forward * 3.0, impulse_position)


func player_add_shell():
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells(reload_round_scene, Vector3(0.003, -0.006, -0.019), Vector3(-1.448, -16.595, -77.987))


func player_clear_shell():
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()
