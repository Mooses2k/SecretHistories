extends CanvasLayer


func _input(event):
	if event is InputEvent and event.is_action_pressed("kick"):
		_on_Player_character_died()
		
	if event is InputEvent and event.is_pressed() and $ColorRect.modulate.a == 1:
		yield(get_tree().create_timer(2), "timeout")
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ChangeScene._change_to_scene("res://scenes/UI/title_menu.tscn")


func _on_Player_character_died():
	get_tree().paused = true
	$Death.play()
	$Tween.interpolate_property($ColorRect, "modulate:a", 0.0, 1.0, 2.0, Tween.TRANS_SINE, Tween.EASE_IN)
	$Tween.start()
