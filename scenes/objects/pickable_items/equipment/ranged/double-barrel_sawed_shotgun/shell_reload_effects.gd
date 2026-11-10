extends "res://scenes/objects/pickable_items/equipment/ranged/gun_shell_effects.gd"

@export var impulse_position_1 : Vector3 = Vector3(0, 0.2, 0.1)
@export var impulse_position_2 : Vector3 = Vector3(0, 0.2, 0.1)

var shotgun_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/shotgun_shells/12-gauge_shotgun_shell.tscn")

var all_shell_positions : Array = []

@onready var shell_position_1 = %ShellPosition1
@onready var shell_position_2 = %ShellPosition2


func _ready() -> void:
	all_shell_positions.append(shell_position_1)
	all_shell_positions.append(shell_position_2)


func expell_shells(count : int, world_parent : Node) -> void:
	var gun := owner as GunItem
	var character_forward := Vector3.ZERO
	if gun != null and gun.owner_character is Node3D:
		character_forward = (gun.owner_character as Node3D).global_transform.basis.z
	for i in mini(count, all_shell_positions.size()):
		var marker := all_shell_positions[i] as Marker3D
		if marker == null:
			continue
		var impulse_offset := impulse_position_1 if i == 0 else impulse_position_2
		spawn_casing(shotgun_shell, world_parent, marker.global_position, 100.695, character_forward * 3.0, impulse_offset)


func add_shells_to_slot() -> void:
	var added_new_shells = shotgun_shell.instantiate()
	added_new_shells.position = Vector3(0.001, -0.035, 0)
	added_new_shells.rotation_degrees = Vector3(0, 0, -82.59)
	for shells_positions in all_shell_positions:
		if shells_positions.get_child_count() < 1:
			shells_positions.add_child(added_new_shells)


func clear_all_slots() -> void:
	var added_new_shells = shotgun_shell.instantiate()
	for shells_positions in all_shell_positions:
		for bullet_shells in shells_positions.get_children():
			bullet_shells.queue_free()


func player_add_shell() -> void:
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells(shotgun_shell, Vector3(), Vector3())


func player_clear_shell() -> void:
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()
