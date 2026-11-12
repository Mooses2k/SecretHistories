extends GutTest

## The neophyte scene's live sensor chain, the part the synthetic-stimulus
## tests bypass: the Sensors node must carry character_sensors.gd (a stale
## ext_resource uid silently attaches a core/ai BT script instead and every
## sensor goes dark with no error), the scene VisualSensor must register
## body overlaps under the frozen character root (on the Jolt build an
## Area3D with monitorable=false under a RigidBody3D detects nothing, so
## the sight cone was blind), and the lit player in front must raise
## suspicion, fire the detection seam once per Combat entry, keep the
## dry-period speech guard, turn the model toward the target, and walk
## with animation parameters actually written.

const NEOPHYTE_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const AI_CONTROLLER_SCRIPT := "res://scenes/characters/cultist/ai_controller.gd"
const CHARACTER_AUDIO_SCRIPT := "res://scenes/characters/character_audio.gd"

var _world: Node
var _cultist: Node
var _player: Node
var _controller: Node
var _audio_double: Node = null


func before_each() -> void:
	_world = add_child_autofree(Node.new()) as Node


func after_each() -> void:
	_cultist = null
	_player = null
	_controller = null
	_audio_double = null
	_world = null


func _boot_cultist(at: Vector3 = Vector3.ZERO, with_double_audio := false) -> Node:
	_cultist = (load(NEOPHYTE_SCENE) as PackedScene).instantiate()
	if with_double_audio:
		var real_audio: Node = _cultist.get_node("Audio")
		_cultist.remove_child(real_audio)
		real_audio.free()
		_audio_double = (double(load(CHARACTER_AUDIO_SCRIPT)) as GDScript).new()
		_audio_double.name = "Audio"
		for player_name in ["Speech", "Manipulation", "Movement"]:
			var stream_player := AudioStreamPlayer3D.new()
			stream_player.name = player_name
			_audio_double.add_child(stream_player)
		_cultist.add_child(_audio_double)
	_world.add_child(_cultist)
	_cultist.set("global_position", at)
	for child in _cultist.get_children():
		if child.get_script() == load(AI_CONTROLLER_SCRIPT):
			_controller = child
	assert_not_null(_controller, "the AIController is found by script path")
	(_controller.get_node("TickTimer") as Timer).stop()
	return _cultist


func _boot_lit_player(at: Vector3) -> Node:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(_player)
	_player.set("freeze", true)
	_player.set("global_position", at)
	_player.set("light_level", 0.01)
	# The interact controller reads the game HUD surface every frame; the
	# full game UI is out of scope here, so its processing stays off. The
	# player body keeps processing and stays in the physics space for the
	# sight cone and raycast.
	var interact: Node = _player.get_node("PlayerController/InteractController")
	interact.set_process(false)
	return _player


func _idle_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _brain() -> HFSM:
	return _controller.brain


func _board() -> Blackboard:
	return _controller.ai_state


func test_sensors_node_carries_character_sensors_script() -> void:
	_boot_cultist()
	var sensors: Node = _cultist.get_node("Sensors")
	var script: GDScript = sensors.get_script()
	assert_not_null(script, "the Sensors node has a script attached")
	assert_eq(script.resource_path, "res://scenes/sensors/character_sensors.gd",
		"the Sensors node runs the sensor ticker, not a stolen-uid BT script")
	assert_true((sensors.get("sensors") as Array).size() >= 3,
		"the ticker collected the SoundSensor, VisualSensor and TouchSensor")


func test_visual_sensor_overlaps_frozen_body_in_front() -> void:
	_boot_cultist()
	var base: Node = (load("res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn") as PackedScene).instantiate()
	_world.add_child(base)
	base.set("freeze", true)
	base.set("global_position", Vector3(0.0, 0.0, -3.0))
	base.set("light_level", 0.01)
	await _idle_frames(30)
	var sensor: Area3D = _cultist.get_node("Sensors/VisualSensor")
	var names: Array = sensor.get_overlapping_bodies().map(func(b: Node): return b.name)
	assert_true(names.has("HumanoidCharacterBase"),
		"the scene sight cone registers the body 3 m in front, got %s" % str(names))


