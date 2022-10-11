extends "res://scenes/characters/character.gd"
class_name Player


onready var tinnitus = $Tinnitus
onready var fps_camera = $Body/FPSCamera
onready var Gun_cam=$"Body/FPSCamera/ViewportContainer2/Viewport/GunCam"
onready var grabcast=$Body/FPSCamera/GrabCast



func _process(delta):
	Gun_cam.global_transform=fps_camera.global_transform
	grab_indicator()
#	if get_tree().paused==true:
#		$Indication_canvas/Indication_system.hide()
#	else:
#		$Indication_canvas/Indication_system.show()

func grab_indicator():
	var grabable_object=grabcast.get_collider()
	if grabcast.is_colliding() and grabable_object.has_method("is_grabable") :
			if $PlayerController.is_grabbing==false:
				$Indication_canvas/Indication_system/Grab.show()
	else:
			$Indication_canvas/Indication_system/Grab.hide()

