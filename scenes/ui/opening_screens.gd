extends Control


func _ready():
# TODO: choose which of three random Help screens
#	randi() % 3
#	$CenterContainer/Help.texture_normal = help_screen
	
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _input(event):
	if event.is_action_pressed("misc|fullscreen"):
		VideoSettings.set_fullscreen_enabled(!VideoSettings.fullscreen_enabled)
		# Size the center container to screen size
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		$Timer.start()
		_on_Timer_timeout()


func _on_PreMusicTimer_timeout():
	BackgroundMusic.volume_db = 0
	BackgroundMusic.play()
	$Timer.start()


func _on_MadeWithGodot_pressed():
	$MadeWithGodot.visible = false


func _on_GPL_pressed():
	$GPL.visible = false


func _on_GoDieInAHole_pressed():
	$GoDieInAHole.visible = false


func _on_Help_pressed():
	var _error = get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")


func _on_Timer_timeout():
	if $MadeWithGodot.visible == true:
		$MadeWithGodot.visible = false
	elif $GPL.visible == true:
		$GPL.visible = false
	elif $GoDieInAHole.visible == true:
		$GoDieInAHole.visible = false
	elif $Help.visible == true:
		var _error = get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
