@tool
extends Node

@export_enum("None",
"Webley", "Khyber_pass_martini", 
"Lee-metford_rifle", "Double-barrel_sawed_shotgun", 
"Double-barrel_shotgun", "Martini_henry_rifle", "Comet_Shard") var current_weapon = "None": set = change_gun

@export_enum("IDLE", "ADS", "RELOAD") var weapon_state = "IDLE": set = set_weapon_state

@export var reset_to_idle_pos : bool: set = reset_animation_tree
@export var ads_weapon_position: Vector3: set = adjust_weapon_position
@export var ads_weapon_rotation : Vector3: set = adjust_weapon_rotation

var spawned_weapon

@onready var inventory = $"../Inventory"
@onready var main_hand_equipment_root = $"../MainHandEquipmentRoot"
@onready var animation_tree = %AnimationTree
@onready var arm_position = %MainCharOnlyArmsGameRig.position
@onready var gun_cam = $"../FPSCamera/SubViewportContainer/SubViewport/GunCam" as Camera3D


func change_gun(value):
	current_weapon = value

	if not Engine.is_editor_hint():
		return
		
	if value == "None":
		reset_animation_tree(true)
		get_equipped_weapon().queue_free()
		
	if value == "Webley":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn").instantiate()
	
	elif value == "Khyber_pass_martini":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn").instantiate()
	
	elif value == "Lee-metford_rifle":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/lee-metford_rifle/lee-metford_rifle.tscn").instantiate()
	
	elif value == "Double-barrel_sawed_shotgun":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn").instantiate()
	
	elif value == "Double-barrel_shotgun":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn").instantiate()
	
	elif value == "Martini_henry_rifle":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/ranged/martini_henry_rifle/martini_henry_rifle.tscn").instantiate()
		
	elif value == "Comet_Shard":
		spawned_weapon = preload("res://scenes/objects/pickable_items/equipment/strange_devices/comet_shard/comet_shard.tscn").instantiate()
		
	if get_equipped_weapon():
		get_equipped_weapon().queue_free()
	%MainHandEquipmentRoot.add_child(spawned_weapon)
	set_weapon_state("IDLE")
	ads_weapon_position = spawned_weapon.ads_hold_position
	ads_weapon_rotation = spawned_weapon.ads_hold_rotation
	spawned_weapon.transform = spawned_weapon.get_hold_transform()


func adjust_weapon_position(value):
	if not Engine.is_editor_hint():
		return
	ads_weapon_position = value
	if not is_node_ready():
		await ready
	if get_equipped_weapon():
		get_equipped_weapon().ads_hold_position = ads_weapon_position
		get_equipped_weapon().hold_position.position = get_equipped_weapon().ads_hold_position
		get_equipped_weapon().transform = get_equipped_weapon().get_hold_transform()


func adjust_weapon_rotation(value):
	if not Engine.is_editor_hint():
		return
	ads_weapon_rotation = value
	if not is_node_ready():
		await ready
	if get_equipped_weapon():
		get_equipped_weapon().ads_hold_rotation = ads_weapon_rotation
		get_equipped_weapon().hold_position.rotation_degrees = get_equipped_weapon().ads_hold_rotation
		get_equipped_weapon().transform = get_equipped_weapon().get_hold_transform()


func reset_animation_tree(value):
	if not Engine.is_editor_hint():
		return
	reset_to_idle_pos = true
	if not is_node_ready():
		await ready
	%AnimationTree.set("parameters/Hand_Transition/current", 0)
	%AnimationTree.set("parameters/Weapon_states/current", 4)
	%AnimationTree.set("parameters/OffHand_MainHand_Blend/blend_amount", 1)
	%AnimationTree.set("parameters/OffHand_Weapon_States/current", 2)


func set_weapon_state(value):
	notify_property_list_changed()
	if not Engine.is_editor_hint():
		return
	weapon_state = value
	if value == "IDLE":
		do_ads(false)
		do_idle()
	
	elif value == "ADS":
		do_ads(true)
	
	elif value == "RELOAD":
		get_equipped_weapon().animation_player.play("reload")
		player_reload()
		await get_tree().create_timer(get_equipped_weapon().animation_player.get_animation("reload").length - 0.3).timeout
#		do_idle()


func player_reload():
	adjust_arm(Vector3(0.008, -1.364, 0.175))
	
	%AnimationTree.set("parameters/" + str(get_equipped_weapon().item_name) + "/active", true)


