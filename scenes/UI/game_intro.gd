extends Control


signal intro_done


func _ready():
# TODO: choose which of three random Help screens
#	randi() % 3
#	$CenterContainer/Help.texture_normal = help_screen
	
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _input(event):
	if event.is_action_pressed("fullscreen"):
		VideoSettings.set_fullscreen_enabled(!VideoSettings.is_fullscreen_enabled())
		# Size the center container to screen size
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		$Timer.start()
		_on_Timer_timeout()


func show_intro():
	$GameIntro.visible = true
	$Timer.start(1)


# TODO: Attach this signal
func _on_anything_pressed():
	queue_free()


func _change_slide(next_slide, next_slide_wait_time):
	pass


func _start_game():
	emit_signal("intro_done")


func _on_Timer_timeout():
#	match slide:
#		n:
#			_change_slide(n+1, 1 or 3)
#		final:
			_start_game()
			queue_free()

#	if $CenterContainer/MadeWithGodot.visible == true:
#		$CenterContainer/MadeWithGodot.visible = false
#	elif $CenterContainer/GPL.visible == true:
#		$CenterContainer/GPL.visible = false
#	elif $CenterContainer/Help.visible == true:
#		$CenterContainer/Help.visible = false
#	elif $last one.visible == true:
