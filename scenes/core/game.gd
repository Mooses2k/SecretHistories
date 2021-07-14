class_name Game
extends Node

signal level_loaded(level)
signal player_spawned(player)

export var start_level_scn : PackedScene
export var player_scn : PackedScene

onready var world_root : Node = $World
onready var UI_root : Node = $UI

var player
var level : GameWorld

func _init():
	GameManager.game = self
	self.connect("level_loaded", self, "on_level_loaded")

func _ready():
	load_level(start_level_scn)
	pass

func load_level(packed : PackedScene):
	self.level = start_level_scn.instance() as GameWorld
	world_root.call_deferred("add_child", self.level)
	yield(self.level, "ready")
	self.emit_signal("level_loaded", self.level)

func on_level_loaded(level : GameWorld):
	self.spawn_player()

func spawn_player():
	self.player = player_scn.instance()
	world_root.call_deferred("add_child", self.player)
	yield(self.player, "ready")
	self.player.global_transform.origin = self.level.get_player_spawn_position()
	self.emit_signal("player_spawned", self.player)
