class_name Game
extends Node

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal level_loaded(level)
signal player_spawned(player)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# Starts at -1 and goes down to -5 so that it's a but more intuitive to talk about the dungeon
# floors and because suposedly, 0 is ground level.
const HIGHEST_FLOOR_LEVEL = -1
const LOWEST_FLOOR_LEVEL = -5

#--- public variables - order: export > normal var > onready --------------------------------------

export var start_level_scn : PackedScene
export var player_scn : PackedScene
export var floor_sizes := {
	HIGHEST_FLOOR_LEVEL: 15,
	-2: 25,
	-3: 25,
	-4: 35,
	LOWEST_FLOOR_LEVEL: 55
}

var player
var level : GameWorld
var current_floor_level := HIGHEST_FLOOR_LEVEL

onready var world_root : Node = $World
onready var ui_root : CanvasLayer = $GameUI
onready var local_settings : SettingsClass = $"%LocalSettings"
onready var world_environment: WorldEnvironment = $WorldEnvironment

#--- private variables - order: export > normal var > onready -------------------------------------

# Keys are floor level indices and values are FloorLevelHandler objects or null.
var _loaded_levels := {}

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

func _init():
	GameManager.game = self


func _ready():
	set_brightness()
	for floor_index in range(HIGHEST_FLOOR_LEVEL, LOWEST_FLOOR_LEVEL - 1, -1):
		_loaded_levels[floor_index] = null
	
	yield(get_tree().create_timer(1), "timeout")
	var _error = connect("level_loaded", self, "_on_first_level_loaded", [], CONNECT_ONESHOT)
	load_level(start_level_scn)
	BackgroundMusic.stop()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func set_brightness():
	# Set game brightness/gamma
	world_environment.environment.tonemap_exposure = VideoSettings.brightness


func load_level(packed : PackedScene):
	if _loaded_levels[current_floor_level] == null:
		level = packed.instance() as GameWorld
		world_root.add_child(level)
		
		var is_lowest_level := current_floor_level == LOWEST_FLOOR_LEVEL
		var current_floor_size: int = floor_sizes[current_floor_level]
		level.create_world(is_lowest_level, current_floor_size)
		
		_loaded_levels[current_floor_level] = FloorLevelHandler.new(level, current_floor_level)
		yield(level, "spawning_world_scenes_finished")
	else:
		var level_handler: FloorLevelHandler = _loaded_levels[current_floor_level]
		level = level_handler.get_level_instance()
		world_root.add_child(level)
		# this needs a yield because this function is called from within another yield
		yield(get_tree(), "idle_frame")
	
	emit_signal("level_loaded", level)


func spawn_player():
	player = player_scn.instance()
	level.set_player_on_spawn_position(player, true)
	world_root.call_deferred("add_child", player)
	yield(player, "ready")
	emit_signal("player_spawned", player)
	
	LoadScene.emit_signal("scene_loaded")

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _connect_staircase_events() -> void:
	if not Events.is_connected("up_staircase_used", self, "_on_Events_up_staircase_used"):
		# warning-ignore:return_value_discarded
		Events.connect("up_staircase_used", self, "_on_Events_up_staircase_used")
	
	if not Events.is_connected("down_staircase_used", self, "_on_Events_down_staircase_used"):
		# warning-ignore:return_value_discarded
		Events.connect("down_staircase_used", self, "_on_Events_down_staircase_used")


func disconnect_staircase_events() -> void:
	if Events.is_connected("up_staircase_used", self, "_on_Events_up_staircase_used"):
		# warning-ignore:return_value_discarded
		Events.disconnect("up_staircase_used", self, "_on_Events_up_staircase_used")
	
	if Events.is_connected("down_staircase_used", self, "_on_Events_down_staircase_used"):
		# warning-ignore:return_value_discarded
		Events.disconnect("down_staircase_used", self, "_on_Events_down_staircase_used")

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _on_first_level_loaded(_level : GameWorld):
	spawn_player()
	
	_connect_staircase_events()


func _handle_floor_change(is_going_downstairs: bool) -> void:
	yield(_show_load_screen(), "completed")
	_handle_floor_levels()
	yield(load_level(start_level_scn), "completed")
	_set_new_position_for_player(is_going_downstairs)
	LoadScene.emit_signal("scene_loaded")


func _show_load_screen() -> void:
	LoadScene.setup_loadscreen()
	# Wait a bit so that the load screen is visible
	yield(get_tree().create_timer(0.1), "timeout")


func _handle_floor_levels() -> void:
	world_root.remove_child(level)
	level = null
	for floor_level in _loaded_levels:
		var level_handler := _loaded_levels[floor_level] as FloorLevelHandler
		if level_handler != null:
			level_handler.update_floor_data(current_floor_level)


func _set_new_position_for_player(is_going_downstairs: bool) -> void:
	level.set_player_on_spawn_position(player, is_going_downstairs)
	emit_signal("player_spawned", player)


func _on_Events_up_staircase_used() -> void:
	var old_value := current_floor_level
	current_floor_level = int(min(HIGHEST_FLOOR_LEVEL, current_floor_level + 1))
	var has_changed := old_value != current_floor_level
	
	if has_changed:
		print("Floor level changed from: %s to: %s" % [old_value, current_floor_level])
		yield(_handle_floor_change(false), "completed")
	elif current_floor_level == HIGHEST_FLOOR_LEVEL:
		if player.inventory.bulky_equipment is ShardOfTheComet:
			print("Win screen")
		else:
			print("You're already at the top of the dungeon, can't go up.")


func _on_Events_down_staircase_used() -> void:
	var old_value := current_floor_level
	current_floor_level = int(max(LOWEST_FLOOR_LEVEL, current_floor_level - 1))
	var has_changed := old_value != current_floor_level
	
	if has_changed:
		print("Went down from: %s to: %s" % [old_value, current_floor_level])
		yield(_handle_floor_change(true), "completed")
	elif current_floor_level == LOWEST_FLOOR_LEVEL:
		print("You're already at the bottom of the dungeon, can't go lower.")

### -----------------------------------------------------------------------------------------------
