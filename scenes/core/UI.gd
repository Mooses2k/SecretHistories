extends Node


onready var modal_window_active = false
#onready var start_game_menu_active = true    #doesn't work these two
#onready var title_menu_active = false
onready var esc_menu_active = false
onready var settings_menu_active = false
onready var ingame_menu_active = false


func _ready():
	pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal_window_active == true: #NA, things like press key to keybind or quit game dialog
			pass #hide modal window
#		if start_game_menu_active == true:    #not working
#			start_game_menu_active = false
#			title_menu_active = true
#			get_tree().change_scene("res://scenes/UI/title_menu.tscn")
#		if title_menu_active == true:
#			#implement 'do you want to quit?'
#			get_tree().quit()
		elif settings_menu_active == true:
			settings_menu_active = false
			$PauseMenu/SettingsMenu.hide() #hide settings_menu
		elif esc_menu_active == true:
			$PauseMenu/EscMenu/ColorRect.visible = get_tree().paused
			get_tree().paused = not get_tree().paused
			_on_EscMenu_popup_hide() #go to HUD
		elif ingame_menu_active == true: #NA, ingame menus like inv/map/journal not implemented yet
			pass #go to HUD
		else: #is in HUD
			$PauseMenu/EscMenu/ColorRect.visible = get_tree().paused
			get_tree().paused = not get_tree().paused
			$PauseMenu/EscMenu.popup() #go to esc menu
		get_tree().set_input_as_handled()


func _on_EscMenu_about_to_show() -> void:
	esc_menu_active = true


func _on_EscMenu_popup_hide() -> void:
	$PauseMenu/EscMenu.visible = get_tree().paused
	esc_menu_active = false


func _on_SettingsMenu_about_to_show() -> void:
	settings_menu_active = true


func _on_SettingsMenu_popup_hide() -> void:
	settings_menu_active = false
