extends Node

export var impulse_position : Vector3 = Vector3(0, 0.2, 0.1)
export var impulse_value : Vector3 = Vector3(0, 0.3, 0.2)

var dropped_bullet_shell = preload("res://scenes/objects/pickable_items/tiny/ammo/webley/webley_casing.tscn")
var bullet_shells = preload("res://scenes/objects/pickable_items/tiny/ammo/webley/webley_round.tscn")

var all_shell_positions : Array = []
var all_bullet_shells : Array = []


onready var bullet_position_1 = $"%BulletPosition"
onready var bullet_position_2 = $"%BulletPosition2"
onready var bullet_position_3 = $"%BulletPosition3"
onready var bullet_position_4 = $"%BulletPosition4"
onready var bullet_position_5 = $"%BulletPosition5"
onready var bullet_position_6 = $"%BulletPosition6"

func _ready():
	all_shell_positions.append(bullet_position_1)
	all_shell_positions.append(bullet_position_2)
	all_shell_positions.append(bullet_position_3)
	all_shell_positions.append(bullet_position_4)
	all_shell_positions.append(bullet_position_5)
	all_shell_positions.append(bullet_position_6)


func expell_shells():
	all_bullet_shells.clear()
	var first_shell = dropped_bullet_shell.instance() as RigidBody
	var second_shell = dropped_bullet_shell.instance() as RigidBody
	var third_shell = dropped_bullet_shell.instance() as RigidBody
	var fourth_shell = dropped_bullet_shell.instance() as RigidBody
	var fifth_shell = dropped_bullet_shell.instance() as RigidBody
	var sixth_shell = dropped_bullet_shell.instance() as RigidBody
	
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
		world_scene = owner.owner_character.owner as Spatial

	first_shell.translation = bullet_position_1.global_translation
	second_shell.translation = bullet_position_2.global_translation
	third_shell.translation = bullet_position_3.global_translation
	fourth_shell.translation = bullet_position_4.global_translation
	fifth_shell.translation = bullet_position_5.global_translation
	sixth_shell.translation = bullet_position_6.global_translation
	
	for bullet_shells in all_bullet_shells:
		world_scene.add_child(bullet_shells)
	
	for bullet_shells in all_bullet_shells:
		bullet_shells.apply_impulse(impulse_position, impulse_value)


func player_add_shell():
	owner.owner_character.player_gun_reload_shells.spawn_bullet_shells(bullet_shells, Vector3(0.014, -0.001, -0.003), Vector3(1.372, 6.429, 0.474))


func player_clear_shell():
	owner.owner_character.player_gun_reload_shells.clear_shotgun_shells()


func add_shells_to_slot():
	var added_new_shells = bullet_shells.instance()
	added_new_shells.translation = Vector3(0.006, -0.009, 0)
	added_new_shells.rotation_degrees = Vector3(0, 0, -68.136)
	for shells_positions in all_shell_positions:
		if shells_positions.get_child_count() < 1:
			shells_positions.add_child(added_new_shells)


func clear_all_slots():
	var added_new_shells = bullet_shells.instance()
	for shells_positions in all_shell_positions:
		for bullet_shells in shells_positions.get_children():
			bullet_shells.queue_free()
