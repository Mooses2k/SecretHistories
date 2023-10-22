tool
extends Node

export(String, 
"Webley", "Khyber_pass_martini", 
"Lee-metford_rifle", "Double-barrel_sawed_shotgun", 
"Double-barrel_shotgun", "Martini_henry_rifle") var current_weapon = "Webley" setget change_gun
#export var river_settings: bool setget set_river_settings
export (String, "Idle", "ADS", "Reload") var weapon_status = "Idle" setget set_weapon_state
export (bool) var reset_animation_tree setget reset_animation_tree
export (bool) var reset_character_arm_position setget reset_arm_position
export (Vector3) var adjust_weapon_dial setget adjust_weapon_position
export (Vector3) var adjust_weapon_rotation_dial setget adjust_weapon_rotation
export (Vector3) var weapon_default_position setget set_default_position
export (Vector3) var weapon_default_rotation setget set_default_rotation
export (bool) var save_all_changes_to_gun = true setget save_changes_to_gun

var spawned_weapon
var spawned_weapon_path : String
var is_doing_ads : bool = false

onready var inventory = $"../Inventory"
onready var main_hand_equipment_root = $"../MainHandEquipmentRoot"
onready var animation_tree = $"%AnimationTree"
onready var arm_position = $"%MainCharOnlyArmsGameRig".translation

#ResourceSaver.save("res://path_to_modified_scene.tscn", scene_instance)

func change_gun(value):
	current_weapon = value
	
	if not Engine.editor_hint:
		return
	if value == "Webley":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn").instance()
		spawned_weapon_path = "res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn"
		
	elif value == "Khyber_pass_martini":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn").instance()
		spawned_weapon_path = "res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn"
		
	elif value == "Lee-metford_rifle":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn").instance()
		spawned_weapon_path = "res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn"
		
	elif value == "Double-barrel_sawed_shotgun":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn").instance()
		spawned_weapon_path = "res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn"
		
	elif value == "Double-barrel_shotgun":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn").instance()
		spawned_weapon_path = "res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn"
		
	elif value == "Martini_henry_rifle":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/martini_henry_rifle/martini_henry_rifle.tscn").instance()
		spawned_weapon_path = "res://scenes/objects/pickable_items/equipment/ranged/martini_henry_rifle/martini_henry_rifle.tscn"
	
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.queue_free()
	$"%MainHandEquipmentRoot".add_child(spawned_weapon)
	spawned_weapon.transform = spawned_weapon.get_hold_transform()
	set_weapon_state(weapon_status)


func adjust_weapon_position(value):
	if not Engine.editor_hint:
		return
	adjust_weapon_dial = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.ads_parameters.ads_hold_position = adjust_weapon_dial
		if weapon_status == "ADS":
			available_weapons.hold_position.translation = available_weapons.ads_parameters.ads_hold_position
			available_weapons.transform = available_weapons.get_hold_transform()

#export var ads_parameters : Dictionary = {
#	"ads_hold_position" : Vector3(),
#	"ads_reset_position" : Vector3(),
#	"ads_rotation_position" : Vector3(),
#	"ads_reset_rotation" : Vector3(),
#	"ads_arm_position" : Vector3(),
#}

func adjust_weapon_rotation(value):
	if not Engine.editor_hint:
		return
	adjust_weapon_rotation_dial = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.ads_parameters.ads_rotation_position = adjust_weapon_rotation_dial
		if weapon_status == "ADS":
			available_weapons.hold_position.rotation = available_weapons.ads_parameters.ads_rotation_position
			available_weapons.transform = available_weapons.get_hold_transform()


func set_default_position(value):
	if not Engine.editor_hint:
		return
	weapon_default_position = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.ads_parameters.ads_reset_position = weapon_default_position
		if weapon_status == "Idle":
			available_weapons.hold_position.translation = available_weapons.ads_parameters.ads_reset_position
			available_weapons.transform = available_weapons.get_hold_transform()


func set_default_rotation(value):
	if not Engine.editor_hint:
		return
	weapon_default_rotation = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		available_weapons.ads_parameters.ads_reset_rotation = weapon_default_rotation
		if weapon_status == "Idle":
			available_weapons.hold_position.rotation = available_weapons.ads_parameters.ads_reset_rotation
			available_weapons.transform = available_weapons.get_hold_transform()


