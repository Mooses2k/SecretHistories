# Pins the tinnitus overlay port (3.x scenes/characters/player/tinnitus.gd on
# origin/main): the trigger/refresh/decay lifecycle through the real
# game_ui scene, the Events.tinnitus_triggered bus wiring, and the death stop.
# Gunfire does NOT trigger tinnitus (owner ruling: the white screen flash read
# as a broken overlay; tinnitus belongs to the 3.x ghost-attack family and its
# only producer is the ghost damage area). A real webley fired from a spawned
# player probe pins the silence (the bomb-scenario harness).
extends GutTest

const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const WEBLEY_SCENE := preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
const WEBLEY_AMMO := preload("res://resources/tiny_items/ammunition/455_webley.tres")
const TinnitusOverlay := preload("res://scenes/ui/tinnitus_overlay.gd")

var _ui : GameUI
var _world : Node3D
var _game : Game
var _level : GameWorld
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


func after_each() -> void:
	GameManager.game = _saved_game
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null
	if _level != null:
		_level.free()
		_level = null


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _white_rect(tinnitus) -> TextureRect:
	return tinnitus.get_node("ScreenWhite/TextureRect") as TextureRect


func test_events_bus_signal_rings_the_overlay() -> void:
	Events.tinnitus_triggered.emit(0.25)
	assert_eq(_ui._tinnitus._t, 0.25, "a bus trigger adds its strength to the ring level")


func test_trigger_starts_the_audio_and_the_white_wash() -> void:
	Events.tinnitus_triggered.emit(0.5)
	# A GUT physics_frame await resumes at the signal, before that frame's
	# _physics_process callbacks: two awaits are the first processed tick.
	await _physics_frames(2)
	assert_true(_ui._tinnitus.playing, "the ring audio starts after a trigger")
	assert_true(_ui._tinnitus._t > 0.4, "the ring level holds just after the trigger")
	assert_true(_white_rect(_ui._tinnitus).modulate.a > 0.0, "the white wash shows while the ring decays")


func test_ring_decays_at_the_quarter_rate_and_stops_at_silence() -> void:
	Events.tinnitus_triggered.emit(0.2)
	await _physics_frames(60)   # 0.2 of ring decays to silence in 0.8 s
	assert_false(_ui._tinnitus.playing, "the ring audio stops once the level reaches silence")
	assert_eq(_white_rect(_ui._tinnitus).modulate.a, 0.0, "the white wash is fully faded at silence")


func test_rapid_triggers_refresh_without_stacking_past_full() -> void:
	for i in 5:
		Events.tinnitus_triggered.emit(0.5)
	assert_eq(_ui._tinnitus._t, 1.0, "rapid re-triggers hold the ring at full, never above")


func test_death_stops_the_ring_and_ignores_further_triggers() -> void:
	Events.tinnitus_triggered.emit(1.0)
	_ui._on_player_physical_state_changed(HumanoidCharacterState.PhysicalState.DEAD)
	assert_false(_ui._tinnitus.playing, "death stops the ring")
	assert_false(_white_rect(_ui._tinnitus).visible, "death hides the white wash")
	await _physics_frames(2)
	Events.tinnitus_triggered.emit(1.0)
	await _physics_frames(2)
	assert_false(_ui._tinnitus.playing, "a dead overlay never resumes the ring on later triggers")
	assert_false(_white_rect(_ui._tinnitus).visible, "a dead overlay never re-shows the white wash")


func test_player_gunshot_does_not_ring_the_ears() -> void:
	# Owner ruling: the gunfire tinnitus trigger is gone. Firing the webley
	# must not emit the bus signal and must leave the overlay silent. The
	# noise_level set in shoot() stays: that is the AI hearing channel.
	# Minimal bomb-scenario harness: the before_each Game stub, a floor, and a
	# real player probe.
	_world = Node3D.new()
	add_child_autofree(_world)
	_level_setup()
	_game.ui_root = _ui
	_add_floor()
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = Vector3(2.0, 0.0, 2.0)
	_world.add_child(player)
	_game.player = player
	await _physics_frames(5)

	var gun : GunItem = WEBLEY_SCENE.instantiate()
	var hand_root : Node3D = player.get_node("ModelRoot/rig_deform/Skeleton3D/PalmR/MainHandRoot")
	hand_root.add_child(gun)
	await _physics_frames(2)
	gun.set("owner_character", player)
	gun.set("current_ammo", 6)
	gun.set("current_ammo_type", WEBLEY_AMMO)

	watch_signals(Events)
	gun.call("_use_primary")
	await _physics_frames(1)   # exactly the trigger tick: no decay step applied yet

	assert_signal_not_emitted(Events, "tinnitus_triggered",
		"a player gunshot must not trigger tinnitus")
	assert_almost_eq(_ui._tinnitus._t, 0.0, 0.0001,
		"the overlay stays silent through the gunshot")


func _level_setup() -> void:
	_level = GameWorld.new()
	var world_data : WorldData = WorldData.new()
	world_data.cell_type.resize(world_data.cell_count)
	_level.world_data = world_data
	_game.level = _level


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.5, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
