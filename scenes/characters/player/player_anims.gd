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
#	print(inventory.current_mainhand_equipment)
#	print(inventory.current_offhand_equipment)
#	print(inventory.hotbar[off_hand_object])
	if not $"..".is_reloading:
		pass



func _physics_process(delta):
	ads()

#
##func check_current_item_animation():
#
#	# This code checks the current item equipped by the player and updates the current_mainhand_item_animation to correspond to it 
#	var main_hand_object = inventory.current_mainhand_slot
#	var off_hand_object = inventory.current_offhand_slot
#
#
#	if inventory.hotbar[off_hand_object].name != "empty_hand"  and inventory.hotbar[off_hand_object] != null and inventory.hotbar[off_hand_object].item_state == GlobalConsts.ItemState.EQUIPPED:
#		offhand_active = true
#		if inventory.hotbar[off_hand_object] is GunItem:
#			current_offhand_item_animation = hold_states.SMALL_GUN_ITEM_LEFT
#
#		elif inventory.hotbar[off_hand_object] is EquipmentItem:
#			if inventory.hotbar[off_hand_object].horizontal_holding == true:
#				current_offhand_item_animation = hold_states.ITEM_HORIZONTAL_LEFT
#				inventory.hotbar[off_hand_object].hold_position.rotation_degrees.z = -90
#			else:
#
#				current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
#
#		elif inventory.hotbar[off_hand_object] is MeleeItem:
#			current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
#
#		elif inventory.hotbar[off_hand_object] is ConsumableItem:
#			current_offhand_item_animation = hold_states.ITEM_HORIZONTAL_LEFT
#
#		elif inventory.hotbar[off_hand_object] is ToolItem:
#			current_offhand_item_animation = hold_states.ITEM_HORIZONTAL_LEFT
#
#	else:
#		if mainhand_active != true:
#			animation_tree.set("parameters/Hand_Transition/current",0)
#			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
#
#		offhand_active = false
#
#
#		# temporary hack (issue #409)
#	if not is_instance_valid(inventory.hotbar[main_hand_object]):
#		inventory.hotbar[main_hand_object] = null
#		return
#
#	if inventory.hotbar[main_hand_object] != null and inventory.hotbar[main_hand_object].item_state == GlobalConsts.ItemState.EQUIPPED:
#		mainhand_active = true
#		if inventory.hotbar[main_hand_object] is GunItem:
#
#			if inventory.hotbar[main_hand_object].item_size == 0:
#				current_mainhand_item_animation = hold_states.SMALL_GUN_ITEM
#			else:
#				current_mainhand_item_animation = hold_states.LARGE_GUN_ITEM
#
#		elif inventory.hotbar[main_hand_object] is EquipmentItem:
#
#			if inventory.hotbar[main_hand_object].horizontal_holding == true:
#				current_mainhand_item_animation = hold_states.ITEM_HORIZONTAL
#				inventory.hotbar[main_hand_object].hold_position.rotation_degrees.z = 90
#			else:
#				current_mainhand_item_animation = hold_states.ITEM_VERTICAL
#
#		elif inventory.hotbar[main_hand_object] is MeleeItem:
#			current_mainhand_item_animation = hold_states.ITEM_VERTICAL
#
#		elif inventory.hotbar[main_hand_object] is ConsumableItem:
#			current_mainhand_item_animation = hold_states.ITEM_HORIZONTAL
#
#		elif inventory.hotbar[main_hand_object] is ToolItem:
#			current_mainhand_item_animation = hold_states.ITEM_HORIZONTAL
#
#	else:
#		if offhand_active != false:
#			animation_tree.set("parameters/Hand_Transition/current",0)
#			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
#			animation_tree.set("parameters/Weapon_states/current",4)
#		mainhand_active = false






func check_player_animation():
	print(inventory.current_offhand_equipment)
	adjust_arm()
	if inventory.current_mainhand_equipment != null:
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
	if inventory.current_offhand_equipment != null:
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
	else:
		offhand_active = false
		
