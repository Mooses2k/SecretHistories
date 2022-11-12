extends CanvasLayer


var is_BW = false
onready var main_cam = get_node("../Body/FPSCamera")
onready var gun_cam = get_node("../Body/FPSCamera/ViewportContainer2/Viewport/GunCam")
onready var white_effect_rect = get_node("../Tinnitus/ScreenWhite/TextureRect")


func _input(event):
	if event is InputEvent and event.is_pressed() and is_BW:
		_fade_to_black()


func _on_Player_character_died():
	GameManager.is_player_dead = true
	get_tree().paused = true
	$Death.play()
	$ColorRect.show()
	main_cam.transform.origin.z += 0.8
	yield(get_tree().create_timer(1.5), "timeout")
	$BW.show()
	is_BW = true
	gun_cam.cull_mask = 0
	white_effect_rect.hide()
	_move_cam()


func _move_cam():
	$Tween.interpolate_property($ColorRect, "modulate:a", 1, 0, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.interpolate_property(main_cam, "translation", 
			Vector3(main_cam.transform.origin.x, main_cam.transform.origin.y, main_cam.transform.origin.z), 
			Vector3(main_cam.transform.origin.x, main_cam.transform.origin.y + 1, main_cam.transform.origin.z + 1.8), 
			8, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.interpolate_property(main_cam, "rotation_degrees", 
			Vector3(main_cam.transform.basis.x.x, main_cam.transform.basis.y.y, main_cam.transform.basis.z.z), 
			Vector3(main_cam.transform.basis.x.x-45, main_cam.transform.basis.y.y, main_cam.transform.basis.z.z), 
			5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.start()


func _fade_to_black():
	$Tween.interpolate_property($ColorRect, "modulate:a", 0, 1, 0.7, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.start()


func _on_Tween_tween_completed(object, key):
	if object.name == "ColorRect" and $ColorRect.modulate.a == 1:
		yield(get_tree().create_timer(1), "timeout")
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var error = get_tree().change_scene("res://scenes/UI/title_menu.tscn")
