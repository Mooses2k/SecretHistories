extends Control


const GAME_SCENE = preload("res://scenes/core/game.tscn")

var game : Game


func _ready() -> void:
	game = GAME_SCENE.instance()
	$"%StartGameSettings".attach_settings(game.get_node("%LocalSettings"))
	$"%SettingsUI".attach_settings(game.get_node("%LocalSettings"))


func _input(event):
	if event.is_action_pressed("fullscreen"):
		VideoSettings.set_fullscreen_enabled(!VideoSettings.is_fullscreen_enabled())


func _on_ZombieSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_CultistSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_GhostDetectionRange_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_StartGame_pressed() -> void:
#	var _error = get_tree().change_scene("res://scenes/core/game.tscn")
	# Visible the GameIntro scene here, it goes invis after click or timeout of last screen
	$HBoxContainer.visible = false
	$GameIntro.show_intro()


func _on_GameIntro_intro_done():
	GameManager.is_player_dead = false
	GameManager.act = 1
	LoadScreen.change_scene(game)


func _on_ReturnButton_pressed() -> void:
	var _error = get_tree().change_scene("res://scenes/UI/title_menu.tscn")
