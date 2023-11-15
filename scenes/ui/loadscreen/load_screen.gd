extends CanvasLayer


var random_num_gen = RandomNumberGenerator.new()
var random_num

var is_loading = true
var clicked = false

onready var color_rect = get_node("ColorRect")
onready var label = get_node("Label")
onready var quote = get_node("Holder/Quote")


func _input(event: InputEvent):
	if (
			(
				(event is InputEventMouseButton and event.is_pressed())
				or event.is_action_released("ui_accept")
			)
			and not is_loading
	):
#		var _error = get_tree().change_scene(LoadScene.next_scene)
		if !clicked:   # Without this, clicking many times will cause crash in load_scene
			LoadScene.remove_loadscreen()
			clicked = true


func _ready():
#	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	LoadScene.connect("scene_loaded", self, "on_scene_loaded")

	random_num_gen.randomize()
	if GameManager.act > 4:
		# late game
		random_num = random_num_gen.randi_range(0, LoadQuotes.list3.size()-1)
		quote.text = LoadQuotes.list3[random_num]
	if GameManager.act > 2:
		# mid game
		random_num = random_num_gen.randi_range(0, LoadQuotes.list2.size()-1)
		quote.text = LoadQuotes.list2[random_num]
	else:
		# early game
		random_num = random_num_gen.randi_range(0, LoadQuotes.list1.size()-1)
		quote.text = LoadQuotes.list1[random_num]


func on_scene_loaded():
	is_loading = false
	$Label.text = "Click to Continue"
