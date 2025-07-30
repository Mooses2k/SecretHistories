extends Node
class_name ScreenFilters

@onready var world_environment: WorldEnvironment = %WorldEnvironment

@export var _compositor_effects : Array[CompositorEffect]

var compositor : Compositor = Compositor.new()

func clear_effects() -> void:
	_compositor_effects.clear()
	compositor.compositor_effects = _compositor_effects

func get_effect_by_type(type : Script) -> Array[CompositorEffect]:
	return _compositor_effects.filter(func(effect : CompositorEffect) -> bool: return effect.get_script() == type)

func push_effect(effect : CompositorEffect) -> void:
	_compositor_effects.push_back(effect)
	compositor.compositor_effects = _compositor_effects

func remove_effect(effect : CompositorEffect) -> void:
	_compositor_effects.erase(effect)
	compositor.compositor_effects = _compositor_effects

func _ready() -> void:
	compositor.compositor_effects = _compositor_effects
	var effects := compositor.compositor_effects
	compositor.compositor_effects = effects
	world_environment.compositor = compositor
