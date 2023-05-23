extends Control


signal intro_done


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	show_intro()


func _input(event):
	if event.is_action_pressed("fullscreen"):
		VideoSettings.set_fullscreen_enabled(!VideoSettings.is_fullscreen_enabled())
		# Size the center container to screen size
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_start_game()
		queue_free()


func show_intro():
#	$GameIntro.visible = true
#	BackgroundMusic.stop
	$AnimationPlayer.play("Intro")


func _start_game():
	emit_signal("intro_done")
