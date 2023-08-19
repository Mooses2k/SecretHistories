extends CanvasLayer


var random_num_gen = RandomNumberGenerator.new()
var random_num

onready var label = get_node("Holder/Quote")
var is_loading = true


func _input(event):
	if event is InputEvent and event.is_pressed() and not is_loading:
#		var _error = get_tree().change_scene(LoadScene.next_scene)
		LoadScene.remove_loadscreen()


func _ready():
#	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	LoadScene.connect("scene_loaded", self, "on_scene_loaded")

	random_num_gen.randomize()
	if GameManager.act > 2:
		#late game
		random_num = random_num_gen.randi_range(0, LoadQuotes.list2.size()-1)
		label.text = LoadQuotes.list2[random_num]
	else:
		#early game
		random_num = random_num_gen.randi_range(0, LoadQuotes.list1.size()-1)
		label.text = LoadQuotes.list1[random_num]


func on_scene_loaded():
	is_loading = false
	$Label.text = "Click to Continue"
