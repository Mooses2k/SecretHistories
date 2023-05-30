extends Control


signal intro_done


func _input(event):
#	if event.is_action_pressed("fullscreen"):
#		VideoSettings.set_fullscreen_enabled(!VideoSettings.is_fullscreen_enabled())
		# Size the center container to screen size
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"): # But not mouse button
		_start_game()
		queue_free()


func show_intro():
	self.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
#	BackgroundMusic.stop
	$AnimationPlayer.play("Intro")


func _start_game():
	emit_signal("intro_done")


func _on_AnimationPlayer_animation_finished(anim_name):
	_start_game()
