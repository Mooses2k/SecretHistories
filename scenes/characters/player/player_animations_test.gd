tool
extends Node

export(String, 
"Webley", "Khyber_pass_martini", 
"Lee-metford_rifle", "Double-barrel_sawed_shotgun", 
"Double-barrel_shotgun", "Martini_henry_rifle") var current_weapon = "Webley" setget change_gun
export (String, "IDLE", "ADS", "RELOAD") var weapon_state = "IDLE" setget set_weapon_state

export (bool) var reset_to_idle_pos setget reset_animation_tree
export (Vector3) var ads_weapon_position setget adjust_weapon_position
export (Vector3) var ads_weapon_rotation setget adjust_weapon_rotation

var spawned_weapon

onready var inventory = $"../Inventory"
onready var main_hand_equipment_root = $"../MainHandEquipmentRoot"
onready var animation_tree = $"%AnimationTree"
onready var arm_position = $"%MainCharOnlyArmsGameRig".translation


func _ready():
	pass


func change_gun(value):
	current_weapon = value

	if not Engine.editor_hint:
		return
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
	set_weapon_state("IDLE")
	ads_weapon_position = spawned_weapon.ads_hold_position
	ads_weapon_rotation = spawned_weapon.ads_hold_rotation
	spawned_weapon.transform = spawned_weapon.get_hold_transform()



func adjust_weapon_position(value):
	if not Engine.editor_hint:
		return
	ads_weapon_position = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.ads_hold_position = ads_weapon_position
		available_weapons.hold_position.translation = available_weapons.ads_hold_position
		available_weapons.transform = available_weapons.get_hold_transform()


func adjust_weapon_rotation(value):
	if not Engine.editor_hint:
		return
	ads_weapon_rotation = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.ads_hold_rotation = ads_weapon_rotation
		available_weapons.hold_position.rotation_degrees = available_weapons.ads_hold_rotation
		available_weapons.transform = available_weapons.get_hold_transform()


func reset_animation_tree(value):
	if not Engine.editor_hint:
		return
	reset_to_idle_pos = true
	$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
	$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
	$"%AnimationTree".set("parameters/Weapon_states/current", 4)
	$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 1)


func set_weapon_state(value):
	property_list_changed_notify()
	if not Engine.editor_hint:
		return
	weapon_state = value
	if value == "IDLE":
		do_ads(false)
		for available_weapons in $"%MainHandEquipmentRoot".get_children():
			if available_weapons is GunItem:
				if available_weapons.item_size == 0:
					$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
					$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					$"%AnimationTree".set("parameters/Weapon_states/current", 2)
					adjust_arm(Vector3(0, -1.287, 0.063))
				else:
					$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
					$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					$"%AnimationTree".set("parameters/Weapon_states/current", 1)
					adjust_arm(Vector3(0.096, -1.391, 0.091))
	else:
		do_ads(true)


func do_ads(value):
	if not Engine.editor_hint:
		return
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		if available_weapons is GunItem:
			if value == true:
				available_weapons.hold_position.translation = available_weapons.ads_hold_position
				available_weapons.hold_position.rotation_degrees = available_weapons.ads_hold_rotation
				available_weapons.transform = available_weapons.get_hold_transform()

				if available_weapons.item_size == 0:
					operation_tween($"%AnimationTree",
					"parameters/SmallAds/blend_amount",
					$"%AnimationTree".get("parameters/SmallAds/blend_amount"), 1.0, 0.1)

					adjust_arm(Vector3(-0.086, -1.558, 0.294))

				else:
					operation_tween($"%AnimationTree",
					"parameters/MediumAds/blend_amount",
					$"%AnimationTree".get("parameters/MediumAds/blend_amount"), 1.0, 0.1)
					adjust_arm(Vector3(-0.054, -1.571, 0.253))
			else:
				available_weapons.hold_position.translation = available_weapons.ads_reset_position
				available_weapons.hold_position.rotation_degrees = available_weapons.ads_reset_rotation
				available_weapons.transform = available_weapons.get_hold_transform()

				if available_weapons.item_size == 0:

					operation_tween(
					$"%AnimationTree",
					"parameters/SmallAds/blend_amount",
					$"%AnimationTree".get("parameters/SmallAds/blend_amount"), 0.0, 0.1)
					adjust_arm(Vector3(0, -1.287, 0.063))

				else:
					operation_tween($"%AnimationTree",
					"parameters/MediumAds/blend_amount",
					$"%AnimationTree".get("parameters/MediumAds/blend_amount"), 0.0, 0.1)
					adjust_arm(Vector3(0.008, -1.364, 0.175))
				$"../FPSCamera".fov = lerp($"../FPSCamera".fov, 70, 0.1)


func operation_tween(object : Object, method, tweening_from, tweening_to, duration):
	var tweener = Tween.new() as Tween
	tweener.interpolate_property(object, method, tweening_from, tweening_to, duration, Tween.TRANS_LINEAR)
	add_child(tweener)
	tweener.start()


func adjust_arm(final_position):
	$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, final_position, 0.15)
	$"%ADSTween".start()
