extends Node


var game : Game
var act = 0
var is_player_dead = false
var is_reloading = false

func _ready() -> void:
	randomize()
