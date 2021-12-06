extends Node

enum FullscreenMode {
	FULLSCREEN = 0,
	BORDERLESS_WINDOWED = 1,
	WINDOWED = 2
}
var fullscreen_mode : int setget set_fullscreen_mode

var vsync : bool
var brightness : float

var master_audio_enabled : bool
var sound_enabled : bool
var music_enabled : bool
var voice_enabled : bool

var master_audio_volume : float
var sound_volume : float
var music_volume : float
var voice_volume : float


func set_fullscreen_mode(value : int):
	fullscreen_mode = value
	match fullscreen_mode:
		FullscreenMode.FULLSCREEN:
			OS.window_fullscreen = true
			OS.window_borderless = false
		FullscreenMode.BORDERLESS_WINDOWED:
			OS.window_fullscreen = false
			OS.window_borderless = true
		FullscreenMode.WINDOWED:
			OS.window_fullscreen = false
			OS.window_borderless = false
