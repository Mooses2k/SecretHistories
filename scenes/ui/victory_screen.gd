extends Control


func _ready():
	BackgroundMusic.stream = preload("res://resources/sounds/music/you_and_me_-_scp_fifthist_hub_old_am_radio_1.ogg")
	if !BackgroundMusic.is_playing():
		BackgroundMusic.play()


func _on_Timer_timeout():
	OS.shell_open("https://github.com/Mooses2k/SecretHistories/wiki/Credits") 
	get_tree().quit()