func save_changes_to_gun(value):
	if not Engine.editor_hint:
		return
	
	var new_gun_changes = GunItem.new()
	new_gun_changes.ads_parameters.ads_hold_position = adjust_weapon_dial
	new_gun_changes.ads_parameters.ads_rotation_position = adjust_weapon_rotation_dial
	new_gun_changes.ads_parameters.ads_reset_position = weapon_default_position
	new_gun_changes.ads_parameters.ads_reset_rotation = weapon_default_rotation
	
	save_all_changes_to_gun = true
	
	ResourceSaver.save(spawned_weapon_path, new_gun_changes)
	print("Saved weapon", new_gun_changes)

func reset_animation_tree(value):
	if not Engine.editor_hint:
		return
	reset_animation_tree = true
	$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
	$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
	$"%AnimationTree".set("parameters/Weapon_states/current", 4)
	$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 1)


func reset_arm_position(value):
	if not Engine.editor_hint:
		return
	reset_character_arm_position = true
	$"%MainCharOnlyArmsGameRig".translation = Vector3(0, -1.287, 0.063)


func set_weapon_state(value):
	if not Engine.editor_hint:
		return
	weapon_status = value
	for available_weapons in $"%MainHandEquipmentRoot".get_children():
		if available_weapons is GunItem:
			if value == "Idle":
				
				do_ads(false, available_weapons)
				if available_weapons.item_size == 0:
					$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
					$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					$"%AnimationTree".set("parameters/Weapon_states/current", 2)
				else:
					$"%AnimationTree".set("parameters/Hand_Transition/current", 0)
					$"%AnimationTree".set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					$"%AnimationTree".set("parameters/Weapon_states/current", 1)
				
			elif value == "ADS":
				do_ads(true, available_weapons)


#export var ads_parameters : Dictionary = {
#	"ads_hold_position" : Vector3(),
#	"ads_reset_position" : Vector3(),
#	"ads_rotation_position" : Vector3(),
#	"ads_reset_rotation" : Vector3(),
#	"ads_arm_position" : Vector3(),
#}

func do_ads(status, available_weapons):
	if not Engine.editor_hint:
		return
	if status == true:
		operation_tween(
		available_weapons.hold_position, "rotation", 
		available_weapons.hold_position.rotation, 
		available_weapons.ads_parameters.ads_hold_position , 0.1
	)
		operation_tween(
		available_weapons.hold_position, "rotation", 
		available_weapons.hold_position.rotation, 
		available_weapons.ads_parameters.ads_rotation_position, 0.1
	)
		if available_weapons.item_size == 0:
			operation_tween($"%AnimationTree",
			"parameters/SmallAds/blend_amount",
			$"%AnimationTree".get("parameters/SmallAds/blend_amount"), 1.0, 0.15)
			
			$"../FPSCamera".fov = lerp($"../FPSCamera".fov, 65, 0.1)
			adjust_arm(Vector3(-0.08, -1.518, 0.347))
		else:
			operation_tween($"%AnimationTree",
			"parameters/MediumAds/blend_amount",
			$"%AnimationTree".get("parameters/MediumAds/blend_amount"), 1.0, 0.15)
			
			$"../FPSCamera".fov = lerp($"../FPSCamera".fov, 60, 0.1)
			adjust_arm(Vector3(-0.03, -1.635, 0.218))
			is_doing_ads = true
	else:
		operation_tween(
		available_weapons.hold_position, "rotation", 
		available_weapons.hold_position.rotation, 
		available_weapons.ads_parameters.ads_reset_position, 0.1
	)
		operation_tween(
		available_weapons.hold_position, "rotation", 
		available_weapons.hold_position.rotation, 
		available_weapons.ads_parameters.ads_reset_rotation, 0.1
	)
		if available_weapons.item_size == 0:
			
			operation_tween(
			$"%AnimationTree",
			"parameters/SmallAds/blend_amount",
			$"%AnimationTree".get("parameters/SmallAds/blend_amount"),
			0.0, 
			0.15
			)
			adjust_arm(Vector3(0, -1.287, 0.063))
		
		else:
			operation_tween($"%AnimationTree",
			"parameters/MediumAds/blend_amount",
			$"%AnimationTree".get("parameters/MediumAds/blend_amount"), 0.0, 0.15)
			adjust_arm(Vector3(-0.086, -1.558, 0.294))
		
		$"../FPSCamera".fov = lerp($"../FPSCamera".fov, 70, 0.1)
		is_doing_ads = false


func operation_tween(object : Object, method, tweening_from, tweening_to, duration):
	var tweener = Tween.new() as Tween
	tweener.interpolate_property(object, method, tweening_from, tweening_to, duration, Tween.TRANS_LINEAR)
	add_child(tweener)
	tweener.start()


func adjust_arm(final_position):
	$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, final_position, 0.15)
	$"%ADSTween".start()