func do_idle():
	if get_equipped_weapon():
		if get_equipped_weapon() is GunItem:
			if get_equipped_weapon().item_size == 0:
				%AnimationTree.set("parameters/Hand_Transition/current", 0)
				%AnimationTree.set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
				%AnimationTree.set("parameters/Weapon_states/current", 2)
				adjust_arm(Vector3(0, -1.287, 0.063))
			else:
				if get_equipped_weapon().item_name == "Double-barrel shotgun":
					%AnimationTree.set("parameters/Hand_Transition/current", 0)
					%AnimationTree.set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					%AnimationTree.set("parameters/Weapon_states/current", 5)
				else:
					%AnimationTree.set("parameters/Hand_Transition/current", 0)
					%AnimationTree.set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
					%AnimationTree.set("parameters/Weapon_states/current", 1)
				adjust_arm(Vector3(0.008, -1.364, 0.175))
			
		else:
				%AnimationTree.set("parameters/Hand_Transition/current", 0)
				%AnimationTree.set("parameters/OffHand_MainHand_Blend/blend_amount", 1)
				
				%AnimationTree.set("parameters/Weapon_states/current", 0)
				%AnimationTree.set("parameters/Hold_Animation/current", 0)
				
				%AnimationTree.set("parameters/OffHand_Weapon_States/current", 0)
				%AnimationTree.set("parameters/Offhand_Hold_Animation/current", 0)

#		elif get_equipped_weapon().item_size == 3:
#				%AnimationTree.set("parameters/Hand_Transition/current", 0)
#				%AnimationTree.set("parameters/OffHand_MainHand_Blend/blend_amount", 1)
#
#				%AnimationTree.set("parameters/Weapon_states/current", 0)
#				%AnimationTree.set("parameters/Hold_Animation/current", 0)
#
#				%AnimationTree.set("parameters/OffHand_Weapon_States/current", 0)
#				%AnimationTree.set("parameters/Offhand_Hold_Animation/current", 0)

func do_ads(value):
	if not Engine.is_editor_hint():
		return
	if get_equipped_weapon():
		if get_equipped_weapon() is GunItem:
			if value == true:
				get_equipped_weapon().hold_position.position = get_equipped_weapon().ads_hold_position
				get_equipped_weapon().hold_position.rotation_degrees = get_equipped_weapon().ads_hold_rotation
				get_equipped_weapon().transform = get_equipped_weapon().get_hold_transform()

				if get_equipped_weapon().item_size == 0:
					operation_tween(%AnimationTree,
					"parameters/SmallAds/blend_amount",
					%AnimationTree.get("parameters/SmallAds/blend_amount"), 1.0, 0.1)

					adjust_arm(Vector3(-0.086, -1.558, 0.294))

				else:
					if get_equipped_weapon().item_name == "Double-barrel shotgun":
						operation_tween(%AnimationTree,
						"parameters/ShotgunAds/blend_amount",
						%AnimationTree.get("parameters/ShotgunAds/blend_amount"), 1.0, 0.05)
					else:
						operation_tween(%AnimationTree,
						"parameters/MediumAds/blend_amount",
						%AnimationTree.get("parameters/MediumAds/blend_amount"), 1.0, 0.05)
#						gun_cam.transform = lerp(gun_cam.transform, Vector3(0, 1.538, 0), 0.1)
						adjust_arm(Vector3(-0.054, -1.571, 0.257))
					adjust_arm(Vector3(-0.054, -1.571, 0.257))
			else:
				get_equipped_weapon().hold_position.position = get_equipped_weapon().ads_reset_position
				get_equipped_weapon().hold_position.rotation_degrees = get_equipped_weapon().ads_reset_rotation
				get_equipped_weapon().transform = get_equipped_weapon().get_hold_transform()

				if get_equipped_weapon().item_size == 0:
					operation_tween(
					%AnimationTree,
					"parameters/SmallAds/blend_amount",
					%AnimationTree.get("parameters/SmallAds/blend_amount"), 0.0, 0.1)
					adjust_arm(Vector3(0, -1.287, 0.063))
				else:
					if get_equipped_weapon().item_name == "Double-barrel shotgun":
						operation_tween(%AnimationTree,
						"parameters/ShotgunAds/blend_amount",
						%AnimationTree.get("parameters/ShotgunAds/blend_amount"), 0.0, 0.1)
					else:
						operation_tween(%AnimationTree,
						"parameters/MediumAds/blend_amount",
						%AnimationTree.get("parameters/MediumAds/blend_amount"), 0.0, 0.1)
						adjust_arm(Vector3(0.008, -1.364, 0.175))
				$"../FPSCamera".fov = lerp($"../FPSCamera".fov, 70, 0.1)


func get_equipped_weapon() -> EquipmentItem:
	var equipped_weapon
	for available_weapon in %MainHandEquipmentRoot.get_children():
		if available_weapon is EquipmentItem:
			equipped_weapon = available_weapon
	return equipped_weapon


func operation_tween(object : Object, method, tweening_from, tweening_to, duration):
	var tweener = get_tree().create_tween()
	tweener.tween_property(object, method, tweening_to, duration)\
	.from(tweening_from)\
	.set_trans(Tween.TRANS_LINEAR)


# TODO: haven't tested since changing tween
func adjust_arm(final_position):
	var ads_tween = get_tree().create_tween()
	ads_tween.tween_property(%MainCharOnlyArmsGameRig, "position", final_position, 0.01) 
	ads_tween.start()
