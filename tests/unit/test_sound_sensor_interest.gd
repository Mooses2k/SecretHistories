# Unit tests for the SoundSensor interest side (#407): the 3.x semantics
# restored after a stray migration FIXME killed every detection with an
# unconditional return 0. Pinned behavior, read from the 3.x
# scenes/sensors/sound_sensor.gd: interest is the source noise as int,
# divided by the wall count between sensor and source, +100 for a BombItem
# at noise >= 80, +100 for anything within 1.0 m, and zero below
# hearing_sensitivity (default 5.0). check_for_sounds emits sound_detected
# and event for EVERY qualifying registered source in one check and returns
# whether any were emitted. The pre-fix sensor (always 0) fails the
# threshold and bonus tests here.
extends GutTest

const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const GRENADE_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/bomb/grenade/grenade.tscn"

var _world : Node3D
var _floor_body : StaticBody3D


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)
	# A ground plane far below the tested sight lines, so no tested segment
	# crosses it: the wall query counts shapes intersecting the ray segment,
	# and the floor must not contribute a phantom wall.
	_floor_body = StaticBody3D.new()
	_floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40.0, 0.5, 40.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -1.0, 0.0)
	_floor_body.add_child(floor_shape)
	_world.add_child(_floor_body)


func after_each() -> void:
	_world.free()


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _add_sensor(at : Vector3) -> SoundSensor:
	var sensor : SoundSensor = (load("res://scenes/sensors/sound_sensor.gd") as GDScript).new()
	sensor.name = "ProbeSensor"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	sensor.add_child(shape)
	_world.add_child(sensor)
	sensor.position = at
	await _physics_frames(2)
	return sensor


func _add_wall(at : Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.position = at
	await _physics_frames(2)


func _rest_item(scene_path : String, at : Vector3, noise : float) -> PickableItem:
	var item : PickableItem = (load(scene_path) as PackedScene).instantiate()
	_world.add_child(item)
	item.global_position = at
	await _physics_frames(2)
	item.noise_level = noise
	return item


func test_noise_at_the_threshold_becomes_interest() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var dagger := await _rest_item(DAGGER_SCENE, Vector3(0.0, 1.0, 6.0), 5.0)
	sensor.sound_sources.append(dagger)
	assert_eq(sensor.get_interest_level(dagger), 5,
		"noise exactly at hearing_sensitivity is detected at its noise level")


func test_noise_below_the_threshold_is_silence() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var dagger := await _rest_item(DAGGER_SCENE, Vector3(0.0, 1.0, 6.0), 3.0)
	sensor.sound_sources.append(dagger)
	assert_eq(sensor.get_interest_level(dagger), 0,
		"noise below hearing_sensitivity returns 0 interest")


func test_silent_source_returns_zero() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var dagger := await _rest_item(DAGGER_SCENE, Vector3(0.0, 1.0, 6.0), 0.0)
	sensor.sound_sources.append(dagger)
	assert_eq(sensor.get_interest_level(dagger), 0, "a noise_level of 0 is silent")


func test_walls_in_between_divide_the_interest() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	await _add_wall(Vector3(0.0, 1.0, 2.0))
	await _add_wall(Vector3(0.0, 1.0, 4.0))
	var dagger := await _rest_item(DAGGER_SCENE, Vector3(0.0, 1.0, 6.0), 40.0)
	sensor.sound_sources.append(dagger)
	assert_eq(sensor.get_interest_level(dagger), 20,
		"interest is the noise divided by the wall count along the segment")


func test_bomb_noise_gets_the_bomb_bonus() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var bomb := await _rest_item(GRENADE_SCENE, Vector3(0.0, 1.0, 6.0), 80.0)
	sensor.sound_sources.append(bomb)
	assert_eq(sensor.get_interest_level(bomb), 180,
		"a BombItem at noise >= 80 gets +100 interest")


func test_point_blank_noise_gets_the_distance_bonus() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var dagger := await _rest_item(DAGGER_SCENE, Vector3(0.0, 1.0, 0.5), 3.0)
	sensor.sound_sources.append(dagger)
	assert_eq(sensor.get_interest_level(dagger), 103,
		"a source within 1.0 m gets +100 interest even below the threshold")


func test_check_for_sounds_emits_every_qualifying_source() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var first := await _rest_item(DAGGER_SCENE, Vector3(2.0, 1.0, 6.0), 10.0)
	var second := await _rest_item(DAGGER_SCENE, Vector3(-2.0, 1.0, 6.0), 10.0)
	sensor.sound_sources.append(first)
	sensor.sound_sources.append(second)

	var detections := []
	sensor.sound_detected.connect(func(source, interest): detections.append([source, interest]))
	var events := []
	sensor.event.connect(func(interest, position, object, emitter): events.append([interest, object]))

	var result : bool = sensor.check_for_sounds()
	assert_true(result, "a check with qualifying sources returns true")
	assert_eq(detections.size(), 2,
		"every qualifying source is detected in one check, not just the first")
	assert_eq(events.size(), 2, "the sensor event fires for every qualifying source")
	assert_true(detections.any(func(d): return d[0] == first),
		"the first source is among the detections")
	assert_true(detections.any(func(d): return d[0] == second),
		"the second source is among the detections")
	assert_true(detections.all(func(d): return d[1] == 10),
		"each detection carries the source's interest level")


func test_tick_emits_sound_detected_for_a_noisy_registered_source() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var dagger := await _rest_item(DAGGER_SCENE, Vector3(0.0, 1.0, 6.0), 10.0)
	sensor.sound_sources.append(dagger)

	var detections := []
	sensor.sound_detected.connect(func(source, interest): detections.append([source, interest]))
	var status : int = sensor.tick(null, 0.016)
	assert_eq(status, OK, "a tick that detected sound returns OK")
	assert_eq(detections.size(), 1, "the tick emits sound_detected for the noisy source")
	assert_eq(detections[0][0], dagger, "the detection points at the noisy source")
	assert_eq(detections[0][1], 10, "the detection carries the source's interest level")


func test_tick_returns_failed_without_noise() -> void:
	var sensor := await _add_sensor(Vector3(0.0, 1.0, 0.0))
	var dagger := await _rest_item(DAGGER_SCENE, Vector3(0.0, 1.0, 6.0), 0.0)
	sensor.sound_sources.append(dagger)
	assert_eq(sensor.tick(null, 0.016), FAILED,
		"a tick with no qualifying source returns FAILED")
