extends Node

# Screen filter section
enum ScreenFilter {
	NONE,
	OLD_FILM,
	PIXELATE,
	DITHER,
	REDUCE_COLOR,
	PSX,
	DEBUG_LIGHT
}

var game : Game
var act = 0   # the game has five Acts/Chapters
var is_player_dead = false


func _ready() -> void:
	randomize()
