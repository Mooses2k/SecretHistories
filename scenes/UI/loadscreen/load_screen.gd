extends Node

onready var label = get_node("Holder/Quote")

var randomNumG = RandomNumberGenerator.new()
var randomNum


func _input(event):
	if event is InputEvent and event.is_pressed():
		var _error = get_tree().change_scene(ChangeScene.next_scene)


func _ready():
	randomNumG.randomize()

	if GameManager.act > 2:
		#late game
		randomNum = randomNumG.randi_range(0, LoadQuotes.list2.size()-1)
		label.text = LoadQuotes.list2[randomNum]
	else:
		#early game
		randomNum = randomNumG.randi_range(0, LoadQuotes.list1.size()-1)
		label.text = LoadQuotes.list1[randomNum]


