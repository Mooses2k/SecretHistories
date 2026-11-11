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


## Realistic ejection mode: each unfired shell lands in the world as its
## loose pickup item (12-gauge_shotgun_shell.tscn, a TinyItem carrying the
## shotgun shell ammo data), sharing the casing impulse style.
func expell_live_rounds(count : int, world_parent : Node) -> void:
	var gun := owner as GunItem
	var character_forward := Vector3.ZERO
	if gun != null and gun.owner_character is Node3D:
		character_forward = (gun.owner_character as Node3D).global_transform.basis.z
	for i in mini(count, all_shell_positions.size()):
		var marker := all_shell_positions[i] as Marker3D
		if marker == null:
			continue
		var impulse_offset := impulse_position_1 if i == 0 else impulse_position_2
		spawn_casing(shotgun_shell, world_parent, marker.global_position, 0.0, character_forward * 3.0, impulse_offset)


func add_shells_to_slot() -> void:
	var added_new_shells := shotgun_shell.instantiate() as Node3D
	if added_new_shells == null:
		return
	for shells_positions in all_shell_positions:
		var slot := shells_positions as Marker3D
		if slot == null or slot.get_child_count() > 0:
			continue
		slot.add_child(added_new_shells)
		added_new_shells.position = Vector3(0.001, -0.035, 0)
		added_new_shells.rotation_degrees = Vector3(0, 0, -82.59)
		_pin_insertion_visual(added_new_shells)
		return
	added_new_shells.free()


func clear_all_slots() -> void:
	for shells_positions in all_shell_positions:
		var slot := shells_positions as Marker3D
		if slot == null:
			continue
		for added_shell in slot.get_children():
			added_shell.queue_free()


func player_add_shell() -> void:
	var holder := _shell_holder()
	if holder != null and holder.has_method("spawn_hand_shell"):
		var shell : Node = holder.call("spawn_hand_shell", shotgun_shell, Vector3(), Vector3())
		_pin_insertion_visual(shell)


func player_clear_shell() -> void:
	var holder := _shell_holder()
	if holder != null and holder.has_method("clear_hand_shells"):
		holder.call("clear_hand_shells")
