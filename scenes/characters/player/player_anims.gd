extends Node


# Different hold states depending on the item equipped and the hand equipped on 
enum hold_states {
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

export var _cam_path : NodePath
onready var inventory = $"../Inventory"
onready var arm_position = $"%MainCharOnlyArmsGameRig".translation
onready var _camera : ShakeCamera = get_node(_cam_path)
onready var animation_tree = $"%AnimationTree"


var main_hand_object 
var off_hand_object 

var offhand_active = false
var mainhand_active = false

func _ready():
	pass



func _process(delta):
	if not $"..".is_reloading:
		pass



func _physics_process(delta):
	ads()


func check_player_animation():
	
	#___________offhand_object_______________#
	if inventory.current_offhand_equipment is GunItem:
		adjust_arm()
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_Weapon_States/current",1)
		


	elif inventory.current_offhand_equipment is EmptyHand:
		animation_tree.set("parameters/OffHand_Weapon_States/current",2)
		

	elif inventory.current_offhand_equipment is EquipmentItem:
		adjust_arm()
		if inventory.current_offhand_equipment.horizontal_holding == true:
			inventory.current_offhand_equipment.hold_position.rotation_degrees.z = -90
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_Weapon_States/current",0)
			animation_tree.set("parameters/Offhand_Hold_Animation/current",1)
		else:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_Weapon_States/current",0)
			animation_tree.set("parameters/Offhand_Hold_Animation/current",0)
#

	else:
		animation_tree.set("parameters/OffHand_Weapon_States/current",2)

	#___________mainhand_object_______________#

	if inventory.current_mainhand_equipment is GunItem:
#		
		if inventory.current_mainhand_equipment.item_size == 0:
			adjust_arm()
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/Weapon_states/current",2)
		else:
			$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, 0.124), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
			$"%ADSTween".start()
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
			animation_tree.set("parameters/Weapon_states/current",1)
			unequip_offhand()


	elif inventory.current_mainhand_equipment is EmptyHand:
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/Weapon_states/current",4)

	elif inventory.current_mainhand_equipment is EquipmentItem:
		adjust_arm()
		if inventory.current_mainhand_equipment.horizontal_holding == true:
			inventory.current_mainhand_equipment.hold_position.rotation_degrees.z = 90
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/Weapon_states/current",0)
			animation_tree.set("parameters/Hold_Animation/current",1)
		else:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/Weapon_states/current",0)
			animation_tree.set("parameters/Hold_Animation/current",0)


	elif inventory.current_mainhand_equipment == null:
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/Weapon_states/current",4)


func unequip_offhand():
	inventory.unequip_offhand_item()

func adjust_arm():
	$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.115), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
	$"%ADSTween".start()


func ads():
	var main_hand_item = get_parent().inventory.current_mainhand_slot
	
	# This checks if the ADS mouse button is pressed then lerps the weapon to that position and when the button is released the weapon goes to its normal position
	if Input.is_action_pressed("main_use_secondary") and owner.do_sprint == false:
	
		if get_parent().inventory.current_mainhand_slot != null:
			
			if get_parent().inventory.hotbar[main_hand_item] is GunItem:
				$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(-0.097, -1.444, 0.108), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
				$"%ADSTween".start()
				if get_parent().inventory.hotbar[main_hand_item].item_size == GlobalConsts.ItemSize.SIZE_SMALL:
					if _camera.state == _camera.CameraState.STATE_NORMAL:   # Allows for binoc etc zoom
						_camera.fov  = lerp(_camera.fov, 65, 0.5)
				else:
					if _camera.state == _camera.CameraState.STATE_NORMAL:   # Allows for binoc etc zoom
						_camera.fov  = lerp(_camera.fov, 60, 0.5)

	else:
		if Input.is_action_just_released("main_use_secondary") and get_parent().inventory.current_mainhand_equipment is GunItem:
			
			if inventory.current_mainhand_equipment.item_size == 0:
				$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.115), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
				$"%ADSTween".start()
			else:
				$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, 0.124), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
				$"%ADSTween".start()
				
			if _camera.state == _camera.CameraState.STATE_NORMAL:   # Allows for binoc etc zoom
				_camera.fov  = lerp(_camera.fov, 70, 0.5)




func _on_Inventory_inventory_changed(is_mainhand_item):
	yield(get_tree().create_timer(0.5), "timeout")
	check_player_animation()
#	switch_mainhand_item_animation()

func switch_mainhand_item_animation():
	
	animation_tree.set("parameters/Hand_Transition/current",0)
	animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
	animation_tree.set("parameters/Weapon_states/current",4)
	
	yield(get_tree().create_timer(0.5), "timeout")
	check_player_animation()

func _on_Inventory_unequip_mainhand():
	animation_tree.set("parameters/Hand_Transition/current",0)
	animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
	animation_tree.set("parameters/Weapon_states/current",4)


func _on_Inventory_unequip_offhand():
	animation_tree.set("parameters/OffHand_Weapon_States/current",2)


func _on_Inventory_mainhand_slot_changed(previous, current):
	pass
#	yield(get_tree().create_timer(0.5), "timeout")
#	check_player_animation()


func _on_Inventory_offhand_slot_changed(previous, current):
	pass
#	animation_tree.set("parameters/OffHand_Weapon_States/current",2)
#	yield(get_tree().create_timer(0.5), "timeout")
#	check_player_animation()
