extends Node


var game : Game
var act = 0   # the game has five Acts/Chapters
var is_player_dead = false


func _ready() -> void:
	randomize()
