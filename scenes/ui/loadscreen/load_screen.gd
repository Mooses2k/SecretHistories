extends CanvasLayer
class_name LoadScreen
# TODO: stop making a generator everywhere, having a global one is more performant and uses less memory
# TODO: when the level generator works, add this scene on top of the game scene and show + run it 
#       whenever it's time to get the new level, waiting not for loading, but generation
var random_num_gen = RandomNumberGenerator.new()
var random_num
const DEFAULT_PATH_TO_STARTUP = "res://scenes/ui/opening_screens.tscn"
var loading_done : bool = false
var next_scene_path : String = ""
var next_scene : PackedScene
var error
@onready var color_rect = $ColorRect
@onready var label = $Label
@onready var quote = $Holder/Quote
@onready var load_timer : Timer = $LoadTimer

signal clicked


func _input(event: InputEvent):
	if (event is InputEventMouseButton and event.is_pressed() and loading_done):
		loading_done = false 
		handle_external_settings()
		fade_in()
		await clicked
		LoadScene.clear_data()
		##For when changing to a different scene, so we spawned the load screen
		# with the LoadScene.change_scene_to_file()
		if(LoadScene.target_node == null):
			if(next_scene != null): #Extra safety
				LoadScene.clear_data()
				get_tree().change_scene_to_packed(next_scene)
		##For when loading an existing level and adding it to the world (not generating, but loading)
		elif (LoadScene.target_node != null):
			LoadScene.target_node.add_child(next_scene.instantiate())
			LoadScene.clear_data()
			#clear_data()


func start_loading():
	#With the suggestion from line 3, this is not required anymore. 
	#The randomize method is somewhat expensive to run, so running it 
	#only once on the global one it should be much easier
	random_num_gen.randomize()
	show_message()
	load_scene()
	load_timer.start()


func load_scene():
	next_scene_path = LoadScene.next_scene
	#TODO: remove next line once no longer required by other ui parts waiting for loads
	if(next_scene_path.is_empty()):
		get_tree().change_scene_to_file(DEFAULT_PATH_TO_STARTUP)
		return
	else:
		error = ResourceLoader.load_threaded_request(next_scene_path)


func show_message():
	setup_loading_screen()
	#Level 2, or 4 or whatever would be better as predefined constants
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
	
	show()
	#get_tree().paused = true


func _on_load_timer_timeout():
	#Every 0.5s, check if the next scene has loaded yet
	var progress = []
	match ResourceLoader.load_threaded_get_status(next_scene_path, progress):
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS: 
			#This could be an update to something if required, like a progress bar, 
			#or just showing the percentage
			print("Still loading, " + str(progress[0]) + "% done")
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			printerr("PANIC, can't load " + next_scene_path)
			get_tree().change_scene_to_file(DEFAULT_PATH_TO_STARTUP)
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
			printerr("PANIC, BAD or NO Resource " + next_scene_path)
			get_tree().change_scene_to_file(DEFAULT_PATH_TO_STARTUP) 
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			print("Good, loaded next scene! ")
			load_timer.stop()
			next_scene = ResourceLoader.load_threaded_get(next_scene_path)
			finish_loading()
	if !loading_done:
		load_timer.start()


func finish_loading():
	loading_done = true
	label.text = "Click to Continue"


func clear_data():
	loading_done = false
	next_scene_path = ""
	next_scene = null
	LoadScene.clear_data()


func setup_loading_screen():
	label.text = "Loading..."
	color_rect.modulate = Color.from_hsv(1,1,1,1)
	LoadScene.loading = true
	loading_done = false


func handle_external_settings():
	AudioSettings.internal_effects_volume = 0.0
	
	get_tree().create_tween()\
		.tween_property(AudioSettings, "internal_effects_volume", 1.0, 5.0)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)
		
	if GameManager.game != null and GameManager.game.player != null:
		GameManager.game.player.player_controller.no_click_after_load_period = true
		await get_tree().create_timer(1).timeout   # Possibly 0.5 better?
		GameManager.game.player.player_controller.no_click_after_load_period = false


func fade_in():
	#hide the texts to show black screen
	label.text = ""
	quote.text = ""
	color_rect.modulate = Color.from_hsv(1,1,1,1)
	get_tree().paused = false
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(color_rect, "modulate", Color.from_hsv(1,1,1,0), 1)
	await tween.finished
	clicked.emit()
