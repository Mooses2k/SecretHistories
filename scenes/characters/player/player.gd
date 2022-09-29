extends "res://scenes/characters/character.gd"
class_name Player

onready var tinnitus = $Tinnitus
onready var fps_camera = $Body/FPSCamera
onready var Gun_cam=$Body/FPSCamera/ViewportContainer/Viewport/GunCam


func _process(delta):
	Gun_cam.global_transform=fps_camera.global_transform
