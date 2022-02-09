extends Popup


func _ready() -> void:
	var _error = $HBoxContainer/Column/Graphics/GridContainer/FullscreenSlider.connect("item_selected", self, "Fullscreen")
	$HBoxContainer/Column/Graphics/GridContainer/FullscreenSlider.add_item("Fullscreen", GlobalSettings.FullscreenMode.FULLSCREEN)
	$HBoxContainer/Column/Graphics/GridContainer/FullscreenSlider.add_item("Borderless Windowed", GlobalSettings.FullscreenMode.BORDERLESS_WINDOWED)
	$HBoxContainer/Column/Graphics/GridContainer/FullscreenSlider.add_item("Windowed", GlobalSettings.FullscreenMode.WINDOWED)

	$HBoxContainer/Column/Graphics/GridContainer/FullscreenSlider.select(GlobalSettings.fullscreen_mode)


func Fullscreen(item):
	GlobalSettings.fullscreen_mode = item


func _on_VSyncButton_toggled(_button_pressed: bool) -> void:
	if OS.vsync_enabled == true:
		OS.vsync_enabled = false
	else:
		OS.vsync_enabled = true
	#not tested


func _on_BrightnessSlider_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_master_audio_db_value_changed(value: float) -> void:
	GlobalSettings.master_audio_volume = value
	if value == $HBoxContainer/Column/Audio/GridContainer3/master_audio_db.min_value:
		GlobalSettings.master_audio_enabled = false
	else:
		GlobalSettings.master_audio_enabled = true
	emit_signal("master_audio_changed") # signal not handled at the moment
	AudioServer.set_bus_volume_db(0, value) # working


func _on_sound_db_value_changed(value: float) -> void:
	GlobalSettings.sound_volume = value
	if value == $HBoxContainer/Column/Audio/GridContainer3/sound_db.min_value:
		GlobalSettings.sound_enabled = false
	else:
		GlobalSettings.sound_enabled = true
	emit_signal("sound_audio_changed") # signal not handled at the moment


func _on_music_db_value_changed(value: float) -> void:
	GlobalSettings.music_volume = value
	if value == $HBoxContainer/Column/Audio/GridContainer3/music_db.min_value:
		GlobalSettings.music_enabled = false
	else:
		GlobalSettings.music_enabled = true
	emit_signal("music_audio_changed") # signal not handled at the moment


func _on_voice_db_value_changed(value: float) -> void:
	GlobalSettings.voice_volume = value
	if value == $HBoxContainer/Column/Audio/GridContainer3/voice_db.min_value:
		GlobalSettings.voice_enabled = false
	else:
		GlobalSettings.voice_enabled = true
	emit_signal("voice_audio_changed") # signal not handled at the moment


func _on_ReturnButton_pressed() -> void:
	hide()
