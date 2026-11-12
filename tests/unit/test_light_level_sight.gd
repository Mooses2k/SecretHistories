extends GutTest
## The light-level sight model (parity audit M3, 3.x origin/main):
## HumanoidCharacter carries light_level, the LightDetection rig on the
## humanoid base publishes it (player owners only, matching 3.x where only
## player.tscn mounted the rig), and VisualSensor.can_see_player rejects a
## player whose light_level is at or below light_sensitivity_level (0.003),
## so cultists cannot sight an unlit player in darkness. The producer math
## is pinned through its modifier functions without rendering the sample
## viewports (headless runs have no renderer).

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const BASE_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"
const DETECTOR_SCENE := "res://scenes/characters/light_detection.tscn"
const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const VISUAL_SENSOR_SCRIPT := "res://scenes/sensors/visual_sensor.gd"
const LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/starstuff_lantern/starstuff_lantern.tscn"

var _world : Node3D
var _game : Game
var _saved_game : Game


func before_each() -> void:
	# Same stub set as test_spyglass_zoom.gd: the real player scene ticks
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


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _frozen_character(scene_path : String) -> Node:
	var character : Node = (load(scene_path) as PackedScene).instantiate()
	_world.add_child(character)
	# Freeze holds the body still for the sensor overlap and sight ray; the
	# custom integrator would otherwise drop it through the empty test world.
	character.freeze = true
	await _physics_frames(2)
	return character


func _add_visual_sensor(at : Vector3) -> VisualSensor:
	var sensor : VisualSensor = (load(VISUAL_SENSOR_SCRIPT) as GDScript).new()
	var ik_target := Marker3D.new()
	ik_target.name = "IkTarget"
	sensor.add_child(ik_target)
	sensor._ik_target = NodePath("IkTarget")
	_world.add_child(sensor)
	sensor.global_position = at
	await _physics_frames(3)
	return sensor


# --------------------------------------------------------------------------
# The property and the rig authoring
# --------------------------------------------------------------------------
func test_humanoid_declares_light_level_defaulting_to_zero() -> void:
	var character : Node = await _frozen_character(BASE_SCENE)
	assert_eq(character.light_level, 0.0,
		"the active humanoid chain carries light_level, dark by default")


func test_player_scene_rig_is_active_and_npc_rig_is_idle() -> void:
	var player : Node = await _frozen_character(PLAYER_SCENE)
	var rig : Node = player.get_node("ModelRoot/LightDetection")
	assert_true(rig != null and rig.process_mode != Node.PROCESS_MODE_DISABLED,
		"the player rig authors the LightDetection producer and keeps it processing")
	var player_viewport : SubViewport = rig.get_node("SubViewportContainer/SubViewport")
	assert_eq(player_viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS,
		"the player's sample viewports always render despite the hidden rig")

	var npc : Node = await _frozen_character(BASE_SCENE)
	var npc_rig : Node = npc.get_node("ModelRoot/LightDetection")
	assert_false(npc_rig.is_processing(),
		"non-Player owners never process the producer, matching 3.x where only the player mounted the rig")
	var npc_viewport : SubViewport = npc_rig.get_node("SubViewportContainer/SubViewport")
	assert_eq(npc_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED,
		"non-Player owners never render the sample viewports")


# --------------------------------------------------------------------------
# The producer math (3.x light_detection.gd modifiers, no rendering needed)
# --------------------------------------------------------------------------
func _make_detector(owner_character : Node) -> Node:
	# The rig as authored: viewports disabled, processing off, so the test
	# drives the modifiers directly. A runtime-added node has a null owner,
	# so the scene owner the producer reads is assigned explicitly.
	var detector : Node = (load(DETECTOR_SCENE) as PackedScene).instantiate()
	owner_character.add_child(detector)
	detector.owner = owner_character
	detector.set_process(false)
	return detector


func test_publish_writes_the_owner_light_level() -> void:
	var character : Node = await _frozen_character(BASE_SCENE)
	var detector := _make_detector(character)
	detector.light_level_top = 0.42
	detector._publish()
	assert_eq(character.light_level, 0.42,
		"the detector publishes light_level_top into owner.light_level")


