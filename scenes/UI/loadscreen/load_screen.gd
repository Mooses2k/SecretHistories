extends Node

var list1 =  ["Test quote 1","Test quote 2","Test quote 3"]
var list2 =  ["Test quote 1 - late game","Test quote 2 - late game","Test quote 3 - late game","Test quote 4 - late game"]

onready var label = get_node("Quote")

var randomNumG = RandomNumberGenerator.new()
var randomNum


func _process(_delta):
	if Input.is_key_pressed(KEY_SPACE):
		var _error = get_tree().change_scene("res://scenes/UI/start_game_menu.tscn")


func _ready():
	randomNumG.randomize()

	if GameManager.level > 2:
		#late game
		randomNum = randomNumG.randi_range(0, 3)
		label.text = list2[randomNum]
		pass
	else:
		#early game
		randomNum = randomNumG.randi_range(0, 2)
		label.text = list1[randomNum]
		pass # Replace with function body.
		

