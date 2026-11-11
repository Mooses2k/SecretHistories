extends GutTest

## Pins issue #623 (explosion camera shake). 3.x ground truth: origin/main
## scenes/objects/pickable_items/equipment/consumable/bomb/bomb.gd:71-72
## called owner_character.fps_camera.add_stress(0.5) when the owner player
## body was inside the BlastRadius overlap. Dev4 wires the same amount into
## the runtime-mounted CameraStressShake on the player camera, so only the
## player camera shakes. Uses the same real-scenario harness as the bomb
## damage pins (test_bomb_scenario_damage.gd).

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const CULTIST_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const GRENADE_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/bomb/grenade/grenade.tscn"
const CAMERA_SHAKE_SCRIPT := preload("res://scenes/characters/player/camera_stress_shake.gd")

var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game


func before_each() -> void:
	# Same headless stub set as the bomb damage pins: GameManager.game with a
	# level, a GameUI/HUD pair, and a floor plane so bodies rest like they do
	# in a level.
	_saved_game = GameManager.game
	await _physics_frames(2)
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
	_add_floor()


func after_each() -> void:
	_world.free()
	GameManager.game = _saved_game
	_game.free()
	_level.free()
	_ui.free()
	_hud.free()


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 0.5, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)


func _spawn_character(scene_path : String, at : Vector3) -> Node3D:
	var character : Node3D = (load(scene_path) as PackedScene).instantiate()
	character.position = at
	_world.add_child(character)
	if character is Player:
		_game.player = character
	await _physics_frames(5)
	return character


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _rest_grenade(at : Vector3) -> RigidBody3D:
	var bomb : RigidBody3D = (load(GRENADE_SCENE) as PackedScene).instantiate()
	bomb.name = "ScenarioBomb"
	_world.add_child(bomb)
	bomb.global_position = at
	await _physics_frames(5)
	assert_gt(bomb.global_position.y, 0.0, "the grenade rests on the floor instead of falling through")
	return bomb


func _player_camera(player : Node3D) -> Node:
	var camera : Node = player.get_node("ModelRoot/MainCamera")
	return camera


func test_explosion_with_the_player_inside_the_blast_shakes_the_player_camera() -> void:
	var player : Node3D = await _spawn_character(PLAYER_SCENE, Vector3(2.0, 0.0, 2.0))
	var camera := _player_camera(player)
	assert_not_null(camera, "the player camera node exists")
	assert_eq(camera.get_script(), CAMERA_SHAKE_SCRIPT,
			"the player camera carries the stress shake mount")
	var bomb : RigidBody3D = await _rest_grenade(Vector3(2.0, 0.14, 2.5))
	bomb.set("owner_character", player)

	bomb.call("_on_Countdown_timeout")
	await _physics_frames(2)

	assert_gt(camera.get("stress"), 0.0,
			"an explosion with the owner player inside the blast radius adds camera stress")


func test_explosion_outside_the_blast_radius_does_not_shake_the_camera() -> void:
	var player : Node3D = await _spawn_character(PLAYER_SCENE, Vector3(2.0, 0.0, 2.0))
	var camera := _player_camera(player)
	var bomb : RigidBody3D = await _rest_grenade(Vector3(40.0, 0.14, 40.0))
	bomb.set("owner_character", player)

	bomb.call("_on_Countdown_timeout")
	await _physics_frames(2)

	assert_eq(camera.get("stress"), 0.0,
			"an explosion far outside the blast radius adds no camera stress")


func test_a_cultist_owned_explosion_does_not_shake_the_player_camera() -> void:
	var player : Node3D = await _spawn_character(PLAYER_SCENE, Vector3(2.0, 0.0, 2.0))
	var camera := _player_camera(player)
	var cultist : Node3D = await _spawn_character(CULTIST_SCENE, Vector3(6.0, 0.0, 6.0))
	var bomb : RigidBody3D = await _rest_grenade(Vector3(6.0, 0.14, 6.5))
	bomb.set("owner_character", cultist)

	bomb.call("_on_Countdown_timeout")
	await _physics_frames(2)

	assert_eq(camera.get("stress"), 0.0,
			"only the player's own explosion shakes the player camera")
