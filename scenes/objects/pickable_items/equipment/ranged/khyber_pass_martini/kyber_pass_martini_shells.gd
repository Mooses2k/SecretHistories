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


## Realistic ejection mode: the unfired round lands in the world as its loose
## pickup item (martini-henry_round.tscn, a TinyItem carrying the .577
## Martini-Henry ammo data), sharing the casing impulse style.
func expell_live_rounds(count : int, world_parent : Node) -> void:
	if count <= 0:
		return
	var gun := owner as GunItem
	var character_forward := Vector3.ZERO
	if gun != null and gun.owner_character is Node3D:
		character_forward = (gun.owner_character as Node3D).global_transform.basis.z
	var marker := %DropShellPosition as Marker3D
	if marker == null:
		return
	spawn_casing(reload_round_scene, world_parent, marker.global_position, 0.0, character_forward * 3.0, impulse_position)


## The khyber's 3.x method track called only the hand pair: a single-shot
## break-open has no cylinder slots to fill, so there is no slot method.
func player_add_shell():
	var holder := _shell_holder()
	if holder != null and holder.has_method("spawn_hand_shell"):
		var shell : Node = holder.call("spawn_hand_shell", reload_round_scene, Vector3(0.003, -0.006, -0.019), Vector3(-1.448, -16.595, -77.987))
		_pin_insertion_visual(shell)


func player_clear_shell():
	var holder := _shell_holder()
	if holder != null and holder.has_method("clear_hand_shells"):
		holder.call("clear_hand_shells")
