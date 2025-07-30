extends Node
class_name ScreenFilters

@onready var world_environment: WorldEnvironment = %WorldEnvironment
@export var screen_filter_psx : ScreenFilterPSX

var compositor : Compositor = Compositor.new()

func _ready() -> void:
	var effects := compositor.compositor_effects
	effects.push_back(screen_filter_psx)
	compositor.compositor_effects = effects
	world_environment.compositor = compositor
	print("added ", screen_filter_psx, " to ", compositor)