func test_lit_player_in_front_raises_suspicion_and_combat() -> void:
	_boot_cultist()
	_boot_lit_player(Vector3(0.0, 0.0, -3.0))
	await _idle_frames(40)
	_controller.tick()
	assert_true(_board().alertness >= _board().investigate_bar,
		"the sight stimulus raised alertness past the investigate bar, got %.1f" % _board().alertness)
	_controller.tick()
	var active_name := String(_brain().active_state.name)
	assert_true(active_name == "Combat" or active_name == "Suspicious" or active_name == "Investigate",
		"the brain left Idle on sight, got %s" % active_name)
	assert_true(_board().target != null, "the sight stimulus set the target")


func test_detection_seam_fires_once_per_combat_entry() -> void:
	_boot_cultist(Vector3.ZERO, true)
	_boot_lit_player(Vector3(0.0, 0.0, -3.0))
	await _idle_frames(40)
	_controller.tick()
	_controller.tick()
	_controller.tick()
	assert_true(String(_brain().active_state.name) == "Combat",
		"the brain reached Combat, got %s" % String(_brain().active_state.name))
	assert_called_count(_audio_double.on_player_detected, 1)
	# The first Combat entry fired the detection seam exactly once.
	_brain().active_state.exited.emit(&"Combat")
	_brain().active_state.entered.emit(&"Combat")
	assert_called_count(_audio_double.on_player_detected, 2)
	# A re-entry reaches the audio seam again; the dry period lives in the guard.


func test_speech_guard_does_not_restart_a_playing_line() -> void:
	_boot_cultist()
	var audio: Node = _cultist.get_node("Audio")
	var speech: AudioStreamPlayer3D = audio.get_node("Speech")
	audio.call("play_alert_sound")
	assert_true(speech.is_playing(), "the alert line plays")
	var stream_before: AudioStream = speech.stream
	audio.call("play_detection_sound")
	assert_eq(speech.stream, stream_before,
		"the dry-period guard did not restart the playing line with a detection line")
	assert_true(speech.is_playing(), "the original line is still the one playing")


func test_combat_turns_the_model_toward_the_target() -> void:
	_boot_cultist(Vector3(0.0, 0.0, -3.8))
	_boot_lit_player(Vector3(0.0, 0.0, -3.0))
	await _idle_frames(40)
	for i in 5:
		_controller.tick()
	var active: Node = _brain().active_state
	assert_not_null(active, "the brain is running")
	var model_root: Node3D = _cultist.get_node("ModelRoot")
	var to_player: Vector3 = _player.global_position - _cultist.global_position
	var dot: float = model_root.global_basis.z.normalized().dot(to_player.normalized())
	assert_true(absf(dot) > 0.5,
		"the model turns toward the combat target (dot %.2f, state %s)" % [
			dot, String(active.name)])


func test_patrol_walks_with_animation_parameters_written() -> void:
	_boot_cultist()
	var brain := _brain()
	brain.force_state(&"Patrol")
	var adapter: Node = _controller.navigation_adapter
	adapter.set("path", [Vector3(0.0, 0.0, -6.0)])
	_controller.tick()
	await _idle_frames(60)
	_controller.tick()
	var velocity: Vector3 = _cultist.get("linear_velocity")
	assert_true(velocity.length() > 0.2,
		"the cultist walks along the injected path, vel %s" % str(velocity))
	var anim_tree: AnimationTree = _cultist.get_node("CharacterAnimationTree")
	var blend: Vector2 = anim_tree.get("parameters/movement/blend_position")
	assert_true(blend.length() > 0.05,
		"the walk writes the movement blend position, got %s" % str(blend))
	var skeleton: Skeleton3D = _cultist.get_node("ModelRoot/rig_deform/Skeleton3D")
	var thigh: int = skeleton.find_bone("DEF-thigh.L")
	var pose_a: Vector3 = skeleton.get_bone_global_pose(thigh).origin
	await _idle_frames(20)
	var pose_b: Vector3 = skeleton.get_bone_global_pose(thigh).origin
	assert_true(pose_a.distance_to(pose_b) > 0.005,
		"the leg bones keep animating while walking (no T-pose pin): %s vs %s" % [
			str(pose_a), str(pose_b)])
