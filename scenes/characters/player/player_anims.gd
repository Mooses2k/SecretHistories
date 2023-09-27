extends Node


# Different hold states depending on the item equipped and the hand equipped on 
enum HoldStates {
	SMALL_GUN_ITEM,
	SMALL_GUN_ITEM_LEFT,
	LARGE_GUN_ITEM,
	MELEE_ITEM,
	ITEM_HORIZONTAL,
	ITEM_VERTICAL,
	ITEM_HORIZONTAL_LEFT,
	ITEM_VERTICAL_LEFT,
	SMALL_GUN_ADS,
	LARGE_GUNS_ADS,
	UNEQUIPPED
}



onready var inventory = $"../Inventory"
onready var arm_position = $"%MainCharOnlyArmsGameRig".translation
onready var _camera : ShakeCamera = get_node(_cam_path)
onready var animation_tree = $"%AnimationTree"

var offhand_active = false
var mainhand_active = false
var is_on_ads = false

export var _cam_path : NodePath

func _ready():
	print($"%MainCharOnlyArmsGameRig".translation)
	pass


func _process(delta):
	if not $"..".is_reloading:   # TODO: messy
		pass


func _physics_process(delta):
	check_if_ads()


func check_player_animation():
	
	### Off-hand item
	if inventory.current_offhand_equipment is GunItem:
		animation_tree.set("parameters/Hand_Transition/current", 0)
		animation_tree.set("parameters/OffHand_Weapon_States/current", 1)
		
	elif inventory.current_offhand_equipment is EmptyHand:
		animation_tree.set("parameters/OffHand_Weapon_States/current", 2)
		
	elif inventory.current_offhand_equipment is EquipmentItem:
	
		if inventory.current_offhand_equipment.horizontal_holding == true:
			inventory.current_offhand_equipment.hold_position.rotation_degrees.z = -90
			animation_tree.set("parameters/Hand_Transition/current", 0)
			animation_tree.set("parameters/OffHand_Weapon_States/current", 0)
			animation_tree.set("parameters/Offhand_Hold_Animation/current", 1)
		else:
			animation_tree.set("parameters/Hand_Transition/current", 0)
			animation_tree.set("parameters/OffHand_Weapon_States/current", 0)
			animation_tree.set("parameters/Offhand_Hold_Animation/current", 0)
	
	else:
		animation_tree.set("parameters/OffHand_Weapon_States/current", 2)
	
	### Main-hand item
	if inventory.current_mainhand_equipment is GunItem:
#		
		if inventory.current_mainhand_equipment.item_size == 0:
			animation_tree.set("parameters/Hand_Transition/current", 0)
			animation_tree.set("parameters/Weapon_states/current", 2)
		else:
			animation_tree.set("parameters/Hand_Transition/current", 0)
			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount", 0)
			animation_tree.set("parameters/Weapon_states/current", 1)
			unequip_offhand()
	
	elif inventory.current_mainhand_equipment is EmptyHand:
		animation_tree.set("parameters/Hand_Transition/current", 0)
		animation_tree.set("parameters/Weapon_states/current", 4)


	elif inventory.current_mainhand_equipment is EquipmentItem:
		if inventory.current_mainhand_equipment.horizontal_holding == true:
			inventory.current_mainhand_equipment.hold_position.rotation_degrees.z = 90
			animation_tree.set("parameters/Hand_Transition/current", 0)
			animation_tree.set("parameters/Weapon_states/current", 0)
			animation_tree.set("parameters/Hold_Animation/current", 1)
		else:
			animation_tree.set("parameters/Hand_Transition/current", 0)
			animation_tree.set("parameters/Weapon_states/current", 0)
			animation_tree.set("parameters/Hold_Animation/current", 0)
	
	elif inventory.current_mainhand_equipment == null:
		animation_tree.set("parameters/Hand_Transition/current", 0)
		animation_tree.set("parameters/Weapon_states/current", 4)

	if inventory.current_mainhand_equipment and inventory.current_mainhand_equipment.item_size == 1:
		adjust_arm(Vector3(0.015, -1.474, 0.124))
	elif inventory.current_mainhand_equipment and inventory.current_mainhand_equipment.item_size == 0:
		adjust_arm(Vector3(0, -1.287, 0.063))
	elif inventory.current_offhand_equipment and inventory.current_offhand_equipment.item_size == 0:
		adjust_arm(Vector3(0, -1.287, 0.063))


