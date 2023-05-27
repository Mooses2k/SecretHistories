extends Node


#Different hold states depending on the item equipped
enum hold_states {
	SMALL_GUN_ITEM,
	LARGE_GUN_ITEM,
	MELEE_ITEM,
	LANTERN_ITEM,
	SMALL_GUN_ADS,
	LARGE_GUNS_ADS,
	UNEQUIPPED
}

export var _cam_path : NodePath
var current_mainhand_item_animation 
onready var inventory = $"../Inventory"
onready var arm_position = $"%MainCharOnlyArmsGameRig".translation
onready var _camera : ShakeCamera = get_node(_cam_path)


func _process(delta):
	check_player_animation()
	check_current_item_animation()


func _physics_process(delta):
	ads()


func check_current_item_animation():
	
	#This code checks the current item equipped by the player and updates the current_mainhand_item_animation to correspond to it 
		var main_hand_object = inventory.current_mainhand_slot
		var off_hand_object = inventory.current_offhand_slot

		# temporary hack (issue #409)
		if not is_instance_valid(inventory.hotbar[main_hand_object]):
			inventory.hotbar[main_hand_object] = null
			return

		if inventory.hotbar[main_hand_object] is GunItem or inventory.hotbar[off_hand_object] is GunItem :
			if inventory.hotbar[main_hand_object].item_size == 0:
				current_mainhand_item_animation = hold_states.SMALL_GUN_ITEM
			else:
				current_mainhand_item_animation = hold_states.LARGE_GUN_ITEM
				
		elif  inventory.hotbar[main_hand_object] is LanternItem or inventory.hotbar[off_hand_object] is LanternItem:
			current_mainhand_item_animation = hold_states.LANTERN_ITEM
			
		elif  inventory.hotbar[main_hand_object] is MeleeItem or inventory.hotbar[off_hand_object] is MeleeItem:
			current_mainhand_item_animation = hold_states.MELEE_ITEM
			
		elif inventory.hotbar[main_hand_object] is ConsumableItem or inventory.hotbar[off_hand_object] is ConsumableItem:
			$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
			$"../Player_Animation_tree".set("parameters/Weapon_states/current", 0)
			$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.105), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
			$"%ADSTween".start()
			
		elif inventory.hotbar[main_hand_object] is ToolItem or inventory.hotbar[off_hand_object] is ToolItem:
			$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
			$"../Player_Animation_tree".set("parameters/Weapon_states/current", 0)
			$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.105), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
			$"%ADSTween".start()
			
		else:
			$"../Player_Animation_tree".set("parameters/Animation_State/current", 0)


func ads():
	var main_hand_item = get_parent().inventory.current_mainhand_slot
	
	# This checks if the ADS mouse button is pressed then lerps the weapon to that position and when the button is released the weapon goes to its normal position
	if Input.is_action_pressed("ADS"):
		if get_parent().inventory.current_mainhand_slot != null:
			
			if get_parent().inventory.hotbar[main_hand_item] is GunItem:
				$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(-0.097, -1.444, 0.108), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
				$"%ADSTween".start()
				if get_parent().inventory.hotbar[main_hand_item].item_size == 0:
					_camera.fov  = lerp(_camera.fov, 65, 0.5)
				else:
					_camera.fov  = lerp(_camera.fov, 60, 0.5)

	else:
		if Input.is_action_just_released("ADS") and get_parent().inventory.hotbar[main_hand_item] is GunItem:
			$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, 0.124), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
			$"%ADSTween".start()
			_camera.fov  = lerp(_camera.fov, 70, 0.5)


func check_player_animation():
	#This code checks the current item type the player is equipping and set the animation that matches that item in the animation tree
	if current_mainhand_item_animation == hold_states.SMALL_GUN_ITEM:
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
		$"../Player_Animation_tree".set("parameters/Weapon_states/current", 2)
		
	elif current_mainhand_item_animation == hold_states.LARGE_GUN_ITEM :
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
		$"../Player_Animation_tree".set("parameters/Weapon_states/current", 1)

# The tween functions make sure that the items are visible by moving the hand a bit forward
	elif current_mainhand_item_animation == hold_states.MELEE_ITEM or current_mainhand_item_animation == hold_states.LANTERN_ITEM :
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
		$"../Player_Animation_tree".set("parameters/Weapon_states/current", 0)
		$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.105), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
		$"%ADSTween".start()

	else:
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 0)
		$"%ADSTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, 0.124), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
		$"%ADSTween".start()


func _on_Inventory_mainhand_slot_changed(previous, current):
	# Checks if there is something currently equipped, else does nothing
	if inventory.hotbar[current] != null:   # this code may be insufficient to handle can_attach!
		pass
	else:
		current_mainhand_item_animation = hold_states.UNEQUIPPED
