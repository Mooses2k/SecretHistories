# Integration-style noise propagation tests (#407): the noise PRODUCER side of
# the character noise detection chain, on real items. The shared noise surface
# is PickableItem.noise_level (a float, zeroed again about 0.2 s after it is
# set by _process). Producers pinned by observation: a bomb's countdown
# handler sets noise_level = 80 with item_max_noise_level = 80 right before
# the explosion, play_throw_sound raises the noise to 6 when it was below 8,
# and the real ImpactAudioManager.play_impact_sound entry sets
# clamp(max_noise_level * impact_intensity, 1, 8) on the parent item (the
# melee base scene gives every melee item a drop sound, so the noise write is
# reached). The SoundSensor registration half of the chain is also pinned: a
# sensor whose mask covers the ItemDrops layer registers an overlapping
# dropped item in sound_sources and ignores non-item bodies. The sensor to
# interest side (SoundSensor.get_interest_level) is dead code today: it always
# returns 0 at its FIXME, so detection never fires. That is a discovered bug,
# reported in docs/research, NOT pinned here as expected behavior.
extends GutTest

const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const GRENADE_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/bomb/grenade/grenade.tscn"

var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game


func before_each() -> void:
	# The bomb countdown path calls into effects.gd which needs a valid
	# GameManager.game with a level, so the headless stub set is required.
	_saved_game = GameManager.game
	_world = Node3D.new()
	add_child(_world)
	_game = Game.new()
	_level = GameWorld.new()
	var world_data : WorldData = WorldData.new()
	world_data.cell_type.resize(world_data.cell_count)
	_level.world_data = world_data
	_game.level = _level
	_ui = GameUI.new()
	_hud = HUD.new()
	var indicators : Array[TextureRect] = [
		TextureRect.new(), TextureRect.new(), TextureRect.new(),
	]
	_hud.indicators = indicators
	_hud.add_child(indicators[0])
	_hud.add_child(indicators[1])
	_hud.add_child(indicators[2])
	_ui.hud_root = _hud
	_game.ui_root = _ui
	GameManager.game = _game


func after_each() -> void:
	# Free the scene content first so no per-frame handler sees a torn-down
	# stub, then restore the autoload state.
	_world.free()
	GameManager.game = _saved_game
	_game.free()
	_level.free()
	_ui.free()
	_hud.free()


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


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


func _rest_dagger(at : Vector3) -> EquipmentItem:
	var dagger : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	dagger.name = "NoisyDagger"
	_world.add_child(dagger)
	dagger.global_position = at
	await _physics_frames(2)
	return dagger


func test_bomb_countdown_sets_the_loud_noise_level() -> void:
	_add_floor()
	var bomb : RigidBody3D = (load(GRENADE_SCENE) as PackedScene).instantiate()
	bomb.name = "LoudBomb"
	_world.add_child(bomb)
	bomb.global_position = Vector3(8.0, 0.14, 8.0)
	await _physics_frames(2)
	bomb.call("_on_Countdown_timeout")
	assert_eq(bomb.get("noise_level"), 80.0,
		"the countdown handler raises the bomb noise to 80 right before the explosion")
	assert_eq(bomb.get("item_max_noise_level"), 80,
		"the countdown handler also raises the bomb's own max noise level to 80")


func test_item_impact_audio_writes_noise_on_the_item() -> void:
	_add_floor()
	var dagger : EquipmentItem = await _rest_dagger(Vector3(6.0, 0.15, 6.0))
	assert_true(dagger.impact_audio_manager != null,
		"every pickable item carries an impact audio manager from _enter_tree")
	assert_eq(dagger.get("noise_level"), 0.0, "a resting item is silent")
	dagger.impact_audio_manager.play_impact_sound(5.0)
	assert_eq(dagger.get("noise_level"), 8.0,
		"play_impact_sound writes clamp(max_noise_level * intensity, 1, 8) on the item")


func test_sound_sensor_registers_a_dropped_item_as_a_sound_source() -> void:
	_add_floor()
	var sensor : Area3D = (load("res://scenes/sensors/sound_sensor.gd") as GDScript).new()
	sensor.name = "ProbeSensor"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape.shape = sphere
	sensor.add_child(shape)
	_world.add_child(sensor)
	sensor.position = Vector3(6.0, 1.0, 6.0)
	var dagger : EquipmentItem = await _rest_dagger(Vector3(6.0, 0.15, 6.0))
	var bystander := StaticBody3D.new()
	bystander.name = "Bystander"
	bystander.position = Vector3(6.0, 0.5, 6.0)
	var bystander_shape := CollisionShape3D.new()
	var bystander_sphere := SphereShape3D.new()
	bystander_sphere.radius = 0.3
	bystander_shape.shape = bystander_sphere
	bystander.add_child(bystander_shape)
	_world.add_child(bystander)
	await _physics_frames(2)
	assert_eq(sensor.collision_mask, 1 << 1 | 1 << 6 | 1 << 9,
		"the sensor _ready covers the Player, ItemDrops and Interactables layers")
	assert_true(sensor.sound_sources.has(dagger),
		"an overlapping dropped item is registered as a sound source")
	assert_false(sensor.sound_sources.has(bystander),
		"a body that is not a PickableItem is not registered as a sound source")


func test_thrown_item_noise_decays_back_to_silence() -> void:
	# No floor here on purpose: a resting throw-sound item touching anything
	# runs the impact audio manager's first-contact path, which is out of
	# scope for the decay behavior under test.
	var dagger : EquipmentItem = await _rest_dagger(Vector3(6.0, 2.0, 6.0))
	dagger.call("play_throw_sound")
	assert_eq(dagger.get("noise_level"), 6.0,
		"play_throw_sound raises the item noise to 6 when it was below 8")
	await _physics_frames(40)
	assert_eq(dagger.get("noise_level"), 0.0,
		"the item _process decay zeroes the noise after about 0.2 s")