func unequip_offhand():
	inventory.unequip_offhand_item()


func check_if_ads():
	# This checks if the ADS mouse button is pressed then lerps the weapon to that position and when the button is released the weapon goes to its normal position
	if GameSettings.ads_hold_enabled:
		if Input.is_action_pressed("playerhand|main_use_secondary") and owner.do_sprint == false:
			
			if inventory.current_mainhand_slot != null:
				if inventory.current_mainhand_equipment is GunItem:
					ads()
		
		else:
			if ((Input.is_action_just_released("playerhand|main_use_secondary") or owner.do_sprint == true) and (inventory.current_mainhand_equipment is GunItem)):
				end_ads()
	
	else:
		if Input.is_action_just_pressed("playerhand|main_use_secondary") or owner.do_sprint == true:
			
			if not is_on_ads and owner.do_sprint == false:
				if inventory.current_mainhand_slot != null:
					if inventory.current_mainhand_equipment is GunItem:
						ads()
			
			else:
				if (inventory.current_mainhand_equipment is GunItem or (owner.do_sprint == true and inventory.current_mainhand_equipment is GunItem)):
					end_ads()


func ads():
	print(animation_tree.get("parameters/SmallAds/blend_amount"))
	if inventory.current_mainhand_equipment.item_size == 0:
		operation_tween(animation_tree, "parameters/SmallAds/blend_amount", animation_tree.get("parameters/SmallAds/blend_amount"), 1.0, 0.15)
		adjust_arm(Vector3(0, -1.581, 0.063))
	else:
		operation_tween(animation_tree, "parameters/MediumAds/blend_amount", animation_tree.get("parameters/MediumAds/blend_amount"), 1.0, 0.15)
		adjust_arm(Vector3(0, -1.648, 0.063))
	print("is doing ADS")


func end_ads():
	if inventory.current_mainhand_equipment.item_size == 0:
		operation_tween(animation_tree, "parameters/SmallAds/blend_amount", animation_tree.get("parameters/SmallAds/blend_amount"), 0.0, 0.15)
		adjust_arm(Vector3(0, -1.287, 0.063))
	else:
		operation_tween(animation_tree, "parameters/MediumAds/blend_amount", animation_tree.get("parameters/MediumAds/blend_amount"), 0.0, 0.15)
		adjust_arm(Vector3(0, -1.474, 0.063))
	print("Has ended ADS")


func operation_tween(object : Object, method, tweening_from, tweening_to, duration):
	var tweener = Tween.new() as Tween
	tweener.interpolate_property(object, method, tweening_from, tweening_to, duration, Tween.TRANS_LINEAR)
	add_child(tweener)
	tweener.start()


func adjust_arm(final_position):
	$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, final_position, 0.15)
	$"%ADSTween".start()


func _on_Inventory_inventory_changed():
	yield(get_tree().create_timer(0.5), "timeout")
	check_player_animation()


func switch_mainhand_item_animation():
	animation_tree.set("parameters/Hand_Transition/current",0)
	animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
	animation_tree.set("parameters/Weapon_states/current",4)
	
	yield(get_tree().create_timer(0.5), "timeout")
	check_player_animation()


func _on_Inventory_unequip_mainhand():
	animation_tree.set("parameters/Hand_Transition/current", 0)
	animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount", 1)
	animation_tree.set("parameters/Weapon_states/current", 4)


func _on_Inventory_unequip_offhand():
	animation_tree.set("parameters/OffHand_Weapon_States/current", 2)
