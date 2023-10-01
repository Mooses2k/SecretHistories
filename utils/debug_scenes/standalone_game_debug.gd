# Write your doc string for this file here
extends Game

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

export(int, -55555, 55555, 1) var world_seed := 0
export var _window_size := Vector2(1280, 720)
export var _window_position := Vector2.ZERO
export(GameManager.ScreenFilter) var _screen_filter := GameManager.ScreenFilter.DEBUG_LIGHT

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	if get_tree().current_scene == self:
		# warning-ignore:return_value_discarded
		local_settings.add_int_setting("World Seed", -55555, 55555, 1, world_seed)
		local_settings.set_setting_group("World Seed", "Generation Settings")
		local_settings.set_setting_meta("World Seed", local_settings._CAN_RANDOMIZE_FLAG, true)
		OS.window_fullscreen = false
		OS.window_size = _window_size
		OS.window_position = _window_position
		LoadQuotes.load_files()
		LoadScene.setup_loadscreen()
		# warning-ignore:return_value_discarded
		LoadScene.connect("loading_screen_removed", self, "_on_LoadScene_loading_screen_removed")
		GameManager.is_player_dead = false
		GameManager.act = 1

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func spawn_player():
	.spawn_player()
	Events.call_deferred("emit_signal", "debug_filter_forced", GameManager.ScreenFilter.DEBUG_LIGHT)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _hide_debug_labels() -> void:
	var event := InputEventAction.new()
	event.action = "misc|help_info"
	event.pressed = true
	Input.parse_input_event(event)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _on_LoadScene_loading_screen_removed() -> void:
	_hide_debug_labels()

### -----------------------------------------------------------------------------------------------
