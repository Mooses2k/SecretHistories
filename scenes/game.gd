class_name Game
extends Node

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal level_loaded(level)
signal player_spawned(player)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# Floor levels go from 0 to -4, so 5 possible floors per dungeon.
const MIN_FLOOR_LEVEL = -4

#--- public variables - order: export > normal var > onready --------------------------------------

export var start_level_scn : PackedScene
export var player_scn : PackedScene

var player
var level : GameWorld

onready var world_root : Node = $World
onready var ui_root : CanvasLayer = $GameUI
onready var local_settings : SettingsClass = $"%LocalSettings"

#--- private variables - order: export > normal var > onready -------------------------------------

var _current_floor_level := 0

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

func _init():
	GameManager.game = self
	var _error = connect("level_loaded", self, "_on_level_loaded")


func _ready():
	yield(get_tree().create_timer(1), "timeout")
	load_level(start_level_scn)
	BackgroundMusic.stop()   # Just in case

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func load_level(packed : PackedScene):
	level = packed.instance() as GameWorld
	world_root.add_child(level)
	level.create_world()
	yield(level, "spawning_world_scenes_finished")
	emit_signal("level_loaded", level)


func spawn_player():
	player = player_scn.instance()
	player.translation = level.get_player_spawn_position()
	world_root.call_deferred("add_child", player)
	yield(player, "ready")
	emit_signal("player_spawned", player)
	LoadScene.emit_signal("scene_loaded")

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _on_level_loaded(_level : GameWorld):
	spawn_player()
	
	if not Events.is_connected("up_staircase_used", self, "_on_Events_up_staircase_used"):
		# warning-ignore:return_value_discarded
		Events.connect("up_staircase_used", self, "_on_Events_up_staircase_used")
	
	if not Events.is_connected("down_staircase_used", self, "_on_Events_down_staircase_used"):
		# warning-ignore:return_value_discarded
		Events.connect("down_staircase_used", self, "_on_Events_down_staircase_used")


func _on_Events_up_staircase_used() -> void:
	var old_value := _current_floor_level
	_current_floor_level = int(min(0, _current_floor_level + 1))
	var has_changed := old_value != _current_floor_level
	
	if has_changed:
		print("Floor level changed from: %s to: %s"%[old_value, _current_floor_level])
	elif _current_floor_level == 0:
		print("You're already at the top of the dungeon, can't go upper.")


func _on_Events_down_staircase_used() -> void:
	var old_value := _current_floor_level
	_current_floor_level = int(max(MIN_FLOOR_LEVEL, _current_floor_level - 1))
	var has_changed := old_value != _current_floor_level
	
	if has_changed:
		print("Floor level changed from: %s to: %s"%[old_value, _current_floor_level])
		
	elif _current_floor_level == MIN_FLOOR_LEVEL:
		print("You're already at the bottom of the dungeon, can't go lower.")

### -----------------------------------------------------------------------------------------------
