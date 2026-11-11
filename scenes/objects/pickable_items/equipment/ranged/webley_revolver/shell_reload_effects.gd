extends "res://scenes/objects/pickable_items/equipment/ranged/gun_shell_effects.gd"

var dropped_bullet_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/webley/webley_casing.tscn")
var bullet_shells = preload("res://scenes/objects/pickable_items/tiny/ammo/webley/webley_round.tscn")

var all_shell_positions : Array = []
var all_bullet_shells : Array = []


@onready var bullet_position_1 = %BulletPosition
@onready var bullet_position_2 = %BulletPosition2
@onready var bullet_position_3 = %BulletPosition3
@onready var bullet_position_4 = %BulletPosition4
@onready var bullet_position_5 = %BulletPosition5
@onready var bullet_position_6 = %BulletPosition6


func _ready():
	all_shell_positions.append(bullet_position_1)
	all_shell_positions.append(bullet_position_2)
	all_shell_positions.append(bullet_position_3)
	all_shell_positions.append(bullet_position_4)
	all_shell_positions.append(bullet_position_5)
	all_shell_positions.append(bullet_position_6)


func expell_shells(count : int, world_parent : Node) -> void:
	var gun := owner as GunItem
	var character_forward := Vector3.ZERO
	if gun != null and gun.owner_character is Node3D:
		character_forward = (gun.owner_character as Node3D).global_transform.basis.z
	for i in mini(count, all_shell_positions.size()):
		var marker := all_shell_positions[i] as Marker3D
		if marker == null:
			continue
		spawn_casing(dropped_bullet_shell, world_parent, marker.global_position + Vector3(0, 0.05, 0), 0.0, character_forward * randf_range(0.1, 0.5), Vector3(randf_range(0, 0.6), randf_range(0, 0.8), randf_range(0, 0.5)))


## Realistic ejection mode: each unfired round lands in the world as its
## loose pickup item (webley_round.tscn, a TinyItem carrying the .455 Webley
## ammo data) at the chamber markers, sharing the casing impulse style. The
## casings eject separately through expell_shells.
func expell_live_rounds(count : int, world_parent : Node) -> void:
	var gun := owner as GunItem
	var character_forward := Vector3.ZERO
	if gun != null and gun.owner_character is Node3D:
		character_forward = (gun.owner_character as Node3D).global_transform.basis.z
	for i in mini(count, all_shell_positions.size()):
		var marker := all_shell_positions[i] as Marker3D
		if marker == null:
			continue
		spawn_casing(bullet_shells, world_parent, marker.global_position + Vector3(0, 0.05, 0), 0.0, character_forward * randf_range(0.1, 0.5), Vector3(randf_range(0, 0.6), randf_range(0, 0.8), randf_range(0, 0.5)))


func player_add_shell():
	var holder := _shell_holder()
	if holder != null and holder.has_method("spawn_hand_shell"):
		var shell : Node = holder.call("spawn_hand_shell", bullet_shells, Vector3(0.014, -0.001, -0.003), Vector3(1.372, 6.429, 0.474))
		_pin_insertion_visual(shell)


func player_clear_shell():
	var holder := _shell_holder()
	if holder != null and holder.has_method("clear_hand_shells"):
		holder.call("clear_hand_shells")


func add_shells_to_slot():
	var added_new_shells := bullet_shells.instantiate() as Node3D
	if added_new_shells == null:
		return
	for shells_positions in all_shell_positions:
		var slot := shells_positions as Marker3D
		if slot == null or slot.get_child_count() > 0:
			continue
		slot.add_child(added_new_shells)
		added_new_shells.position = Vector3(0.006, -0.009, 0)
		added_new_shells.rotation_degrees = Vector3(0, 0, -68.136)
		_pin_insertion_visual(added_new_shells)
		return
	added_new_shells.free()


func clear_all_slots():
	for shells_positions in all_shell_positions:
		var slot := shells_positions as Marker3D
		if slot == null:
			continue
		for added_shell in slot.get_children():
			added_shell.queue_free()