func test_speed_multiplies_the_light_level() -> void:
	var character : Node = await _frozen_character(BASE_SCENE)
	var detector := _make_detector(character)
	detector.light_level_top = 1.0
	character.linear_velocity = Vector3(2.0, 0.0, 0.0)
	detector._modify_by_speed()
	assert_almost_eq(detector.light_level_top, 2.0, 0.0001,
		"3.x: movement multiplies light_level by the speed when faster than 1 m/s")


func test_crouching_multiplies_the_light_level_down() -> void:
	var character : Node = await _frozen_character(BASE_SCENE)
	var detector := _make_detector(character)
	detector.light_level_top = 1.0
	character.state.current_crouch_ratio = 1.0
	detector._modify_by_state()
	assert_almost_eq(detector.light_level_top, 0.7, 0.0001,
		"3.x: crouching multiplies light_level by 0.7")


func test_crouching_with_a_lit_light_in_the_mainhand_stays_visible() -> void:
	var character : Node = await _frozen_character(BASE_SCENE)
	var detector := _make_detector(character)
	var lantern : LanternItem = add_child_autofree(
			(load(LANTERN_SCENE) as PackedScene).instantiate())
	lantern.light()
	assert_true(lantern.is_lit, "precondition: the lantern is lit")
	character.inventory.current_mainhand_equipment = lantern
	character.state.current_crouch_ratio = 1.0
	detector.light_level_top = 1.0

	detector._modify_by_state()

	assert_eq(character.light_level, detector.light_level_top,
		"3.x: a lit light-source in hand publishes directly, no crouch hiding")


func test_lit_light_recognition_covers_the_light_source_kinds() -> void:
	var character : Node = await _frozen_character(BASE_SCENE)
	var detector := _make_detector(character)
	var lantern : LanternItem = add_child_autofree(
			(load(LANTERN_SCENE) as PackedScene).instantiate())
	lantern.light()
	assert_true(detector._is_holding_lit_light(lantern), "a lit lantern counts")
	lantern.unlight()
	assert_false(detector._is_holding_lit_light(lantern), "an unlit lantern does not")


# --------------------------------------------------------------------------
# The sight gate (3.x visual_sensor.gd:146)
# --------------------------------------------------------------------------
func test_dark_player_cannot_be_seen_by_a_cultist_sensor() -> void:
	var player : Node = await _frozen_character(PLAYER_SCENE)
	var cultist : Node = await _frozen_character(BASE_SCENE)
	cultist.global_position = Vector3(6.0, -2.0, 6.0)
	var sensor := await _add_visual_sensor(Vector3(0.0, 1.6, 4.0))

	player.light_level = 0.0
	assert_null(sensor.can_see_player(cultist),
		"a player at light_level 0.0 in darkness cannot be sighted")

	player.light_level = 0.003
	assert_null(sensor.can_see_player(cultist),
		"a player exactly at the 0.003 threshold (strictly greater gate) cannot be sighted")


func test_lit_player_is_sighted_again() -> void:
	var player : Node = await _frozen_character(PLAYER_SCENE)
	var cultist : Node = await _frozen_character(BASE_SCENE)
	cultist.global_position = Vector3(6.0, -2.0, 6.0)
	var sensor := await _add_visual_sensor(Vector3(0.0, 1.6, 4.0))

	player.light_level = 0.01
	var seen : Node = sensor.can_see_player(cultist)
	assert_eq(seen, player,
		"a player above light_sensitivity_level is sighted again: the gate passes")


# --------------------------------------------------------------------------
# Save compatibility
# --------------------------------------------------------------------------
func test_save_capture_ignores_light_level() -> void:
	var player : Node = await _frozen_character(PLAYER_SCENE)
	_game.player = player
	player.light_level = 5.0

	var data : Dictionary = SaveManager._capture_player(_game)

	assert_false("light_level" in data,
		"the save capture is explicit and never round-trips the runtime-only light_level")
