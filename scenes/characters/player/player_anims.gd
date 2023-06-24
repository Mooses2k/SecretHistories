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

var offhand_active = false
var mainhand_active = false



var current_mainhand_item_animation 
var current_offhand_item_animation 

func _process(delta):
	if not $"..".is_reloading:
		check_player_animation()
		check_current_item_animation()


func _physics_process(delta):
	ads()


func check_current_item_animation():
	
	# This code checks the current item equipped by the player and updates the current_mainhand_item_animation to correspond to it 
	var main_hand_object = inventory.current_mainhand_slot
	var off_hand_object = inventory.current_offhand_slot


	if inventory.hotbar[off_hand_object].name != "empty_hand"  and inventory.hotbar[off_hand_object] != null and inventory.hotbar[off_hand_object].item_state == GlobalConsts.ItemState.EQUIPPED:
		offhand_active = true
		if inventory.hotbar[off_hand_object] is GunItem:
			current_offhand_item_animation = hold_states.SMALL_GUN_ITEM_LEFT
			
		elif inventory.hotbar[off_hand_object] is EquipmentItem:
			if inventory.hotbar[off_hand_object].horizontal_holding == true:
				current_offhand_item_animation = hold_states.ITEM_HORIZONTAL_LEFT
				inventory.hotbar[off_hand_object].hold_position.rotation_degrees.z = -90
			else:
				
				current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
			
		elif inventory.hotbar[off_hand_object] is MeleeItem:
			current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
			
		elif inventory.hotbar[off_hand_object] is ConsumableItem:
			current_offhand_item_animation = hold_states.ITEM_HORIZONTAL_LEFT
			
		elif inventory.hotbar[off_hand_object] is ToolItem:
			current_offhand_item_animation = hold_states.ITEM_HORIZONTAL_LEFT
			
	else:
		if mainhand_active != true:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
		
		offhand_active = false


		# temporary hack (issue #409)
	if not is_instance_valid(inventory.hotbar[main_hand_object]):
		inventory.hotbar[main_hand_object] = null
		return

	if inventory.hotbar[main_hand_object] != null and inventory.hotbar[main_hand_object].item_state == GlobalConsts.ItemState.EQUIPPED:
		mainhand_active = true
		if inventory.hotbar[main_hand_object] is GunItem:
			
			if inventory.hotbar[main_hand_object].item_size == 0:
				current_mainhand_item_animation = hold_states.SMALL_GUN_ITEM
			else:
				current_mainhand_item_animation = hold_states.LARGE_GUN_ITEM
				
		elif inventory.hotbar[main_hand_object] is EquipmentItem:
			
			if inventory.hotbar[main_hand_object].horizontal_holding == true:
				current_mainhand_item_animation = hold_states.ITEM_HORIZONTAL
				inventory.hotbar[main_hand_object].hold_position.rotation_degrees.z = 90
			else:
				current_mainhand_item_animation = hold_states.ITEM_VERTICAL
			
		elif inventory.hotbar[main_hand_object] is MeleeItem:
			current_mainhand_item_animation = hold_states.ITEM_VERTICAL
			
		elif inventory.hotbar[main_hand_object] is ConsumableItem:
			current_mainhand_item_animation = hold_states.ITEM_HORIZONTAL
			
		elif inventory.hotbar[main_hand_object] is ToolItem:
			current_mainhand_item_animation = hold_states.ITEM_HORIZONTAL
			
	else:
		if offhand_active != false:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
			animation_tree.set("parameters/Weapon_states/current",4)
		mainhand_active = false



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


func check_player_animation():
	# This code checks the current item type the player is equipping and set the animation that matches that item in the animation tree
	if current_mainhand_item_animation == hold_states.SMALL_GUN_ITEM:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
		animation_tree.set("parameters/Weapon_states/current",2)
		adjust_arm()
		

	elif current_mainhand_item_animation == hold_states.LARGE_GUN_ITEM :
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
		animation_tree.set("parameters/Weapon_states/current",1)

	elif current_mainhand_item_animation == hold_states.ITEM_VERTICAL:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
		animation_tree.set("parameters/Weapon_states/current",0)
		animation_tree.set("parameters/Hold_Animation/current",0)
		adjust_arm()

	elif current_mainhand_item_animation == hold_states.ITEM_HORIZONTAL:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
		animation_tree.set("parameters/Weapon_states/current",0)
		animation_tree.set("parameters/Hold_Animation/current",1)
		adjust_arm()

	elif current_offhand_item_animation == hold_states.SMALL_GUN_ITEM_LEFT:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		animation_tree.set("parameters/Weapon_states/current",4)
		animation_tree.set("parameters/OffHand_Weapon_States/current",1)
		adjust_arm()
		
	elif current_offhand_item_animation == hold_states.ITEM_VERTICAL_LEFT:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		animation_tree.set("parameters/Weapon_states/current",4)
		animation_tree.set("parameters/OffHand_Weapon_States/current",0)
		animation_tree.set("parameters/Offhand_Hold_Animation/current",0)
		
		adjust_arm()
		
	elif current_offhand_item_animation == hold_states.ITEM_HORIZONTAL_LEFT:
		
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
		animation_tree.set("parameters/Weapon_states/current",4)
		animation_tree.set("parameters/OffHand_Weapon_States/current",0)
		animation_tree.set("parameters/Offhand_Hold_Animation/current",1)
		adjust_arm()

	if offhand_active == true and mainhand_active == true:
		animation_tree.set("parameters/Hand_Transition/current",0)
		animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",1)
#
#	else:
#		animation_tree.set("parameters/Animation_State/current", 0)
#		$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, 0.124), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
#		$"%ADSTween".start()
#		print("Nothing is equipped")

func adjust_arm():
	$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.105), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
	$"%ADSTween".start()



func _on_Inventory_mainhand_slot_changed(previous, current):
	# Checks if there is something currently equipped, else does nothing
	if inventory.hotbar[current] != null:   # This code may be insufficient to handle can_attach!
		pass
	else:
		current_mainhand_item_animation = hold_states.UNEQUIPPED
		print("unequipping something")


func _on_Inventory_offhand_slot_changed(previous, current):
	if  inventory.hotbar[current] is GunItem:
		current_offhand_item_animation = hold_states.SMALL_GUN_ITEM_LEFT
		
	elif inventory.hotbar[current] is EquipmentItem:
		if inventory.hotbar[current].horizontal_holding == true:
			inventory.hotbar[current].hold_position.rotation_degrees.z = 90
			current_offhand_item_animation = hold_states.ITEM_HORIZONTAL_LEFT
		else:
			current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
		
	elif inventory.hotbar[current] is MeleeItem:
		current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
	elif inventory.hotbar[current] is ConsumableItem:
		current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
		
	elif inventory.hotbar[current] is ToolItem:
		current_offhand_item_animation = hold_states.ITEM_VERTICAL_LEFT
	else:
		if mainhand_active != true:
			animation_tree.set("parameters/Hand_Transition/current",0)
			animation_tree.set("parameters/OffHand_MainHand_Blend/blend_amount",0)
		
		offhand_active = false
