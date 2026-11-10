extends GutTest

## Save compatibility surface: SaveManager capture reads `ai.ai_state.target`
## (a Player-or-null) and restore writes the game player into it. The
## phase-1 AIController binds its `ai_state` to the blackboard, so the
## blackboard's target IS the compat surface. The live BT surface is pinned
## unchanged here too.

const NEOPHYTE_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const PLAYER_SCRIPT := "res://scenes/characters/player/player.gd"
const AI_CONTROLLER_SCRIPT := "res://scenes/characters/cultist/ai_controller.gd"
const H := preload("res://tests/unit/hfsm_test_harness.gd")

var _cultist: Node


func after_each() -> void:
	if is_instance_valid(_cultist):
		_cultist.free()
	_cultist = null


func _capture_target_marker(ai_state: Object) -> String:
	# Mirrors save_manager.gd's capture check exactly.
	if ai_state.target != null and ai_state.target is Player:
		return "player"
	return ""


func test_blackboard_target_carries_the_capture_read() -> void:
	var board := Blackboard.new()
	assert_eq(_capture_target_marker(board), "", "no target saves no marker")
	var player := H.bare_player()
	board.target = player
	assert_eq(_capture_target_marker(board), "player", "a player target saves the marker")
	player.free()


func test_blackboard_target_takes_the_restore_write() -> void:
	var board := Blackboard.new()
	var player := H.bare_player()
	board.target = player
	assert_eq(_capture_target_marker(board), "player",
		"the restore write lands where the next capture reads it")
	player.free()


func test_a_non_player_object_never_saves_the_marker() -> void:
	var board := Blackboard.new()
	var item := Node3D.new()
	board.target = item
	assert_eq(_capture_target_marker(board), "", "only a Player target saves the marker")
	item.free()


func test_the_live_cultist_still_exposes_the_ai_state_target_surface() -> void:
	_cultist = (load(NEOPHYTE_SCENE) as PackedScene).instantiate()
	add_child(_cultist)
	var controller: Node = null
	var controller_script: GDScript = load(AI_CONTROLLER_SCRIPT)
	for child in _cultist.get_children():
		if child.get_script() == controller_script:
			controller = child
	assert_not_null(controller, "the live AIController is found by script path like SaveManager does")
	var ai_state: Object = controller.get("ai_state")
	assert_not_null(ai_state, "the live controller carries ai_state")
	assert_true("target" in ai_state, "the surface exposes target")
	assert_null(ai_state.get("target"), "a fresh cultist has no target")
	var player := H.bare_player()
	ai_state.set("target", player)
	assert_eq(ai_state.get("target"), player, "the restore write-through works on the live surface")
	player.free()
