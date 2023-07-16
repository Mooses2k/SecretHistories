extends Node


var game : Game
var act = 0
var is_player_dead = false
var is_crouch_hold = false
var is_ads_hold = false
var mouse_sensitivity : float = 1


func _ready() -> void:
	randomize()
