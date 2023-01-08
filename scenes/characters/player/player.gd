extends "res://scenes/characters/character.gd"
class_name Player

signal change_off_equipment_out_done()
signal change_main_equipment_out_done()

onready var tinnitus = $Tinnitus
onready var fps_camera = $FPSCamera
onready var gun_cam = $ViewportContainer2/Viewport/GunCam
onready var grab_cast = $FPSCamera/GrabCast

var colliding_pickable_items = []
var colliding_interactable_items = []
var mainhand_orig_origin = null
var offhand_orig_origin = null
var is_change_main_equip_out : bool = false
var is_change_main_equip_in : bool = false
var is_change_off_equip_out : bool = false
var is_change_off_equip_in : bool = false


func _ready():
	mainhand_orig_origin = mainhand_equipment_root.transform.origin
	offhand_orig_origin = offhand_equipment_root.transform.origin
	
#	body.add_collision_exception_with()


func _process(delta):
	gun_cam.global_transform = fps_camera.global_transform
	
	if colliding_pickable_items.empty() and colliding_interactable_items.empty():
		$Indication_canvas/Indication_system/Dot.hide()
	else:
		$Indication_canvas/Indication_system/Dot.show()
	
	grab_indicator()
	change_mainhand_equipment_in()
	change_maindhand_equipment_out()
	change_offhhand_equipment_out()
	change_offhand_equipment_in()


func drop_consumable(object):
	$PlayerController.throw_consumable()


func delete_bomb():
	pass


func grab_indicator():
	var grabable_object = grab_cast.get_collider()
	
	if grab_cast.is_colliding() and grabable_object is PickableItem:
		if $PlayerController.is_grabbing == false:
			$Indication_canvas/Indication_system/Grab.show()
	else:
			$Indication_canvas/Indication_system/Grab.hide()
	if grab_cast.is_colliding() and grabable_object.is_in_group("ignite"):
		if $PlayerController.is_grabbing == false and grabable_object.get_parent().item_state == GlobalConsts.ItemState.DROPPED :
			$Indication_canvas/Indication_system/Ignite.show()
			if Input.is_action_just_pressed("interact"):
				grabable_object.get_parent()._use_primary()
	else:
			$Indication_canvas/Indication_system/Ignite.hide()


func _on_GrabCastDot_body_entered(body):
	if body is PickableItem or body is Door_body:
		if !colliding_pickable_items.has(body):
			colliding_pickable_items.append(body)


func _on_GrabCastDot_body_exited(body):
	if body is PickableItem or body is Door_body:
		colliding_pickable_items.remove(colliding_pickable_items.find(body))


func _on_GrabCastDot_area_entered(area):
	if area is Interactable:
		if !colliding_interactable_items.has(area):
			colliding_interactable_items.append(area)


func _on_GrabCastDot_area_exited(area):
	if area is Interactable:
		colliding_interactable_items.remove(colliding_interactable_items.find(area))


func change_equipment_out(var is_mainhand : bool):
	if(is_mainhand):
		is_change_main_equip_in = false
		mainhand_equipment_root.transform.origin.y = mainhand_orig_origin.y
		mainhand_equipment_root.transform.origin.z = mainhand_orig_origin.z 
		is_change_main_equip_out = true
	else:
		is_change_off_equip_in = false
		offhand_equipment_root.transform.origin.y = offhand_orig_origin.y
		offhand_equipment_root.transform.origin.z = offhand_orig_origin.z 
		is_change_off_equip_out = true


func change_maindhand_equipment_out():
	if(is_change_main_equip_out):
		var from = mainhand_equipment_root.transform.origin.y
		mainhand_equipment_root.transform.origin.y = lerp(from, mainhand_orig_origin.y - 0.2, 0.3)
		
		from = mainhand_equipment_root.transform.origin.z
		mainhand_equipment_root.transform.origin.z = lerp(from, mainhand_orig_origin.z + 0.8, 0.3)
	
		var d1 = mainhand_equipment_root.transform.origin.z - (mainhand_orig_origin.z + 0.8)
		
		if d1 > -0.02:
			is_change_main_equip_out = false
			emit_signal("change_main_equipment_out_done")


func change_offhhand_equipment_out():
	if(is_change_off_equip_out):
		var from = offhand_equipment_root.transform.origin.y
		offhand_equipment_root.transform.origin.y = lerp(from, offhand_orig_origin.y - 0.25, 0.3)
		
		from = offhand_equipment_root.transform.origin.z
		offhand_equipment_root.transform.origin.z = lerp(from, offhand_orig_origin.z + 0.8, 0.3)
	
		var d1 = offhand_equipment_root.transform.origin.z - (offhand_orig_origin.z + 0.8)
		
		if d1 > -0.02:
			is_change_off_equip_out = false
			emit_signal("change_off_equipment_out_done")


func change_equipment_in(var is_mainhand : bool):
	if(is_mainhand):
		is_change_main_equip_out = false
		mainhand_equipment_root.transform.origin.y = mainhand_orig_origin.y - 0.2
		mainhand_equipment_root.transform.origin.z = mainhand_orig_origin.z + 0.8
		is_change_main_equip_in = true
	else:
		is_change_off_equip_out = false
		offhand_equipment_root.transform.origin.y = offhand_orig_origin.y - 0.25
		offhand_equipment_root.transform.origin.z = offhand_orig_origin.z + 0.8
		is_change_off_equip_in = true


func change_mainhand_equipment_in():
	if(is_change_main_equip_in):
		var from = mainhand_equipment_root.transform.origin.y
		mainhand_equipment_root.transform.origin.y = lerp(from, mainhand_orig_origin.y, 0.3)
		
		from = mainhand_equipment_root.transform.origin.z
		mainhand_equipment_root.transform.origin.z = lerp(from, mainhand_orig_origin.z, 0.3)
	
		var d1 = mainhand_equipment_root.transform.origin.z - (mainhand_orig_origin.z)
		
		if d1 < 0.02:
			mainhand_equipment_root.transform.origin.y = mainhand_orig_origin.y
			mainhand_equipment_root.transform.origin.z = mainhand_orig_origin.z
			is_change_main_equip_in = false


func change_offhand_equipment_in():
	if(is_change_off_equip_in):
		var from = offhand_equipment_root.transform.origin.y
		offhand_equipment_root.transform.origin.y = lerp(from, offhand_orig_origin.y, 0.3)
		
		from = offhand_equipment_root.transform.origin.z
		offhand_equipment_root.transform.origin.z = lerp(from, offhand_orig_origin.z, 0.3)
	
		var d1 = offhand_equipment_root.transform.origin.z - (offhand_orig_origin.z)
		
		if d1 < 0.02:
			offhand_equipment_root.transform.origin.y = offhand_orig_origin.y
			offhand_equipment_root.transform.origin.z = offhand_orig_origin.z
			is_change_off_equip_in = false
