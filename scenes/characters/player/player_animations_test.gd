tool
extends Node

export(String, 
"Webley", "Khyber_pass_martini", 
"Lee-metford_rifle", "Double-barrel_sawed_shotgun", 
"Double-barrel_shotgun", "Martini_henry_rifle") var current_weapon = "Webley" setget change_gun
#export var river_settings: bool setget set_river_settings
export (String, "Idle", "ADS", "Reload") var weapon_status = "Idle" setget set_weapon_state

var spawned_weapon

onready var inventory = $"../Inventory"
onready var main_hand_equipment_root = $"../MainHandEquipmentRoot"
onready var animation_tree = $"%AnimationTree"


func change_gun(value):
	current_weapon = value
	
	if value == "Webley":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn").instance()
		
	elif value == "Khyber_pass_martini":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn").instance()
		
	elif value == "Lee-metford_rifle":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn").instance()
		
	elif value == "Double-barrel_sawed_shotgun":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn").instance()
		
	elif value == "Double-barrel_shotgun":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn").instance()
		
	elif value == "Martini_henry_rifle":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/martini_henry_rifle/martini_henry_rifle.tscn").instance()
		
	
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.queue_free()
	$"%MainHandEquipmentRoot".add_child(spawned_weapon)
	spawned_weapon.transform = spawned_weapon.get_hold_transform()


func set_weapon_state(value):
	weapon_status = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		if available_weapons is EquipmentItem:
			print("It is currently gun")
			if available_weapons.item_size == 0:
				print("Current gun is small")
#				animation_tree.set("parameters/Hand_Transition/current", 0)
#				animation_tree.set("parameters/Weapon_states/current", 2)
			else:
				print("Current gun is big")
				animation_tree.set("parameters/Hand_Transition/current", 0)
				animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
				animation_tree.set("parameters/Weapon_states/current", 1)
