# Integration-style bomb scenario tests (#407): real grenade scenes, the real
# countdown handler, the real blast raycast in explosions.gd, and the real
# character damage entries. Damage convention pinned by observation: the
# in-hand path calls hurtbox.damage(floori(bomb_damage)) directly (bomb.gd),
# the blast path applies floor(bomb_damage / (1 + distance)) per hurtbox the
# blast raycast reaches (explosions.gd). The BlastRadius sphere is 2.45528 m
# scaled x2 by _bomb.tscn, so the effective blast radius is about 4.91 m and
# the smallest possible per-hurtbox blast amount for a 150 damage grenade is
# floor(150 / (1 + 4.91056)) = 25. Observed current behavior, pinned here: a
# grenade lit in hand kills the player (direct 150 plus reachable blast
# events), a grenade resting at the player's feet knocks the player down
# through the low hurtboxes below the collision cylinder (one 75 point hit in
# the probe), a grenade resting beside a cultist deals heavy damage, and a
# grenade outside the blast radius deals none.
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const CULTIST_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const GRENADE_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/bomb/grenade/grenade.tscn"

const MIN_BLAST_DAMAGE := 25.0
const MAX_BOMB_DAMAGE := 150.0

var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game


func before_each() -> void:
	# Headless stub set that keeps the real per-frame handlers error-free:
	# GameManager.game with a level for effects.gd and inventory drops, a
	# GameUI/HUD pair for interact_controller, and a World floor plane so
	# grenades rest like they do in a level. The level stays out of the tree
	# so its @onready lookups never run. Two physics frames up front let the
	# navigation map synchronize once so the cultist AI's first map query is
	# not made before the first synchronization.
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
	# Free the scene content first so no per-frame handler sees a torn-down
	# stub, then restore the autoload state.
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
	box.size = Vector3(40.0, 0.5, 40.0)
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


func _record_damages(character : Node3D) -> Array[float]:
	var recorder : Array[float] = []
	var hurtboxes : Array = character.find_children("*", "Hurtbox", true, false)
	for h in hurtboxes:
		(h as Hurtbox).damaged.connect(func(amount, type, direction, origin):
			recorder.append(float(amount)))
	return recorder


func _assert_falloff_bounds(amounts : Array) -> void:
	for amount in amounts:
		assert_true(amount >= MIN_BLAST_DAMAGE and amount <= MAX_BOMB_DAMAGE,
			"each blast hit applies floor(150 / (1 + distance)) within the blast radius bounds, got %s" % amount)


func test_grenade_in_hand_applies_full_damage_and_kills_the_player() -> void:
	var player : Node3D = await _spawn_character(PLAYER_SCENE, Vector3(2.0, 0.0, 2.0))
	var bomb : RigidBody3D = (load(GRENADE_SCENE) as PackedScene).instantiate()
	assert_eq(bomb.get("bomb_damage"), 150.0, "the grenade's authored convention damage is 150")
	bomb.set("owner_character", player)
	var hand_root : Node3D = player.get_node("ModelRoot/rig_deform/Skeleton3D/PalmR/MainHandRoot")
	hand_root.add_child(bomb)
	assert_eq(bomb.get_parent(), hand_root, "the in-hand bomb is attached to the hand socket")
	bomb.set("item_state", GlobalConsts.ItemState.EQUIPPED)
	await _physics_frames(3)
	var amounts := _record_damages(player)
	var state : HumanoidCharacterState = player.get_node("State")
	bomb.call("_on_Countdown_timeout")
	await _physics_frames(2)
	assert_true(amounts.has(150.0),
		"the in-hand path applies floori(bomb_damage) = 150 through the first hurtbox")
	_assert_falloff_bounds(amounts.filter(func(a): return a != 150.0))
	assert_true(state.durability <= 0, "one lit grenade in hand kills the player")
	assert_eq(state.physical_state, state.PhysicalState.DEAD,
		"zero durability puts the character into the DEAD state")


func test_grenade_at_the_players_feet_knocks_the_player_down() -> void:
	var player : Node3D = await _spawn_character(PLAYER_SCENE, Vector3(2.0, 0.0, 2.0))
	var bomb : RigidBody3D = await _rest_grenade(Vector3(2.0, 0.14, 2.5))
	var amounts := _record_damages(player)
	var state : HumanoidCharacterState = player.get_node("State")
	bomb.call("_on_Countdown_timeout")
	await _physics_frames(2)
	assert_gt(amounts.size(), 0, "the blast reached at least one hurtbox")
	_assert_falloff_bounds(amounts)
	assert_true(state.durability <= 50,
		"a grenade at the feet crosses the 50 knockdown bar, observed one 75 point hit")
	assert_ne(state.physical_state, state.PhysicalState.NORMAL,
		"the feet grenade leaves the player knocked out or dead")


func test_grenade_beside_a_cultist_deals_heavy_damage() -> void:
	var cultist : Node3D = await _spawn_character(CULTIST_SCENE, Vector3(2.0, 0.0, 6.0))
	var bomb : RigidBody3D = await _rest_grenade(Vector3(2.55, 0.14, 6.0))
	var amounts := _record_damages(cultist)
	var state : HumanoidCharacterState = cultist.get_node("State")
	bomb.call("_on_Countdown_timeout")
	await _physics_frames(2)
	var max_amount := 0.0
	if amounts.size() > 0:
		max_amount = amounts.max()
	_assert_falloff_bounds(amounts)
	assert_gte(max_amount, 60.0,
		"a grenade 0.55 m from the cultist deals at least one heavy close-range hit, observed 67")
	assert_lt(state.durability, 60,
		"the heavy close-range hit alone must land on the shared durability pool")


func test_grenade_outside_the_blast_radius_deals_no_damage() -> void:
	var cultist : Node3D = await _spawn_character(CULTIST_SCENE, Vector3(2.0, 0.0, 6.0))
	var bomb : RigidBody3D = await _rest_grenade(Vector3(2.0, 0.14, 18.0))
	var amounts := _record_damages(cultist)
	var state : HumanoidCharacterState = cultist.get_node("State")
	bomb.call("_on_Countdown_timeout")
	await _physics_frames(2)
	assert_eq(amounts.size(), 0, "12 m is outside the about 10 m grenade blast radius, no hurtbox is reached")
	assert_eq(state.durability, 100, "a far grenade leaves the cultist untouched")


func test_countdown_timeout_frees_the_bomb_via_the_explosion_timer() -> void:
	var bomb : RigidBody3D = await _rest_grenade(Vector3(8.0, 0.14, 8.0))
	bomb.call("_on_Countdown_timeout")
	var timer : Timer = bomb.get_node("Explosion/Timer")
	timer.timeout.emit()
	await _physics_frames(2)
	assert_false(is_instance_valid(bomb),
		"the wired Explosion/Timer timeout frees the bomb owner after the blast")
