extends GutTest

## Spyglass hold-to-zoom (3.x parity): holding ablty|binocs_spyglass while the
## inventory carries the spyglass tiny item lerps the camera fov toward the
## 3.x zoom target (30) and release restores the normal fov. Without the item
## the view stays normal; the spyglass leaving the inventory mid-hold also
## restores. The zoom cycle never touches the camera debug light or the
## transform the active controller owns. The controller is attached at runtime
## by Game.spawn_player; here it is wired the same way against the real
## player scene's camera and inventory.

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const SPYGLASS_ACTION := "ablty|binocs_spyglass"
const SPYGLASS_ITEM := preload("res://resources/tiny_items/spyglass.tres")
const ZOOM_CONTROLLER := preload("res://scenes/characters/player/spyglass_zoom_controller.gd")

var _world : Node3D
var _game : Game
var _saved_game : Game


func before_each() -> void:
	# Same stub set as the screen-filter tests: the real player scene ticks
	# interact_controller, which reads GameManager.game.ui_root every frame.
	_saved_game = GameManager.game
	_game = Game.new()
	GameManager.game = _game
	var ui : GameUI = UI_SCENE.instantiate()
	add_child_autofree(ui)
	_game.ui_root = ui


func after_each() -> void:
	GameManager.game = _saved_game
	if Input.is_action_pressed(SPYGLASS_ACTION):
		Input.action_release(SPYGLASS_ACTION)
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _spawn_player_with_zoom() -> Node:
	# Same runtime wiring as Game.spawn_player: controller node under the
	# player's main camera, then setup(camera, inventory).
	_world = Node3D.new()
	add_child_autofree(_world)
	var player : Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	var camera := player.get_node("ModelRoot/MainCamera") as Camera3D
	var zoom_controller: Node = ZOOM_CONTROLLER.new()
	zoom_controller.name = "SpyglassZoomController"
	camera.add_child(zoom_controller)
	zoom_controller.setup(camera, player.get_node("Inventory") as Inventory,
		player.get_node("PlayerController") as PlayerController)
	await _physics_frames(2)
	return player


func test_action_exists_and_defaults_to_B() -> void:
	assert_true(InputMap.has_action(SPYGLASS_ACTION), "the spyglass action is registered")
	var events := InputMap.action_get_events(SPYGLASS_ACTION)
	var has_b := false
	for event in events:
		var key := event as InputEventKey
		if key != null and key.keycode == KEY_B:
			has_b = true
	assert_true(has_b, "the action defaults to the B key")


func test_holding_the_action_with_the_spyglass_zooms_and_release_restores() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var camera := player.get_node("ModelRoot/MainCamera") as Camera3D
	var inventory := player.get_node("Inventory") as Inventory
	inventory.tiny_items[SPYGLASS_ITEM] = 1
	Input.action_press(SPYGLASS_ACTION)
	await _physics_frames(40)
	assert_almost_eq(camera.fov, 30.0, 0.05,
		"held with the spyglass, fov converges to the 3.x zoom target")
	Input.action_release(SPYGLASS_ACTION)
	await _physics_frames(120)
	assert_almost_eq(camera.fov, 75.0, 0.05, "release restores the normal fov")


func test_holding_the_action_without_the_spyglass_keeps_normal_fov() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var camera := player.get_node("ModelRoot/MainCamera") as Camera3D
	Input.action_press(SPYGLASS_ACTION)
	await _physics_frames(40)
	assert_almost_eq(camera.fov, 75.0, 0.001, "no spyglass, no zoom")
	Input.action_release(SPYGLASS_ACTION)


func test_spyglass_leaving_the_inventory_midhold_restores() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var camera := player.get_node("ModelRoot/MainCamera") as Camera3D
	var inventory := player.get_node("Inventory") as Inventory
	inventory.tiny_items[SPYGLASS_ITEM] = 1
	Input.action_press(SPYGLASS_ACTION)
	await _physics_frames(10)
	inventory.tiny_items.erase(SPYGLASS_ITEM)
	await _physics_frames(120)
	assert_almost_eq(camera.fov, 75.0, 0.05, "losing the spyglass mid-hold ends the zoom")
	Input.action_release(SPYGLASS_ACTION)


func test_zoom_cycle_leaves_debug_light_and_transform_untouched() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var camera := player.get_node("ModelRoot/MainCamera") as Camera3D
	var light := player.get_node_or_null("ModelRoot/DebugLight") as SpotLight3D
	if light == null:
		light = player.get_node("ModelRoot/MainCamera/DebugLight") as SpotLight3D
	var inventory := player.get_node("Inventory") as Inventory
	inventory.tiny_items[SPYGLASS_ITEM] = 1
	Input.action_press(SPYGLASS_ACTION)
	await _physics_frames(40)
	assert_false(light.visible, "zooming does not turn the L debug light on")
	Input.action_release(SPYGLASS_ACTION)
	await _physics_frames(120)
	assert_almost_eq(camera.fov, 75.0, 0.05, "fov restored")
	assert_almost_eq(camera.rotation.x, 0.0, 0.0001,
		"the active controller's camera pitch is untouched")
	assert_almost_eq(camera.position.y, 1.6, 0.0001,
		"the active controller's camera height is untouched")
