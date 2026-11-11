# Pins the death screen port (3.x scenes/characters/player/player_death.gd on
# origin/main) with the issue 414 ragdoll window in front of it: the DEAD
# state routes through GameUI into the sequence, the tree stays RUNNING while
# the cover fades in slowly behind the eye-closing stencil, the tree pauses
# only when the cover is down, the grayscale reveal follows the 3.x 1.5 s
# delay, and input fades out to the title. The test stops before the actual
# scene change: the tail (unpause plus change_scene) frees the death screen
# mid-wait in the harness so the GUT runner is never replaced.
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


func test_death_routes_into_the_sequence_and_starts_the_fade() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	assert_false(death_screen.get_node("BlackRect").visible, "sanity: the cover is down while alive")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(2)
	assert_true(GameManager.is_player_dead, "the death flag is set before anything else runs")
	assert_false(get_tree().paused,
		"the tree stays running through the ragdoll window (issue 414)")
	assert_true(death_screen.get_node("BlackRect").visible, "the black cover is rising")
	assert_lt(death_screen.get_node("BlackRect").modulate.a, 0.1,
		"the cover starts transparent and fades in slowly")
	assert_true(death_screen.get_node("LidTop").visible, "the top stencil lid is closing")
	assert_true(death_screen.get_node("LidBottom").visible, "the bottom stencil lid is closing")
	var sound : AudioStreamPlayer = death_screen.get_node("DeathSound")
	assert_almost_eq(sound.pitch_scale, 1.74, 0.001, "the death sound keeps the 3.x pitch")
	assert_almost_eq(sound.volume_db, 20.263, 0.001, "the death sound keeps the 3.x volume")


func test_the_stencil_and_cover_run_on_their_timer_then_the_tree_pauses() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	death_screen.death_fade_time = 1.0
	var black : ColorRect = death_screen.get_node("BlackRect")
	var lid_top : TextureRect = death_screen.get_node("LidTop")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(30)
	assert_gt(black.modulate.a, 0.0, "the cover fade is running")
	assert_gt(lid_top.offset_bottom, 0.0, "the stencil lid is travelling down")
	assert_false(get_tree().paused, "the tree still runs mid-window")
	# the 1.0 s window is about 60 frames; give it a margin
	await _physics_frames(40)
	assert_almost_eq(black.modulate.a, 1.0, 0.02, "the cover is fully down")
	assert_true(get_tree().paused, "the tree pauses only when the cover is down")
	assert_false(lid_top.visible, "the stencil lids yield once the cover is down")
	assert_false(death_screen.get_node("BWRect").visible, "the grayscale reveal waits out the delay")
	await _physics_frames(100)
	assert_true(death_screen.get_node("BWRect").visible,
		"the grayscale shader layer reveals after the 1.5 s delay")


func test_the_reveal_fades_the_black_cover_out() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	death_screen.death_fade_time = 1.0
	var black : ColorRect = death_screen.get_node("BlackRect")
	var bw : ColorRect = death_screen.get_node("BWRect")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(200)
	assert_true(bw.visible, "the grayscale reveal is showing after the window")
	assert_almost_eq(black.modulate.a, 0.0, 0.05, "the black cover fades out under the reveal")


func test_input_fades_back_to_black_but_the_tail_stays_out_of_the_test() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	death_screen.death_fade_time = 1.0
	var black : ColorRect = death_screen.get_node("BlackRect")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(200)
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


func _make_esc_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	return event


func test_esc_escapes_during_the_unpaused_ragdoll_window() -> void:
	# ESC works from the very start of the sequence, before the cover is
	# down and while the tree is still running the ragdoll window.
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	var black : ColorRect = death_screen.get_node("BlackRect")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(2)
	assert_false(get_tree().paused, "sanity: this is the unpaused window")
	Input.parse_input_event(_make_esc_press())
	await _physics_frames(12)
	assert_true(death_screen._fade_started,
		"the death screen consumed ESC itself and started the fade")
	assert_gt(black.modulate.a, 0.15, "the fade back to black is running over the window")
	# free the screen before the tail (unpause plus scene change) runs so the
	# GUT runner scene is never replaced
	_world.free()
	_world = null
	_ui.free()
	await _physics_frames(5)


func test_esc_after_the_reveal_fades_like_any_key() -> void:
	var player : Node3D = await _spawn_player(Vector3(2.0, 0.0, 2.0))
	var death_screen : Control = _ui._death_screen
	death_screen.death_fade_time = 1.0
	var black : ColorRect = death_screen.get_node("BlackRect")
	_ui.observe_player(player)
	_kill(player)
	await _physics_frames(200)
	assert_almost_eq(black.modulate.a, 0.0, 0.05, "sanity: the reveal is showing")
	death_screen._input(_make_esc_press())
	await _physics_frames(30)
	assert_true(black.modulate.a > 0.3, "ESC starts the fade back to black like any key")
	assert_true(get_tree().paused, "the tree stays paused through the fade")
	# free the screen before the tail (unpause plus scene change) runs so the
	# GUT runner scene is never replaced
	_world.free()
	_world = null
	_ui.free()
	await _physics_frames(5)
