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

var world_gen_rng: RandomNumberGenerator = null 

func _ready() -> void:
	randomize()
