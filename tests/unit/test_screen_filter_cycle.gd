# Pins the 3.x screen filter cycle restored onto the CompositorEffect
# pipeline: L (misc|change_screen_filter) advances
# NONE -> OLD_FILM -> PIXELATE -> DITHER -> REDUCE_COLOR -> PSX -> DEBUG_LIGHT
# and wraps, the lowest floor (Game.LOWEST_FLOOR_LEVEL) forces REDUCE_COLOR
# once ever (ascending does not reset it, 3.x parity), and the
# debug_filter_forced bus signal applies an explicit filter. Headless runs
# have no RenderingDevice, so the visual application is skipped there and the
# state machine plus the debug light are the text truth.
extends GutTest

const FILTER_ACTION := "misc|change_screen_filter"

var _game : Game
var _saved_game : Game
var _controller : ScreenFilterController
var _light : SpotLight3D


func before_each() -> void:
	# Bare Game stub: current_floor_level defaults to HIGHEST_FLOOR_LEVEL and
	# screen_filters stays null, so the controller runs its state machine
	# without touching a rendering pipeline.
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
	if Input.is_action_pressed(FILTER_ACTION):
		Input.action_release(FILTER_ACTION)
	if _game != null:
		_game.free()
		_game = null
	_controller = null
	_light = null


func test_L_press_advances_the_cycle_through_the_3x_order() -> void:
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.NONE)
	var expected := [
		GameManager.ScreenFilter.OLD_FILM,
		GameManager.ScreenFilter.PIXELATE,
		GameManager.ScreenFilter.DITHER,
		GameManager.ScreenFilter.REDUCE_COLOR,
		GameManager.ScreenFilter.PSX,
		GameManager.ScreenFilter.DEBUG_LIGHT,
	]
	for step in expected.size():
		Input.action_press(FILTER_ACTION)
		await get_tree().physics_frame
		_controller.handle_screen_filters()
		Input.action_release(FILTER_ACTION)
		await get_tree().physics_frame
		assert_eq(_controller.current_filter, expected[step],
				"tap %d lands on %d" % [step + 1, expected[step]])


func test_cycle_wraps_back_to_none_after_the_debug_light() -> void:
	for i in GameManager.ScreenFilter.size():
		_controller.set_filter_to()
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.NONE,
			"seven stops wrap back to NONE")


func test_debug_light_turns_on_at_the_last_stop_and_off_after_the_wrap() -> void:
	for i in GameManager.ScreenFilter.PSX:
		_controller.set_filter_to()
	assert_false(_light.visible, "the light stays off through the shader stops")
	_controller.set_filter_to()   # -> DEBUG_LIGHT
	assert_true(_light.visible, "the last stop turns the debug light on")
	_controller.set_filter_to()   # -> NONE
	assert_false(_light.visible, "wrapping to NONE turns the debug light off")


func test_lowest_floor_forces_reduce_color_once() -> void:
	_game.current_floor_level = Game.LOWEST_FLOOR_LEVEL
	_controller.handle_screen_filters()
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.REDUCE_COLOR,
			"entering the lowest floor forces REDUCE_COLOR")
	assert_true(_controller.changed_to_reduce_color, "the one-shot flag is set")
	assert_false(_light.visible, "the force path passes NONE and leaves the light off")
	# Still REDUCE_COLOR on later frames while the filter stays.
	_controller.handle_screen_filters()
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.REDUCE_COLOR)


func test_ascending_does_not_reset_the_forcing() -> void:
	_game.current_floor_level = Game.LOWEST_FLOOR_LEVEL
	_controller.handle_screen_filters()
	_game.current_floor_level = Game.HIGHEST_FLOOR_LEVEL
	_controller.set_filter_to()   # REDUCE_COLOR cycles to PSX
	_controller.handle_screen_filters()
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.PSX,
			"ascending leaves the user-chosen filter alone")
	_game.current_floor_level = Game.LOWEST_FLOOR_LEVEL
	_controller.handle_screen_filters()
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.PSX,
			"returning to the lowest floor does not re-force REDUCE_COLOR")


func test_cycling_is_free_on_the_lowest_floor_after_the_first_force() -> void:
	_game.current_floor_level = Game.LOWEST_FLOOR_LEVEL
	_controller.handle_screen_filters()
	for i in 1:
		_controller.set_filter_to()   # REDUCE_COLOR cycles to PSX
	_controller.handle_screen_filters()
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.PSX,
			"after the one-shot force the player can cycle on the lowest floor")


func test_debug_filter_forced_signal_applies_an_explicit_filter() -> void:
	Events.debug_filter_forced.emit(GameManager.ScreenFilter.PSX)
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.PSX)
	Events.debug_filter_forced.emit(GameManager.ScreenFilter.OLD_FILM)
	assert_eq(_controller.current_filter, GameManager.ScreenFilter.OLD_FILM)


func test_every_stop_sets_state_without_error_and_none_leaves_it_clean() -> void:
	var stops := [
		GameManager.ScreenFilter.OLD_FILM,
		GameManager.ScreenFilter.PIXELATE,
		GameManager.ScreenFilter.DITHER,
		GameManager.ScreenFilter.REDUCE_COLOR,
		GameManager.ScreenFilter.PSX,
		GameManager.ScreenFilter.DEBUG_LIGHT,
		GameManager.ScreenFilter.NONE,
	]
	for stop in stops:
		_controller.set_filter_to(stop)
		assert_eq(_controller.current_filter, stop)
		if stop == GameManager.ScreenFilter.DEBUG_LIGHT:
			assert_true(_light.visible)
		elif stop == GameManager.ScreenFilter.NONE:
			assert_false(_light.visible)
