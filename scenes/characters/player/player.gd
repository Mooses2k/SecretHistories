class_name Player
extends Character


#signal change_off_equipment_out_done()
#signal change_main_equipment_out_done()

var colliding_pickable_items = []
var colliding_interactable_items = []
var mainhand_orig_origin = null
var offhand_orig_origin = null
var is_change_main_equip_out : bool = false
var is_change_main_equip_in : bool = false
var is_change_off_equip_out : bool = false
var is_change_off_equip_in : bool = false

var light_resource = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
var light2_resource = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/omnidirectional_lantern/omni_lantern.tscn")

onready var player_controller = $PlayerController
onready var tinnitus = $Tinnitus
onready var fps_camera = $FPSCamera
onready var gun_cam = $FPSCamera/ViewportContainer/Viewport/GunCam   # Fixed fov player viewport so stuff doesn't go through walls
onready var grabcast = $FPSCamera/GrabCast
onready var player_animation_tree = $"%AnimationTree"
onready var hit_effect = $HitEffect


func _ready():
	if not is_connected("player_landed", player_controller, "_on_Player_player_landed"):
		connect("player_landed", player_controller, "_on_Player_player_landed")
	mainhand_orig_origin = mainhand_equipment_root.transform.origin
	offhand_orig_origin = offhand_equipment_root.transform.origin
	
	# Add initial equipment to player
	inventory.add_item(light2_resource.instance())
	print("player.gd added oil lantern")
	inventory.set_mainhand_slot(2)
	inventory.add_item(light_resource.instance())
	print("player.gd added candle")


func _process(delta):
	if colliding_pickable_items.empty() and colliding_interactable_items.empty():
		$Indication_canvas/Indication_system/Dot.hide()
	else :
		$Indication_canvas/Indication_system/Dot.show()
	
	grab_indicator()
	
	# This notifies the "pointing nearby" dot if the player is currently grabbing something
	if player_controller.is_grabbing == true:
		$Indication_canvas/Indication_system/Dot.hide()
		
	if is_reloading == true:
		if noise_level < 8:
			noise_level = 8
			$Audio/NoiseTimer.start()
			
	if light_level > 0.01:
#		$KinestheticSense.visible = false
		$KinestheticSense/Tween.interpolate_property($KinestheticSense, "light_energy", $KinestheticSense.light_energy, 0.0, 1.0)
		$KinestheticSense/Tween.start()
#		print("Lit up, kinesthetic sense fading: ", $KinestheticSense.light_energy)
	else:
#		$KinestheticSense.visible = true
		$KinestheticSense/Tween.interpolate_property($KinestheticSense, "light_energy", $KinestheticSense.light_energy, 0.3, 1.0)
		$KinestheticSense/Tween.start()
#		print("In the dark, kinesthetic sense increasing: ", $KinestheticSense.light_energy)


### These five functions maybe better in fps_control_mode.gd?

func grab_indicator():
	var grabable_object = grabcast.get_collider()
	
	if grabable_object != null:
		if grabcast.is_colliding() and grabable_object is PickableItem and player_controller.is_grabbing == false:
			$Indication_canvas/Indication_system/Grab.show()
		elif grabcast.is_colliding() and grabable_object is RigidBody and player_controller.is_grabbing == false:
			$Indication_canvas/Indication_system/Grab.show()
		else:
			$Indication_canvas/Indication_system/Grab.hide()
		if grabcast.is_colliding() and grabable_object.is_in_group("IGNITE") and $PlayerController.is_grabbing == false and grabable_object.get_parent().item_state == GlobalConsts.ItemState.DROPPED:
#			if $PlayerController.is_grabbing == false and grabable_object.get_parent().item_state == GlobalConsts.ItemState.DROPPED :
				$Indication_canvas/Indication_system/Ignite.show()
				if Input.is_action_just_pressed("player|interact"):
					grabable_object.get_parent()._use_primary()
		else:
			$Indication_canvas/Indication_system/Ignite.hide()
	else:
		$Indication_canvas/Indication_system/Grab.hide()
		$Indication_canvas/Indication_system/Ignite.hide()


# Is_in_group("Door_hitbox") or Door_body  # Please rename this group to DOOR_HITBOX and/or DoorBody after door merge
func _on_GrabCastDot_body_entered(body):
	if body is PickableItem or body is Door_body :
		if !colliding_pickable_items.has(body):
			colliding_pickable_items.append(body)


func _on_GrabCastDot_body_exited(body):
	if body is PickableItem or body is Door_body:
		colliding_pickable_items.remove(colliding_pickable_items.find(body))


func _on_GrabCastDot_area_entered(area):
	if area is Interactable :
		if !colliding_interactable_items.has(area):
			colliding_interactable_items.append(area)


func _on_GrabCastDot_area_exited(area):
	if area is Interactable:
		colliding_interactable_items.remove(colliding_interactable_items.find(area))
