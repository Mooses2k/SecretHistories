extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	var brightness_value = VideoSettings.get_brightness()
	$GammaSlider.value = brightness_value
	
	# Apply initial brightness to the TextureRect
	var texture_rect = $TextureRect
	if is_instance_valid(texture_rect):
		texture_rect.modulate = Color(brightness_value, brightness_value, brightness_value, 1.0)


func _on_gamma_slider_value_changed(value):
	# Apply brightness to the 2D TextureRect by modulating its color
	# The modulation affects the brightness of the 2D image
	var texture_rect = $TextureRect
	if is_instance_valid(texture_rect):
		# Use the brightness value to modulate the texture color
		# Values > 1.0 make it brighter, values < 1.0 make it darker
		texture_rect.modulate = Color(value, value, value, 1.0)
	
	VideoSettings.set_brightness(value)


func _on_button_pressed():
	GameSettings.is_first_run = false

	# Save the setting to persistent storage
	SettingsConfig.save_settings()
	visible = false
