extends Control


const GAME_SCENE = preload("res://scenes/game.tscn")

var game : Game


func _ready() -> void:
	game = GAME_SCENE.instantiate()
	%StartGameSettings.attach_settings(game.get_node("%LocalSettings"))
	%SettingsUI.attach_settings(game.get_node("%LocalSettings"), false)


func _input(event):
	if event.is_action_pressed("misc|fullscreen"):
		VideoSettings.set_fullscreen_enabled(!VideoSettings.fullscreen_enabled)


func _on_ZombieSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_CultistSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_GhostDetectionRange_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_StartGame_pressed() -> void:
	$HBoxContainer.visible = false
	BackgroundMusic.stop()
	$AudioStreamPlayer.play()
	$Timer.start(3)


func _on_Timer_timeout():
	$GameIntro.show_intro()


func _on_GameIntro_intro_done():
	GameManager.is_player_dead = false
	GameManager.act = 1
	LoadScene.change_scene_to_file(game)


func _on_ReturnButton_pressed() -> void:
	var _error = get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
