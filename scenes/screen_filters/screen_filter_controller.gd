extends Node
class_name ScreenFilterController

## Drives the 3.x screen-filter cycle for one player: the L key
## (misc|change_screen_filter) advances NONE -> OLD_FILM -> PIXELATE ->
## DITHER -> REDUCE_COLOR -> PSX -> DEBUG_LIGHT and wraps to NONE, the
## lowest floor forces REDUCE_COLOR once as the crystal-grab atmosphere
## cue, and debug_filter_forced applies an explicit filter (the standalone
## debug game uses it). Applies filters through the Game's CompositorEffect
## pipeline (scenes/screen_filters/screen_filters.gd); with no RenderingDevice
## (headless, dummy renderer) the state machine still runs and only the
## visual application is skipped.

const FILTER_ACTION := "misc|change_screen_filter"

var current_filter : int = GameManager.ScreenFilter.NONE
var changed_to_reduce_color : bool = false   # Have we changed to reduce color filter on DLvl5?

var _debug_light : SpotLight3D
var _color_reduce : CompositorEffect
var _old_film : CompositorEffect
var _pixelate : CompositorEffect
var _dither : CompositorEffect
var _psx : CompositorEffect
var _effects_built : bool = false


func setup(debug_light : SpotLight3D) -> void:
	_debug_light = debug_light


func _ready() -> void:
	Events.connect("debug_filter_forced", _on_debug_filter_forced)


func _exit_tree() -> void:
	Events.disconnect("debug_filter_forced", _on_debug_filter_forced)


func _on_debug_filter_forced(screen_filter : int) -> void:
	set_filter_to(screen_filter)


func handle_screen_filters() -> void:
	# 3.x parity (origin/main scenes/characters/player/player_controller.gd
	# handle_screen_filters): the lowest-floor force runs every frame before
	# the L poll, fires once ever (changed_to_reduce_color is never reset,
	# ascending does not reset it), and ends NONE -> REDUCE_COLOR.
	if is_instance_valid(GameManager.game):
		if GameManager.game.current_floor_level == Game.LOWEST_FLOOR_LEVEL:
			if current_filter != GameManager.ScreenFilter.REDUCE_COLOR and not changed_to_reduce_color:
				set_filter_to(GameManager.ScreenFilter.NONE)
				set_filter_to(GameManager.ScreenFilter.REDUCE_COLOR)
				changed_to_reduce_color = true
		if Input.is_action_just_pressed(FILTER_ACTION):
			# Cycle to next filter
			set_filter_to()


func set_filter_to(filter_value : int = -1) -> void:
	if filter_value == -1:
		current_filter = posmod(current_filter + 1, GameManager.ScreenFilter.size())
	else:
		current_filter = filter_value

	_apply_current_filter()


func _build_effects() -> void:
	if not is_instance_valid(GameManager.game) or GameManager.game.screen_filters == null:
		return
	if RenderingServer.get_rendering_device() == null:
		# Dummy renderer (headless runs): keep the state machine working,
		# there is nothing to apply to.
		return
	_effects_built = true
	_register_effects(GameManager.game.screen_filters)


## Creates (or reuses) the per-filter CompositorEffects and registers them
## on the Game's ScreenFilters compositor, the array the WorldEnvironment
## consumes in a real Forward+ frame. Takes the ScreenFilters node as a
## parameter so tests can pin the registration without a renderer.
func _register_effects(filters : ScreenFilters) -> void:
	var wired_color_reduce := filters.get_effect_by_type(ScreenFilterColorReduce)
	if wired_color_reduce.is_empty():
		_color_reduce = ScreenFilterColorReduce.new()
		filters.push_effect(_color_reduce)
	else:
		_color_reduce = wired_color_reduce[0]
	_psx = ScreenFilterPSX.new()
	filters.push_effect(_psx)
	_old_film = ScreenFilterOldFilm.new()
	filters.push_effect(_old_film)
	_pixelate = ScreenFilterPixelate.new()
	filters.push_effect(_pixelate)
	_dither = ScreenFilterDither.new()
	filters.push_effect(_dither)


func _set_only_active(active_filter : int) -> void:
	# One filter is enabled at a time; the others stay disabled so the
	# compositor passes through untouched.
	if _color_reduce != null:
		_color_reduce.enabled = active_filter == GameManager.ScreenFilter.REDUCE_COLOR
	if _psx != null:
		_psx.enabled = active_filter == GameManager.ScreenFilter.PSX
	if _old_film != null:
		_old_film.enabled = active_filter == GameManager.ScreenFilter.OLD_FILM
	if _pixelate != null:
		_pixelate.enabled = active_filter == GameManager.ScreenFilter.PIXELATE
	if _dither != null:
		_dither.enabled = active_filter == GameManager.ScreenFilter.DITHER


func _apply_current_filter() -> void:
	if not _effects_built:
		_build_effects()
	# The debug light is player-owned, so its stop behavior applies even when
	# there is no rendering pipeline (headless runs). The console readout is
	# the 3.x parity cue (origin/main player_controller.gd printed
	# "Screen Filter: <NAME>" on every stop).
	match current_filter:
		GameManager.ScreenFilter.NONE:
			_set_only_active(GameManager.ScreenFilter.NONE)
			print("Screen Filter: NONE")
			if _debug_light != null:
				_debug_light.visible = false
		GameManager.ScreenFilter.DEBUG_LIGHT:
			_set_only_active(GameManager.ScreenFilter.NONE)
			print("Screen Filter: DEBUG_LIGHT")
			if _debug_light != null:
				_debug_light.visible = true
		GameManager.ScreenFilter.OLD_FILM:
			_set_only_active(current_filter)
			print("Screen Filter: OLD_FILM")
		GameManager.ScreenFilter.PIXELATE:
			_set_only_active(current_filter)
			print("Screen Filter: PIXELATE")
		GameManager.ScreenFilter.DITHER:
			_set_only_active(current_filter)
			print("Screen Filter: DITHER")
		GameManager.ScreenFilter.REDUCE_COLOR:
			_set_only_active(current_filter)
			print("Screen Filter: REDUCE_COLOR")
		GameManager.ScreenFilter.PSX:
			_set_only_active(current_filter)
			print("Screen Filter: PSX")
