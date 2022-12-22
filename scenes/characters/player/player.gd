extends "res://scenes/characters/character.gd"
class_name Player


onready var tinnitus = $Tinnitus
onready var fps_camera = $FPSCamera
onready var gun_cam = $ViewportContainer2/Viewport/GunCam
onready var grab_cast = $FPSCamera/GrabCast

var colliding_pickable_items = []
var colliding_interactable_items = []


#func _ready():
#	body.add_collision_exception_with()


func _process(delta):
	gun_cam.global_transform = fps_camera.global_transform
	
	if colliding_pickable_items.empty() and colliding_interactable_items.empty():
		$Indication_canvas/Indication_system/Dot.hide()
	else:
		$Indication_canvas/Indication_system/Dot.show()
	
	grab_indicator()


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
		if $PlayerController.is_grabbing == false:
			$Indication_canvas/Indication_system/Ignite.show()
			if Input.is_action_just_pressed("Left_Mouse_Button"):
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
