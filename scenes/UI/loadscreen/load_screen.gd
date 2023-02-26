extends CanvasLayer


var randomNumG = RandomNumberGenerator.new()
var randomNum

onready var label = get_node("Holder/Quote")
var is_loading = true


func _input(event):
	if event is InputEvent and event.is_pressed() and not is_loading:
#		var _error = get_tree().change_scene(LoadScreen.next_scene)
		LoadScreen.remove_loadscreen()


func _ready():
	LoadScreen.connect("scene_loaded", self, "on_scene_loaded")
	
	randomNumG.randomize()

	if GameManager.act > 2:
		#late game
		randomNum = randomNumG.randi_range(0, LoadQuotes.list2.size()-1)
		label.text = LoadQuotes.list2[randomNum]
	else:
		#early game
		randomNum = randomNumG.randi_range(0, LoadQuotes.list1.size()-1)
		label.text = LoadQuotes.list1[randomNum]


func on_scene_loaded():
	get_tree().paused = false
	is_loading = false
	$Label.text = "Click to Continue"
