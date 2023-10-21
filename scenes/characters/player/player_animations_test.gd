tool
extends Node

export(String, 
"Webley", "Khyber_pass_martini", 
"Lee-metford_rifle", "Double-barrel_sawed_shotgun", 
"Double-barrel_shotgun", "Martini_henry_rifle") var current_weapon = "Webley" setget change_gun
#export var river_settings: bool setget set_river_settings
export (String, "Idle", "ADS", "Reload") var weapon_status = "Idle" setget set_weapon_state
export var _cam_path : NodePath
var spawned_weapon

onready var inventory = $"../Inventory"
onready var main_hand_equipment_root = $"../MainHandEquipmentRoot"
onready var animation_tree = $"%AnimationTree"


onready var arm_position = $"%MainCharOnlyArmsGameRig".translation
onready var _camera : ShakeCamera = get_node(_cam_path) as Camera

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
	set_weapon_state(weapon_status)

func set_weapon_state(value):
	weapon_status = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		if available_weapons is EquipmentItem:
			if value == "Idle":
				if available_weapons.item_size == 0:
					$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
					$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					$"%AnimationTree".set("parameters/Weapon_states/current", 2)
				else:
					$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
					$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					$"%AnimationTree".set("parameters/Weapon_states/current", 1)
			elif value == "ADS":
				operation_tween(
				available_weapons.hold_position, "rotation", 
				available_weapons.hold_position.rotation, 
				available_weapons.ads_hold_rotation, 0.1
			)
				if available_weapons.item_size == 0:
					operation_tween($"%AnimationTree", 
					"parameters/SmallAds/blend_amount", 
					$"%AnimationTree".get("parameters/SmallAds/blend_amount"), 
					1.0, 
					0.15
					)
					$"../FPSCamera".fov = lerp($"../FPSCamera".fov, 65, 0.1)
					adjust_arm(Vector3(-0.086, -1.558, 0.294))
				else:
					operation_tween($"%AnimationTree",
					"parameters/MediumAds/blend_amount",
					$"%AnimationTree".get("parameters/MediumAds/blend_amount"), 
					1.0, 
					0.15
					)
					$"../FPSCamera".fov = lerp($"../FPSCamera".fov, 60, 0.1)
					adjust_arm(Vector3(-0.03, -1.635, 0.218))


func operation_tween(object : Object, method, tweening_from, tweening_to, duration):
	var tweener = Tween.new() as Tween
	tweener.interpolate_property(object, method, tweening_from, tweening_to, duration, Tween.TRANS_LINEAR)
	add_child(tweener)
	tweener.start()


func adjust_arm(final_position):
	$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, final_position, 0.15)
	$"%ADSTween".start()
