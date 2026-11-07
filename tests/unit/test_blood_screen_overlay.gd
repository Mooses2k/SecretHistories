# Pins the blood screen overlay port (3.x scenes/characters/player/player_hit.gd
# on origin/main, the HitEffect visual half): the per-hit flash, the durability
# ladder for the persistent vignette, the real Hurtbox->GameUI->overlay route
# through a spawned player probe, and the death hide. Uses the same harness as
# the tinnitus tests.
extends GutTest

const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _ui : GameUI
var _world : Node3D
var _game : Game
var _saved_game : Game


func before_each() -> void:
	_saved_game = GameManager.game
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
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _spawn_player_with_ui(at : Vector3) -> Node3D:
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
	# In production game.gd re-emits player_spawned and GameUI (the Game's
	# child) starts observing the player's state and hurtboxes. The harness
	# GameUI has no Game parent, so the observation route is invoked the way
	# _on_game_player_spawned would.
	_ui.observe_player(player)
	await _physics_frames(5)
	return player


func _first_hurtbox(player : Node3D) -> Hurtbox:
	return player.find_children("*", "Hurtbox", true, false)[0] as Hurtbox


func test_full_health_hit_flashes_but_shows_no_vignette() -> void:
	var player : Node3D = await _spawn_player_with_ui(Vector3(2.0, 0.0, 2.0))
	var overlay : Control = _ui._blood_screen
	var flash : TextureRect = overlay.get_node("HitFlashRect")
	var vignette : TextureRect = overlay.get_node("LowHealthRect")
	_first_hurtbox(player).damage(10, GlobalConsts.AttackTypes.BLUDGEONING)
	await _physics_frames(2)
	assert_true(flash.visible, "a hit shows the blood splatter flash")
	assert_true(flash.modulate.a > 0.9, "the flash starts near full opacity")
	assert_false(vignette.visible, "a hit at full health shows no persistent vignette")


func test_flash_fades_out_under_a_second() -> void:
	var player : Node3D = await _spawn_player_with_ui(Vector3(2.0, 0.0, 2.0))
	var flash : TextureRect = _ui._blood_screen.get_node("HitFlashRect")
	_first_hurtbox(player).damage(10, GlobalConsts.AttackTypes.BLUDGEONING)
	await _physics_frames(60)   # the 3.x flash length is 0.9 s
	assert_almost_eq(flash.modulate.a, 0.0, 0.02, "the flash has fully faded after 0.9 s")


func test_low_durability_hits_start_the_vignette_pulse() -> void:
	var player : Node3D = await _spawn_player_with_ui(Vector3(2.0, 0.0, 2.0))
	var overlay : Control = _ui._blood_screen
	var vignette : TextureRect = overlay.get_node("LowHealthRect")
	var state : HumanoidCharacterState = player.get_node("State")
	state.durability = 35   # second rung of the 3.x ladder: alpha 0.1 to 0.3
	_first_hurtbox(player).damage(1, GlobalConsts.AttackTypes.BLUDGEONING)
	await _physics_frames(2)
	assert_true(vignette.visible, "a hit below the top threshold shows the persistent vignette")
	assert_eq(overlay._pulse_low, 0.1, "the 35 durability rung pulses from 0.1 alpha")
	assert_eq(overlay._pulse_high, 0.3, "the 35 durability rung pulses to 0.3 alpha")


func test_near_death_hits_reach_the_top_rung() -> void:
	var player : Node3D = await _spawn_player_with_ui(Vector3(2.0, 0.0, 2.0))
	var overlay : Control = _ui._blood_screen
	var state : HumanoidCharacterState = player.get_node("State")
	state.durability = 3   # deepest 3.x rung: alpha 0.7 to 0.98
	_first_hurtbox(player).damage(1, GlobalConsts.AttackTypes.BLUDGEONING)
	await _physics_frames(2)
	assert_eq(overlay._pulse_low, 0.7, "the deepest rung pulses from 0.7 alpha")
	assert_eq(overlay._pulse_high, 0.98, "the deepest rung pulses to 0.98 alpha")
	assert_eq(overlay._pulse_speed, 0.4, "the deepest rung pulses at the 0.4 speed")


func test_death_hides_both_layers_and_ignores_further_hits() -> void:
	var player : Node3D = await _spawn_player_with_ui(Vector3(2.0, 0.0, 2.0))
	var overlay : Control = _ui._blood_screen
	var flash : TextureRect = overlay.get_node("HitFlashRect")
	var vignette : TextureRect = overlay.get_node("LowHealthRect")
	var state : HumanoidCharacterState = player.get_node("State")
	state.durability = 30
	_first_hurtbox(player).damage(1, GlobalConsts.AttackTypes.BLUDGEONING)
	await _physics_frames(2)
	assert_true(flash.visible, "sanity: the flash is up before death")
	_ui._on_player_physical_state_changed(HumanoidCharacterState.PhysicalState.DEAD)
	assert_false(flash.visible, "death hides the flash layer")
	assert_false(vignette.visible, "death hides the vignette layer")
	_first_hurtbox(player).damage(1, GlobalConsts.AttackTypes.BLUDGEONING)
	await _physics_frames(1)
	assert_false(flash.visible, "a dead overlay never re-flashes on later hits")
