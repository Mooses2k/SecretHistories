extends SceneTree

## Headless end-to-end smoke for the L screen-filter fix lane: the real
## player scene with its live PlayerController + ScreenFilterController +
## camera DebugLight, a real Game stub so the controller's poll gate
## (is_instance_valid(GameManager.game)) matches the in-game shape, and a
## real game_ui so the interact controller reads a live ui_root. Taps L
## through the whole cycle via the Input action state (the reliable headless
## instrument; the hardware-event match is pinned by InputMap.event_is_action
## in the probe evidence) and samples the cycle and the light after every
## tap. Prints PROBE lines, quits 0 on pass. NOTE: deliberately duck-typed:
## typed references to project scripts would drag them into this script's
## startup compile, before the autoload globals register.

const FILTER_ACTION := "misc|change_screen_filter"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const UI_SCENE := "res://scenes/ui/game_ui.tscn"
const GAME_SCRIPT := "res://scenes/game.gd"
const EXPECTED_CYCLE := [
	["OLD_FILM", 1],
	["PIXELATE", 2],
	["DITHER", 3],
	["REDUCE_COLOR", 4],
	["PSX", 5],
	["DEBUG_LIGHT", 6],
	["NONE", 0],
]

var _fails := 0


func _check(ok : bool, label : String) -> void:
	if not ok:
		_fails += 1
	print("PROBE ", ("PASS " if ok else "FAIL ") + label)


func _physics_frames(count : int) -> void:
	for i in count:
		await physics_frame


func _tap_action(action : String) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)
	await _physics_frames(2)


func _init() -> void:
	var iter := 0
	while Engine.get_main_loop() == null and iter < 40:
		await create_timer(0.05).timeout
		iter += 1
	await create_timer(0.5).timeout   # autoload boots (KeybindingManager.load_keys included)

	# --- 1. InputMap after the real boot sequence ---------------------------
	_check(InputMap.has_action(FILTER_ACTION), "action exists after boot")
	var has_l := false
	for event in InputMap.action_get_events(FILTER_ACTION):
		var key := event as InputEventKey
		if key != null and key.keycode == KEY_L:
			has_l = true
	_check(has_l, "action bound to keycode L after boot")

	# --- 2. The in-game shape: Game stub + real game_ui + real player -------
	var game : Node = load(GAME_SCRIPT).new()
	if game == null:
		print("PROBE FAIL game stub did not construct")
		print("PROBE RESULT=FAIL")
		quit(1)
		return
	var ui : Node = (load(UI_SCENE) as PackedScene).instantiate()
	root.add_child(ui)
	game.set("ui_root", ui)
	# Constructing the Game already registers it on the GameManager singleton
	# (game.gd _init), matching the in-game poll gate.
	var world : Node3D = Node3D.new()
	root.add_child(world)
	var player : Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	world.add_child(player)
	await _physics_frames(4)

	var controller : Node = player.get_node_or_null("PlayerController")
	_check(controller != null, "PlayerController node present on the spawned player")
	var sfc : Node = controller.get("screen_filter_controller") if controller != null else null
	_check(sfc != null, "ScreenFilterController mounted on PlayerController at spawn")
	var light : Node = player.get_node_or_null("ModelRoot/DebugLight")
	if light == null:
		light = player.get_node_or_null("ModelRoot/MainCamera/DebugLight")
	_check(light != null, "DebugLight present on the spawned player")
	if sfc == null or light == null:
		print("PROBE RESULT=FAIL")
		quit(1)
		return
	_check(sfc.get("current_filter") == 0, "cycle starts at NONE")
	_check(not light.visible, "debug light starts off")

	# --- 3. Seven L taps through the real poll -------------------------------
	for step in EXPECTED_CYCLE:
		await _tap_action(FILTER_ACTION)
		var expected : int = step[1]
		var name : String = step[0]
		_check(sfc.get("current_filter") == expected,
				"L tap lands on %s (filter %d)" % [name, sfc.get("current_filter")])
		var light_on : bool = light.visible
		if name == "DEBUG_LIGHT":
			_check(light_on, "DEBUG_LIGHT stop has the light on")
		elif name == "NONE":
			_check(not light_on, "wrap to NONE has the light off")

	print("PROBE RESULT=", "FAIL" if _fails > 0 else "PASS")
	quit(1 if _fails > 0 else 0)
