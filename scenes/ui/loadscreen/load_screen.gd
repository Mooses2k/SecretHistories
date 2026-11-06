extends CanvasLayer
class_name LoadScreen

# TODO: stop making a generator everywhere, having a global one is more performant and uses less memory
# TODO: when the level generator works, add this scene on top of the game scene and show + run it
#       whenever it's time to get the new level, waiting not for loading, but generation

var random_num_gen = RandomNumberGenerator.new()
var random_num
const DEFAULT_PATH_TO_STARTUP = "res://scenes/ui/opening_screens.tscn"
# Settle grace (owner: A/B testable, 1-3s band, 5s total ceiling): fixed unpaused time
# before "Click to Continue" so world settling (falling objects, glitchy lids) happens
# behind the opaque screen instead of at reveal.
const SETTLE_GRACE_SECONDS : float = 2.0
# How long after the reveal rapid drop-sound deletion is active (owner: 5s total, no more).
const EFFECTS_GRACE_MS : int = 5000
# Floor for the Voice reveal ramp writes: inaudible, and immune to the NaN that
# linear_to_db produces on the tween's tiny negative first-step progress values.
const SILENT_FLOOR_DB : float = -80.0
var loading_done : bool = false
# True while this screen holds the pre-click game-bus mute (see _mute_game_buses).
var _buses_muted : bool = false
var next_scene_path : String = ""
var next_scene : PackedScene
var error
@onready var color_rect = $ColorRect
@onready var label = $Label
@onready var quote = $Holder/Quote
@onready var load_timer : Timer = $LoadTimer

signal clicked


func _ready():
	# The load screen must keep processing while the tree is paused behind it
	# (input, timer, unpause). Owner ruling: the game must not tick while
	# "Click to Continue" is up; the world is paused behind the opaque screen.
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	# With the suggestion from line 3, this is not required anymore.
	# The randomize method is somewhat expensive to run, so running it
	# only once on the global one it should be much easier
	random_num_gen.randomize()
	show_message()
	load_scene()
	load_timer.start()


func load_scene():
	next_scene_path = LoadScene.next_scene
	# TODO: remove next line once no longer required by other ui parts waiting for loads
	if(next_scene_path.is_empty()):
		get_tree().change_scene_to_file(DEFAULT_PATH_TO_STARTUP)
		return
	else:
		error = ResourceLoader.load_threaded_request(next_scene_path)


func show_message():
	setup_loading_screen()
	# Quote lists load lazily in title_menu (LoadQuotes.load_files()); spawns
	# that reach the load screen without that path hold empty lists, and
	# randi_range(0, -1) plus the index access error out (PackedStringArray
	# index 0 on empty). Load here if needed, and leave the quote line blank
	# if the lists are still empty (missing txt files).
	if LoadQuotes.list1.is_empty() and LoadQuotes.list2.is_empty():
		LoadQuotes.load_files()
	# Level 2, or 4 or whatever would be better as predefined constants
	# (list3 for the late-game act>4 branch does not exist yet in LoadQuotes;
	# restore that branch when the list ships.)
	if GameManager.act > 2:
		# mid game
		if not LoadQuotes.list2.is_empty():
			random_num = random_num_gen.randi_range(0, LoadQuotes.list2.size()-1)
			quote.text = LoadQuotes.list2[random_num]
	else:
		# early game
		if not LoadQuotes.list1.is_empty():
			random_num = random_num_gen.randi_range(0, LoadQuotes.list1.size()-1)
			quote.text = LoadQuotes.list1[random_num]

	show()
	#get_tree().paused = true


func _on_load_timer_timeout():
	# Every 0.5s, check if the next scene has loaded yet
	var progress = []
	match ResourceLoader.load_threaded_get_status(next_scene_path, progress):
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			# This could be an update to something if required, like a progress bar,
			# or just showing the percentage
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
	# Settle grace: let physics run unpaused behind the opaque screen so misplaced
	# objects and lids come to rest before the reveal (owner: settle is intentional,
	# but it must not be seen or heard at start).
	await get_tree().create_timer(SETTLE_GRACE_SECONDS).timeout
	# Owner ruling: the game should not start ticking before the click happens.
	# Full tree pause behind the Click to Continue screen: no AI, no actions,
	# no lamp burn, no sounds. Music keeps playing (BackgroundMusic is PROCESS_MODE_ALWAYS).
	get_tree().paused = true
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
	# Owner ruling: nothing audible before the Click to Continue except music.
	# Mute every non-music bus for the whole loading phase (world gen, settle
	# grace, tree pause). Lifted at the click in handle_external_settings.
	_mute_game_buses(true)


