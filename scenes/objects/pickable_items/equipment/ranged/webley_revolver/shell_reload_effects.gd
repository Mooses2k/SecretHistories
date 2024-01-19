extends Node

@export var impulse_position : Vector3 = Vector3(0, 0.2, 0.1)

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


func expell_shells():
	all_bullet_shells.clear()
	var first_shell = dropped_bullet_shell.instantiate() as RigidBody3D
	var second_shell = dropped_bullet_shell.instantiate() as RigidBody3D
	var third_shell = dropped_bullet_shell.instantiate() as RigidBody3D
	var fourth_shell = dropped_bullet_shell.instantiate() as RigidBody3D
	var fifth_shell = dropped_bullet_shell.instantiate() as RigidBody3D
	var sixth_shell = dropped_bullet_shell.instantiate() as RigidBody3D
	
	all_bullet_shells.append(first_shell)
	all_bullet_shells.append(second_shell)
	all_bullet_shells.append(third_shell)
	all_bullet_shells.append(fourth_shell)
	all_bullet_shells.append(fifth_shell)
	all_bullet_shells.append(sixth_shell)
	
	
	var world_scene
	if is_instance_valid(GameManager.game):
		world_scene = GameManager.game
	else:
		world_scene = owner.owner_character.owner as Node3D

	first_shell.position = bullet_position_1.global_position
	second_shell.position = bullet_position_2.global_position
	third_shell.position = bullet_position_3.global_position
	fourth_shell.position = bullet_position_4.global_position
	fifth_shell.position = bullet_position_5.global_position
	sixth_shell.position = bullet_position_6.global_position
	
	first_shell.position.y += 0.05
	second_shell.position.y += 0.05
	third_shell.position.y += 0.05
	fourth_shell.position.y += 0.05
	fifth_shell.position.y += 0.05
	sixth_shell.position.y += 0.05
	
	for bullet_shells in all_bullet_shells:
		world_scene.add_child(bullet_shells)
	
	for bullet_shells in all_bullet_shells:
		bullet_shells.apply_impulse(owner.owner_character.global_transform.basis.z * randf_range(0.1, 0.5), Vector3(randf_range(0, 0.6), randf_range(0, 0.8), randf_range(0, 0.5)))


func player_add_shell():
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells(bullet_shells, Vector3(0.014, -0.001, -0.003), Vector3(1.372, 6.429, 0.474))


func player_clear_shell():
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()


func add_shells_to_slot():
	var added_new_shells = bullet_shells.instantiate()
	added_new_shells.position = Vector3(0.006, -0.009, 0)
	added_new_shells.rotation_degrees = Vector3(0, 0, -68.136)
	for shells_positions in all_shell_positions:
		if shells_positions.get_child_count() < 1:
			shells_positions.add_child(added_new_shells)


func clear_all_slots():
	var added_new_shells = bullet_shells.instantiate()
	for shells_positions in all_shell_positions:
		for bullet_shells in shells_positions.get_children():
			bullet_shells.queue_free()
