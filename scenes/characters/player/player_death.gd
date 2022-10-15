extends CanvasLayer


var is_BW = false
export var main_cam_path : NodePath
onready var main_cam = get_node(main_cam_path)


func _input(event):
	if event is InputEvent and event.is_action_pressed("kick"):
		_on_Player_character_died()
	else:
		if event is InputEvent and event.is_pressed() and is_BW:
			_fade_to_black()


func _on_Player_character_died():
	get_tree().paused = true
	$Death.play()
	$ColorRect.show()
	yield(get_tree().create_timer(1.5), "timeout")
	$BW.show()
	$ColorRect.modulate.a = 0
	is_BW = true
	_move_cam()


func _move_cam():
	$Tween.interpolate_property(main_cam, "translation", 
			Vector3(main_cam.transform.origin.x, main_cam.transform.origin.y, main_cam.transform.origin.z), 
			Vector3(main_cam.transform.origin.x, main_cam.transform.origin.y + 1, main_cam.transform.origin.z + 1.3), 
			8, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.interpolate_property(main_cam, "rotation_degrees", 
			Vector3(main_cam.transform.basis.x.x, main_cam.transform.basis.y.y, main_cam.transform.basis.z.z), 
			Vector3(main_cam.transform.basis.x.x-40, main_cam.transform.basis.y.y, main_cam.transform.basis.z.z), 
			5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.start()


func _fade_to_black():
	$Tween.interpolate_property($ColorRect, "modulate:a", 0, 1, 0.7, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.start()


func _on_Tween_tween_completed(object, key):
	if object.name == "ColorRect":
		yield(get_tree().create_timer(1), "timeout")
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var error = get_tree().change_scene("res://scenes/UI/title_menu.tscn")
