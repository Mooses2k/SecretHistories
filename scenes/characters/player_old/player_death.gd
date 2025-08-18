extends CanvasLayer


var is_bw = false

@onready var _main_cam = get_node("../FPSCamera")
@onready var _player_arms = get_node("../FPSCamera/MainCharOnlyArmsGameRig")
@onready var _gun_cam = get_node("../FPSCamera/SubViewportContainer/SubViewport/GunCam")
@onready var _white_effect_rect = get_node("../Tinnitus/ScreenWhite/TextureRect")


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
	await get_tree().create_timer(1.5).timeout   # Darkness for 1.5 seconds
	$BW.show()
	is_bw = true
	$"../HitEffect".visible = false
	_player_arms.visible = false
	_gun_cam.cull_mask = 0
	_white_effect_rect.hide()
	_move_cam()


func _move_cam():
	var cam_tween = get_tree().create_tween()
	cam_tween.tween_property($ColorRect, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(_main_cam, "position", 
			Vector3(_main_cam.transform.origin.x, _main_cam.transform.origin.y + 1, _main_cam.transform.origin.z),   # Previously z+1.8
			8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(_main_cam, "rotation_degrees", 
			Vector3(_main_cam.transform.basis.x.x - 90, _main_cam.transform.basis.y.y, _main_cam.transform.basis.z.z),   # Previously x-45
			5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cam_tween.start()


func _fade_to_black():
	var fade_tween
	fade_tween.tween_property($ColorRect, "modulate:a", 0, 1, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_tween.start()
	fade_tween.finished.connect(_on_Tween_tween_completed)


func _on_Tween_tween_completed():
	if $ColorRect.modulate.a == 1:
		await get_tree().create_timer(1).timeout
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var error = get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
