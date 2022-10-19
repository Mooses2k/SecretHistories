extends Node

const SAVEFILE = "user://savefile.save"

var game_data = {}

func _ready():
	load_data()


func load_data():
	var file = File.new()
	if not file.file_exists((SAVEFILE)):
		game_data = {
			"fullscreen": true,
			"vsync": true,
			"brightness": 0,
			"master_vol": 50,
			"sound_vol": 50,
			"music_vol": 50,
			"voice_vol": 50,
		}
		save_data()
	file.open(SAVEFILE, File.READ)
	game_data = file.get_var()
	file.close()


func save_data():
	var file = File.new()
	file.open(SAVEFILE, File.WRITE)
	file.store_var(game_data)
	file.close()
