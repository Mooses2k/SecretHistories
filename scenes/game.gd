class_name Game
extends Node

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal level_loaded(level)
signal player_spawned(player)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------


#--- public variables - order: export > normal var > onready --------------------------------------

export var start_level_scn : PackedScene
export var player_scn : PackedScene

var player
var level : GameWorld

onready var world_root : Node = $World
onready var ui_root : CanvasLayer = $GameUI
onready var local_settings : SettingsClass = $"%LocalSettings"

#--- private variables - order: export > normal var > onready -------------------------------------

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
	world_root.call_deferred("add_child", level)
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

### -----------------------------------------------------------------------------------------------
