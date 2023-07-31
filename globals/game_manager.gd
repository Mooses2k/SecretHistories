extends Node


var game : Game
var act = 0
var is_player_dead = false

var is_crouch_hold : bool = false
var is_ads_hold : bool = true
var mouse_sensitivity : float = 0.2
var master_volume : float = AudioServer.get_bus_volume_db(0)
var music_volume : float = AudioServer.get_bus_volume_db(1)
var effects_volume : float = AudioServer.get_bus_volume_db(2)
var voice_volume : float = AudioServer.get_bus_volume_db(3)
var full_screen : bool = OS.window_fullscreen
var gui_scale : float = 1.0


func _ready() -> void:
	randomize()