# TODO: This was a way to try to hide drop sounds from playing a lot during level start
func handle_external_settings():
	# Owner: this 5s internal-effects mute ramp is wanted IN ADDITION to the tree
	# pause and settle grace; it covers residual settling jank right after the
	# reveal (sarco lid settling and similar).
	AudioSettings.internal_effects_volume = 0.0
	# Park the Voice bus at silence while it is still muted, then lift the
	# pre-click bus mutes. Cultist speech now enters through its own 5s ramp
	# below instead of popping in at full volume (owner: "cultist speech
	# wasn't faded in too").
	_apply_voice_reveal_ramp(0.0)
	_mute_game_buses(false)

	# Reveal window: rapid drop-sound deletion is active for EFFECTS_GRACE_MS
	# after the reveal (impact_audio_manager.gd reads this).
	LoadScene.effects_grace_until_ms = Time.get_ticks_msec() + EFFECTS_GRACE_MS

	var tween = get_tree().create_tween()
	# Keep the ramp running even while the tree is briefly paused during the fade.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(AudioSettings, "internal_effects_volume", 1.0, 5.0)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)

	# Same 5s reveal ramp for the Voice bus so speech fades in with the
	# effects instead of starting at full volume.
	var voice_tween = get_tree().create_tween()
	voice_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	voice_tween.tween_method(_apply_voice_reveal_ramp, 0.0, 1.0, 5.0)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)
	#if GameManager.game != null and GameManager.game.player != null:
		#GameManager.game.player.player_controller.no_click_after_load_period = true
		#await get_tree().create_timer(1).timeout   # Possibly 0.5 better?
		#GameManager.game.player.player_controller.no_click_after_load_period = false


## Owner ruling: while a load runs, nothing may be audible before the
## "Click to Continue" except music. Mute every bus except Master and Music
## (music keeps playing; Master carries it). The current layout makes this
## Effects + Voice, which covers item lighting, footsteps, impacts, doors and
## cultist speech. New buses are covered automatically.
## Bus mute, not bus volume: it overrides whatever the volume sliders write
## during loading, and the sliders keep working again once unmuted.
func _mute_game_buses(muted : bool):
	for bus_idx in AudioServer.bus_count:
		var bus : String = AudioServer.get_bus_name(bus_idx)
		if bus == "Master" or bus == "Music":
			continue
		AudioServer.set_bus_mute(bus_idx, muted)
	_buses_muted = muted


## Fade the Voice bus in with the same 5s reveal ramp as the Effects bus.
## Reads the live Voice setting every step, so the ramp always converges on
## what the volume slider currently says.
func _apply_voice_reveal_ramp(progress : float):
	var voice_setting = AudioSettings.get_voice_volume()
	if voice_setting == null:
		voice_setting = AudioSettings.MAX_VALUE
	var target_linear : float = voice_setting / AudioSettings.MAX_VALUE
	# Godot's expo ease-in tween hands out tiny NEGATIVE progress values on its
	# first steps and linear_to_db(negative) is NaN, so floor every write at
	# -80 dB: the codebase's speech-off convention, inaudible either way.
	var db : float = linear_to_db(target_linear * progress)
	AudioServer.set_bus_volume_db(AudioSettings.bus_voice, maxf(db, SILENT_FLOOR_DB))


## Safety: if this screen leaves the tree mid-load (load failure bails to
## opening_screens, quit to menu), never leave the game buses muted.
func _exit_tree():
	if _buses_muted:
		_mute_game_buses(false)


# Hide the text to show black screen
func fade_in():
	label.text = ""
	quote.text = ""
	color_rect.modulate = Color.from_hsv(1,1,1,1)
	get_tree().paused = false
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(color_rect, "modulate", Color.from_hsv(1,1,1,0), 1)
	await tween.finished
	clicked.emit()