#	check_equipped_hands()
	# This code checks the current item type the player is equipping and set the animation that matches that item in the animation tree
	
	#___________offhand_object_______________#
	if inventory.current_offhand_equipment is GunItem:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		animation_tree.set("parameters/OffHand_Weapon_States/current",1)
		
	elif inventory.current_offhand_equipment is EquipmentItem:
		if inventory.current_offhand_equipment.horizontal_holding == true:
			inventory.current_offhand_equipment.hold_position.rotation_degrees.z = -90
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
			animation_tree.set("parameters/OffHand_Weapon_States/current",0)
			animation_tree.set("parameters/Offhand_Hold_Animation/current",1)
			
		else:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
			animation_tree.set("parameters/OffHand_Weapon_States/current",0)
			animation_tree.set("parameters/Offhand_Hold_Animation/current",0)

#	elif inventory.current_offhand_equipment is ConsumableItem:
#
#		animation_tree.set("parameters/Hand_Transition/current",0)
#		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
#		animation_tree.set("parameters/OffHand_Weapon_States/current",2)
#		animation_tree.set("parameters/Offhand_Hold_Animation/current",0)
#
#	elif inventory.current_offhand_equipment is ToolItem:
#
#		animation_tree.set("parameters/Hand_Transition/current",0)
#		animation_tree.set("parameters/OffHand_Weapon_States/current",2)
#		animation_tree.set("parameters/Offhand_Hold_Animation/current",0)
#
	elif inventory.current_offhand_equipment == EmptyHand:
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		animation_tree.set("parameters/OffHand_Weapon_States/current",2)


		
	#___________mainhand_object_______________#

	if inventory.current_mainhand_equipment is GunItem:
		
		if inventory.current_mainhand_equipment.item_size == 0:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/Weapon_states/current",2)
		else:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/Weapon_states/current",1)
		
		
	elif inventory.current_mainhand_equipment is EquipmentItem:
		if inventory.current_mainhand_equipment.horizontal_holding == true:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/Weapon_states/current",0)
			animation_tree.set("parameters/Hold_Animation/current",1)
		else:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/Weapon_states/current",0)
			animation_tree.set("parameters/Hold_Animation/current",0)
		
		
	elif inventory.current_mainhand_equipment is ConsumableItem:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/Weapon_states/current",0)
		animation_tree.set("parameters/Hold_Animation/current",0)
		
	elif inventory.current_mainhand_equipment is ToolItem:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/Weapon_states/current",0)
		animation_tree.set("parameters/Hold_Animation/current",0)
		
	elif inventory.current_mainhand_equipment == null:
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/Weapon_states/current",4)

	

func check_equipped_hands():
	if  offhand_active and  mainhand_active:
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		
	elif offhand_active and not mainhand_active:
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		
	elif mainhand_active and not offhand_active:
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
		
	elif not mainhand_active and not offhand_active:
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
#var mainhand_active = false

func adjust_arm():
	$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.105), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
	$"%ADSTween".start()


func ads():
	var main_hand_item = get_parent().inventory.current_mainhand_slot
	
	# This checks if the ADS mouse button is pressed then lerps the weapon to that position and when the button is released the weapon goes to its normal position
	if Input.is_action_pressed("main_use_secondary") and owner.do_sprint == false:

		if get_parent().inventory.current_mainhand_slot != null:
			
			if get_parent().inventory.hotbar[main_hand_item] is GunItem:
				$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(-0.097, -1.444, 0.108), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
				$"%ADSTween".start()
				if get_parent().inventory.hotbar[main_hand_item].item_size == 0:
					if _camera.state == _camera.CameraState.STATE_NORMAL:   # Allows for binoc etc zoom
						_camera.fov  = lerp(_camera.fov, 65, 0.5)
				else:
					if _camera.state == _camera.CameraState.STATE_NORMAL:   # Allows for binoc etc zoom
						_camera.fov  = lerp(_camera.fov, 60, 0.5)

	else:
		if Input.is_action_just_released("main_use_secondary") and get_parent().inventory.hotbar[main_hand_item] is GunItem or owner.do_sprint == true:
			$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, 0.124), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
			$"%ADSTween".start()
			if _camera.state == _camera.CameraState.STATE_NORMAL:   # Allows for binoc etc zoom
				_camera.fov  = lerp(_camera.fov, 70, 0.5)




func _on_Inventory_inventory_changed():
	check_player_animation()
