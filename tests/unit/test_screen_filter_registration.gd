# Pins the CompositorEffect registration behind the L screen-filter cycle:
# every filter effect constructs headless-tolerant (dummy renderer) at the
# docs-pinned POST_TRANSPARENT stage and starts disabled, the controller's
# registration lands exactly the five effects on a real ScreenFilters
# compositor (reusing a pre-seeded color reduce instead of duplicating), and
# each cycle stop flips enabled on exactly its own registered effect, the
# flag the renderer reads in a real Forward+ frame.
extends GutTest

var _saved_game : Game
var _game : Game
var _controller : ScreenFilterController
var _light : SpotLight3D


func before_each() -> void:
	# Bare Game stub: current_floor_level defaults to HIGHEST_FLOOR_LEVEL and
	# screen_filters stays null, so the controller's own _build_effects stays
	# inert and the tests drive the registration seam directly.
	_saved_game = GameManager.game
	_game = Game.new()
	GameManager.game = _game
	_controller = ScreenFilterController.new()
	_light = SpotLight3D.new()
	_light.visible = false
	add_child_autofree(_light)
	add_child_autofree(_controller)
	_controller.setup(_light)


func after_each() -> void:
	GameManager.game = _saved_game
	if _game != null:
		_game.free()
		_game = null
	_controller = null
	_light = null


## A real ScreenFilters node plus the uniquely-named WorldEnvironment its
## script attaches to: assembled off-tree with owners set, then entered, so
## the scene's own _ready attach path runs (the same shape game.tscn gives
## them).
func _make_filters_rig() -> ScreenFilters:
	var holder : Node = Node.new()
	var we : WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	holder.add_child(we)
	we.owner = holder
	we.unique_name_in_owner = true
	var rig : ScreenFilters = ScreenFilters.new()
	holder.add_child(rig)
	rig.owner = holder
	add_child_autofree(holder)
	return rig


func _registered_effects(rig : ScreenFilters) -> Array[CompositorEffect]:
	return rig.world_environment.compositor.compositor_effects


func _effect_of(rig : ScreenFilters, type : Script) -> CompositorEffect:
	var found := rig.get_effect_by_type(type)
	return found[0] if found.size() > 0 else null


func test_every_filter_effect_constructs_headless_at_the_post_transparent_stage() -> void:
	var effects : Array[CompositorEffect] = [
		ScreenFilterColorReduce.new(),
		ScreenFilterPSX.new(),
		ScreenFilterOldFilm.new(),
		ScreenFilterPixelate.new(),
		ScreenFilterDither.new(),
	]
	for effect in effects:
		assert_false(effect.enabled, "a fresh filter effect starts disabled")
		assert_eq(effect.effect_callback_type,
				CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT,
				"the effect registers at the POST_TRANSPARENT stage")


func test_registration_lands_all_five_effects_on_the_world_environment_compositor() -> void:
	var rig := _make_filters_rig()
	assert_eq(_registered_effects(rig).size(), 0, "a fresh rig carries no effects")
	_controller._register_effects(rig)
	var effects := _registered_effects(rig)
	assert_eq(effects.size(), 5, "exactly five filter effects are registered")
	assert_eq(rig.world_environment.compositor, rig.compositor,
			"the ScreenFilters attach owns the WorldEnvironment compositor")
	for effect in effects:
		assert_false(effect.enabled, "registration leaves every filter disabled")
		assert_eq(effect.effect_callback_type,
				CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT,
				"every registered effect runs at the POST_TRANSPARENT stage")


func test_registration_reuses_a_pre_seeded_color_reduce_instead_of_duplicating() -> void:
	var rig := _make_filters_rig()
	var seeded : CompositorEffect = ScreenFilterColorReduce.new()
	rig.push_effect(seeded)
	_controller._register_effects(rig)
	assert_eq(_registered_effects(rig).size(), 5,
			"the seeded color reduce counts toward the five, no duplicate")
	assert_eq(rig.get_effect_by_type(ScreenFilterColorReduce).size(), 1)
	assert_true(_registered_effects(rig).has(seeded),
			"the registered set is the seeded instance")


func test_each_cycle_stop_enables_exactly_its_own_registered_effect() -> void:
	var rig := _make_filters_rig()
	_controller._register_effects(rig)
	var stops := [
		[GameManager.ScreenFilter.OLD_FILM, ScreenFilterOldFilm],
		[GameManager.ScreenFilter.PIXELATE, ScreenFilterPixelate],
		[GameManager.ScreenFilter.DITHER, ScreenFilterDither],
		[GameManager.ScreenFilter.REDUCE_COLOR, ScreenFilterColorReduce],
		[GameManager.ScreenFilter.PSX, ScreenFilterPSX],
	]
	for stop in stops:
		_controller.set_filter_to(stop[0])
		for effect in _registered_effects(rig):
			var wanted : bool = effect.get_script() == stop[1]
			assert_eq(effect.enabled, wanted,
					"stop %d: %s enabled state" % [stop[0], effect.get_script().resource_path.get_file()])
	# NONE and the light stop disable every shader effect.
	for stop_value in [GameManager.ScreenFilter.NONE, GameManager.ScreenFilter.DEBUG_LIGHT]:
		_controller.set_filter_to(stop_value)
		for effect in _registered_effects(rig):
			assert_false(effect.enabled, "stop %d disables every shader effect" % stop_value)
	_controller.set_filter_to(GameManager.ScreenFilter.DEBUG_LIGHT)
	assert_true(_light.visible, "the light stop still owns the debug light")
