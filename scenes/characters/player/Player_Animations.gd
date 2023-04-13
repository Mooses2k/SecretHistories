extends Node


enum hold_states {
	SMALL_GUN_ITEM,
	LARGE_GUN_ITEM,
	MELEE_ITEM,
	LANTERN_ITEM,
	SMALL_GUN_ADS,
	LARGE_GUNS_ADS,
}


onready var inventory = $"../Inventory"
onready var arm_position = $"%MainCharOnlyArmsGameRig".translation
var current_mainhand_item_animation 
export var _cam_path : NodePath
onready var _camera : ShakeCamera = get_node(_cam_path)

func _process(delta):
	check_player_animation()
	check_curent_weapon()

func _physics_process(delta):
	ads()
	
func _on_Inventory_mainhand_slot_changed(previous, current):
	if inventory.hotbar[current] is GunItem:
		pass
	else:
		pass
#		current_mainhand_item_animation = hold_states.MELEE_ITEM

func check_curent_weapon():
		var main_hand_object = inventory.current_mainhand_slot
		var off_hand_object = inventory.current_offhand_slot


		if inventory.hotbar[main_hand_object] is GunItem or inventory.hotbar[off_hand_object] is GunItem :
			
			if inventory.hotbar[main_hand_object].item_size == 0:
				current_mainhand_item_animation = hold_states.SMALL_GUN_ITEM
			else:
				current_mainhand_item_animation = hold_states.LARGE_GUN_ITEM
				
		elif  inventory.hotbar[main_hand_object] is LanternItem  or inventory.hotbar[off_hand_object] is LanternItem:
			current_mainhand_item_animation = hold_states.LANTERN_ITEM
		elif  inventory.hotbar[main_hand_object] is MeleeItem  or inventory.hotbar[off_hand_object] is MeleeItem:
			current_mainhand_item_animation = hold_states.MELEE_ITEM
		else:
			$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
			$"../Player_Animation_tree".set("parameters/Weapon_states/current", 0)

func ads():
	if Input.is_action_pressed("ADS"):
		var main_hand_item = get_parent().inventory.current_mainhand_slot
		
		if get_parent().inventory.current_mainhand_slot != null:
			
			if get_parent().inventory.hotbar[main_hand_item] is GunItem:
				$"%AdsTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(-0.097, -1.444, 0.108), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
				$"%AdsTween".start()
				if get_parent().inventory.hotbar[main_hand_item].item_size == 0:
					_camera.fov  = lerp(_camera.fov, 65, 0.5)
					
				else:
					_camera.fov  = lerp(_camera.fov, 60, 0.5)


	else:
		if Input.is_action_just_released("ADS"):
			$"%AdsTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, 0.124), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
			$"%AdsTween".start()
			_camera.fov  = lerp(_camera.fov, 70, 0.5)
			
			
			

func check_player_animation():
	if current_mainhand_item_animation == hold_states.SMALL_GUN_ITEM:
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
		$"../Player_Animation_tree".set("parameters/Weapon_states/current", 2)
		
	elif current_mainhand_item_animation == hold_states.LARGE_GUN_ITEM :
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
		$"../Player_Animation_tree".set("parameters/Weapon_states/current", 1)
		
		
	elif current_mainhand_item_animation == hold_states.MELEE_ITEM or current_mainhand_item_animation == hold_states.LANTERN_ITEM :
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 1)
		$"../Player_Animation_tree".set("parameters/Weapon_states/current", 0)
		$"%AdsTween".interpolate_property($"%MainCharOnlyArmsGameRig", "translation", $"%MainCharOnlyArmsGameRig".translation, Vector3(0.015, -1.474, -0.172), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT )
		$"%AdsTween".start()
	
	else:
		$"../Player_Animation_tree".set("parameters/Animation_State/current", 0)
#		$"../Player_Animation_tree".set("parameters/Weapon_states/current", 0)
