# Pins the death screen port (3.x scenes/characters/player/player_death.gd on
# origin/main, minus the camera work that stays with issue #414's character
# lane): the DEAD state routes through GameUI into the sequence, the screen
# pauses the tree, plays the 3.x sound, covers with black, reveals the
# grayscale scene after the 3.x 1.5 s delay, and fades out on input. The test
# stops before the actual scene change: the tail (unpause plus change_scene)
# frees the death screen mid-wait in the harness so the GUT runner is never
# replaced.
extends GutTest

const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _ui : GameUI
var _world : Node3D
var _game : Game
var _saved_game : Game
var _saved_is_player_dead : bool
var _saved_paused : bool


func before_each() -> void:
	_saved_game = GameManager.game
	_saved_is_player_dead = GameManager.is_player_dead
	_saved_paused = get_tree().paused
	# Hotbar slots inside the real game_ui scene read GameManager.game in
	# _ready; a bare Game stub whose player is null makes them await
	# player_spawned quietly instead of erroring.
	_game = Game.new()
	GameManager.game = _game
	_ui = UI_SCENE.instantiate()
	add_child_autofree(_ui)
	# The real scene carries a working %HUD; without ui_root wired up the
	# player's interact_controller errors every tick on the Nil chain.
	_game.ui_root = _ui


func after_each() -> void:
	GameManager.game = _saved_game
	GameManager.is_player_dead = _saved_is_player_dead
	get_tree().paused = _saved_paused
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _spawn_player(at : Vector3) -> Node3D:
	_world = Node3D.new()
	add_child_autofree(_world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.5, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = at
	_world.add_child(player)
	_game.player = player
	await _physics_frames(5)
	return player


func _kill(player : Node3D) -> void:
	var hurtbox : Hurtbox = player.find_children("*", "Hurtbox", true, false)[0]
	hurtbox.damage(1000, GlobalConsts.AttackTypes.BLUDGEONING)


func test_death_routes_into_the_sequence_and_pauses_the_tree() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	assert_false(death_screen.get_node("BlackRect").visible, "sanity: the cover is down while alive")
	# connect through the production observation route like the blood tests
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(2)
	assert_true(GameManager.is_player_dead, "the death flag is set before anything else runs")
	assert_true(get_tree().paused, "the tree is paused with the corpse frozen")
	assert_true(death_screen.get_node("BlackRect").visible, "the black cover is up")
	var sound : AudioStreamPlayer = death_screen.get_node("DeathSound")
	assert_almost_eq(sound.pitch_scale, 1.74, 0.001, "the death sound keeps the 3.x pitch")
	assert_almost_eq(sound.volume_db, 20.263, 0.001, "the death sound keeps the 3.x volume")
	assert_false(death_screen.get_node("BWRect").visible, "the grayscale reveal waits out the delay")


func test_grayscale_reveal_fades_the_black_cover_out() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	var black : ColorRect = death_screen.get_node("BlackRect")
	var bw : ColorRect = death_screen.get_node("BWRect")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(2)
	# the 3.x delay is 1.5 s (about 90 frames at 60 fps), then the 0.5 s fade
	await _physics_frames(140)
	assert_true(bw.visible, "the grayscale shader layer reveals after 1.5 s")
	assert_almost_eq(black.modulate.a, 0.0, 0.05, "the black cover fades out under the reveal")


func test_input_fades_back_to_black_but_the_tail_stays_out_of_the_test() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	var black : ColorRect = death_screen.get_node("BlackRect")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(140)
	assert_almost_eq(black.modulate.a, 0.0, 0.05, "sanity: the reveal is showing")
	# a pressed key starts the 0.7 s fade back to black
	death_screen._input(_make_key_press())
	await _physics_frames(30)
	assert_true(black.modulate.a > 0.3, "the input fades the cover back in")
	assert_true(get_tree().paused, "the tree stays paused through the fade")
	# free the screen before the tail (unpause plus scene change) runs so the
	# GUT runner scene is never replaced
	_world.free()
	_world = null
	_ui.free()
	await _physics_frames(5)


func _make_key_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = KEY_SPACE
	return event
