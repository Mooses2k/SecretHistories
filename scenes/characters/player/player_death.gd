extends CanvasLayer


var is_bw = false

onready var _main_cam = get_node("../FPSCamera")
onready var _player_arms = get_node("../FPSCamera/MainCharOnlyArmsGameRig")
onready var _gun_cam = get_node("../FPSCamera/ViewportContainer/Viewport/GunCam")
onready var _white_effect_rect = get_node("../Tinnitus/ScreenWhite/TextureRect")


func _input(event):
	if event is InputEvent and event.is_pressed() and is_bw:
		_fade_to_black()


func _on_Player_character_died():
	GameManager.is_player_dead = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	$Death.play()
	$ColorRect.show()
	_main_cam.transform.origin.z += 0.8
	yield(get_tree().create_timer(1.5), "timeout")   # Darkness for 1.5 seconds
	$BW.show()
	is_bw = true
	_player_arms.visible = false
	_gun_cam.cull_mask = 0
	_white_effect_rect.hide()
	_move_cam()


func _move_cam():
	$Tween.interpolate_property($ColorRect, "modulate:a", 1, 0, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.interpolate_property(_main_cam, "translation", 
			Vector3(_main_cam.transform.origin.x, _main_cam.transform.origin.y, _main_cam.transform.origin.z), 
			Vector3(_main_cam.transform.origin.x, _main_cam.transform.origin.y + 1, _main_cam.transform.origin.z),   # Previously z+1.8
			8, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.interpolate_property(_main_cam, "rotation_degrees", 
			Vector3(_main_cam.transform.basis.x.x, _main_cam.transform.basis.y.y, _main_cam.transform.basis.z.z), 
			Vector3(_main_cam.transform.basis.x.x-90, _main_cam.transform.basis.y.y, _main_cam.transform.basis.z.z),   # Previously x-45
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
		var error = get_tree().change_scene("res://scenes/ui/title_menu.tscn")
