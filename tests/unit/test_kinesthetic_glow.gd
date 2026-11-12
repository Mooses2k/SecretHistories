extends GutTest
## The KinestheticSense darkness glow (3.x origin/main
## scenes/characters/player/player.gd:49-57 plus the player.tscn OmniLight):
## a cyan light on the player that tweens up to energy 0.2 while light_level
## is at or below the 0.003 sight-gate threshold and back to 0 in the light.
## The glow is Player-only (the node is authored on player.tscn) and the
## tween is recreated toward the target every process frame, matching the
## 3.x per-frame retargeting.

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")

var _world : Node3D
var _game : Game
var _saved_game : Game


func before_each() -> void:
	# Same stub set as test_light_level_sight.gd: the real player scene ticks
	# interact_controller, which reads GameManager.game.ui_root every frame.
	_saved_game = GameManager.game
	_game = Game.new()
	GameManager.game = _game
	var ui : GameUI = UI_SCENE.instantiate()
	add_child_autofree(ui)
	_game.ui_root = ui
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	GameManager.game = _saved_game
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


func _spawn_player() -> Node:
	var player : Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	player.freeze = true
	for i in 2:
		await get_tree().physics_frame
	return player


func _await_frames(count : int) -> void:
	for i in count:
		await get_tree().process_frame


# --------------------------------------------------------------------------
# The authored light (3.x player.tscn node truth)
# --------------------------------------------------------------------------
func test_player_scene_authors_the_kinesthetic_light() -> void:
	var player : Node = await _spawn_player()
	var light : OmniLight3D = player.get_node_or_null("KinestheticSense") as OmniLight3D
	assert_not_null(light, "player.tscn authors the KinestheticSense light")
	if light == null:
		return
	assert_eq(light.light_energy, 0.0, "the glow starts dark, 3.x light_energy 0.0")
	assert_eq(light.omni_range, 1.5, "3.x omni_range 1.5")
	assert_eq(light.light_color, Color(0.0, 0.647059, 1.0, 1.0),
		"3.x light_color, the cyan KinestheticSense tint")
	assert_eq(light.position, Vector3(0.0, 0.992437, 0.151953),
		"3.x player.tscn translation")


func test_bare_humanoid_has_no_kinesthetic_light() -> void:
	var base : Node = (load("res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn") as PackedScene).instantiate()
	add_child_autofree(base)
	await _await_frames(2)
	assert_null(base.get_node_or_null("KinestheticSense"),
		"the glow is Player-only, 3.x mounted it on player.tscn")


# --------------------------------------------------------------------------
# The tween driver (3.x player.gd _process truth)
# --------------------------------------------------------------------------
func test_glow_rises_in_darkness() -> void:
	var player : Node = await _spawn_player()
	var light : OmniLight3D = player.get_node("KinestheticSense") as OmniLight3D
	player.light_level = 0.0
	await _await_frames(40)
	assert_true(light.light_energy > 0.05,
		"entering darkness tweens the glow toward the 0.2 dark energy (got %f)" % light.light_energy)
	assert_true(light.light_energy <= 0.2, "the dark target is capped at 0.2")


func test_glow_fades_in_light() -> void:
	var player : Node = await _spawn_player()
	var light : OmniLight3D = player.get_node("KinestheticSense") as OmniLight3D
	player.light_level = 0.0
	await _await_frames(40)
	var dark_energy : float = light.light_energy
	assert_true(dark_energy > 0.05, "precondition: the glow is up in darkness")
	player.light_level = 1.0
	# The tween is a 1.0 s exponential approach, 3.x restarts it every frame:
	# give it several seconds to fall back down.
	await _await_frames(240)
	assert_true(light.light_energy < dark_energy * 0.25,
		"returning to the light tweens the glow back toward 0 (got %f)" % light.light_energy)


func test_threshold_matches_the_sight_gate() -> void:
	var player : Node = await _spawn_player()
	var light : OmniLight3D = player.get_node("KinestheticSense") as OmniLight3D
	# Exactly at the 3.x threshold (light_level <= 0.003 is the dark branch).
	player.light_level = 0.003
	await _await_frames(40)
	assert_true(light.light_energy > 0.05,
		"at the 0.003 threshold the glow is on: 3.x used the strict > gate for lit")
	player.light_level = 0.004
	await _await_frames(240)
	assert_true(light.light_energy < 0.05,
		"just above the threshold the glow fades: 3.x lit branch")
