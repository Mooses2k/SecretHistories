extends "res://scenes/characters/character.gd"
class_name Player


onready var tinnitus = $Tinnitus
onready var fps_camera = $Body/FPSCamera
onready var gun_cam=$"Body/FPSCamera/ViewportContainer2/Viewport/GunCam"
onready var grabcast=$Body/FPSCamera/GrabCast


func _process(delta):
	gun_cam.global_transform=fps_camera.global_transform
	grab_indicator()
	

func drop_consumable(object):
	$PlayerController.throw_consumable()
func delete_bomb():
	pass
func grab_indicator():
	var grabable_object=grabcast.get_collider()
	
	if grabcast.is_colliding() and grabable_object is PickableItem:
		if $PlayerController.is_grabbing==false:
			$Indication_canvas/Indication_system/Grab.show()
	else:
			$Indication_canvas/Indication_system/Grab.hide()
