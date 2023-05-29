class_name Game
extends Node


signal level_loaded(level)
signal player_spawned(player)

export var start_level_scn : PackedScene
export var player_scn : PackedScene

var player
var level : GameWorld

onready var world_root : Node = $World
onready var UI_root : CanvasLayer = $GameUI
onready var local_settings : SettingsClass = $"%LocalSettings"


func _init():
	GameManager.game = self
	var _error = self.connect("level_loaded", self, "on_level_loaded")


func _ready():
	yield(get_tree().create_timer(1), "timeout")
	load_level(start_level_scn)


func load_level(packed : PackedScene):
	self.level = packed.instance() as GameWorld
	world_root.call_deferred("add_child", self.level)
	yield(self.level, "ready")
	self.emit_signal("level_loaded", self.level)


func on_level_loaded(_level : GameWorld):
	self.spawn_player()


func spawn_player():
	self.player = player_scn.instance()
	self.player.translation = self.level.get_player_spawn_position()
	world_root.call_deferred("add_child", self.player)
	yield(self.player, "ready")
	self.emit_signal("player_spawned", self.player)
	LoadScreen.emit_signal("scene_loaded")
