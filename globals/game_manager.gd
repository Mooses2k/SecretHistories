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
	# The editor Debug menu ("Visible Navigation") injects the navigation debug
	# hint into a game run, which draws white navmesh edge lines and closed
	# entry squares around the world. The game must never show engine
	# navigation debug, regardless of how it was launched.
	get_tree().set_debug_navigation_hint(false)
	NavigationServer3D.set_debug_enabled(false)

	randomize()


func _process(_delta: float) -> void:
	# Cheap bool checks every frame: whatever re-enables the engine navigation
	# debug after startup (editor launch flags, future engine hooks) cannot win.
	if get_tree().is_debugging_navigation_hint() or NavigationServer3D.get_debug_enabled():
		get_tree().set_debug_navigation_hint(false)
		NavigationServer3D.set_debug_enabled(false)
