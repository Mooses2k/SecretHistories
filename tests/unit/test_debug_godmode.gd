# Godmode port tests (M7): the 3.x debug_godmode handler restored. Pinned
# here, per 3.x truth (origin/main player_controller.gd:862-870): enabling
# raises the max pool to 55555 and refills it; disabling restores the
# previous max and refills to it (3.x wrote both health fields back to its
# 100 default); damage still subtracts while godmode is on (3.x
# character.gd:322-324 subtracts unconditionally), so invulnerability is
# the pool size, not a zeroed damage path; and with godmode off the normal
# damage path is unchanged.
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _world : Node3D
var _game : Game
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _saved_dead : bool


func before_each() -> void:
	# Headless stub set that keeps the real per-frame handlers error-free
	# (interact_controller needs ui_root.hud_root). Same pattern as the ADS
	# tests.
	_saved_game = GameManager.game
	_world = Node3D.new()
	add_child_autofree(_world)
	_game = Game.new()
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
	_saved_dead = GameManager.is_player_dead
	GameManager.is_player_dead = false


func after_each() -> void:
	GameManager.is_player_dead = _saved_dead
	GameManager.game = _saved_game
	# Free the stub set the ADS tests free: the world content is released
	# by add_child_autofree, these three never enter the tree.
	_hud.free()
	_ui.free()
	_game.free()


func _spawn_player() -> HumanoidCharacter:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.5, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	var player : HumanoidCharacter = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	for i in 5:
		await get_tree().physics_frame
	_mark_preexisting_asset_noise_handled()
	return player


func _mark_preexisting_asset_noise_handled() -> void:
	for err in get_errors():
		if not err.handled and (
			err.contains_text("invalid UID")
			or err.contains_text("Skeleton uses old pose format")
			or err.contains_text("Mesh uses old surface format")
			# Another bridge lane's client can eval into this headless
			# instance while it holds port 9090; that parse error is the
			# eval channel, not this suite.
			or err.contains_text("Identifier \"GameState\"")
		):
			err.handled = true


func _controller(player : HumanoidCharacter) -> PlayerController:
	return player.get_node("PlayerController") as PlayerController


func _hurtbox(player : HumanoidCharacter) -> Hurtbox:
	var found := player.find_children("*", "Hurtbox", true, false)
	assert_gt(found.size(), 0, "sanity: the player rig carries hurtboxes")
	return found[0] as Hurtbox


func test_enable_raises_the_pool_to_55555() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	assert_eq(player.state.parameters.max_durability, 100, "sanity: the dev4 max pool default matches the 3.x max_health 100 default")
	pc.toggle_godmode()
	assert_eq(player.state.parameters.max_durability, PlayerController.GODMODE_POOL, "enable raises the max pool to the 3.x 55555")
	assert_eq(player.state.durability, PlayerController.GODMODE_POOL, "enable refills the pool")


func test_damage_while_godmode_cannot_kill() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	pc.toggle_godmode()
	var hurtbox := _hurtbox(player)
	hurtbox.damage(5, GlobalConsts.AttackTypes.BLUDGEONING, Vector3.ZERO, Vector3.ZERO)
	assert_eq(player.state.durability, PlayerController.GODMODE_POOL - 5, "damage still subtracts while godmode is on, per the 3.x semantics")
	assert_eq(player.state.physical_state, HumanoidCharacterState.PhysicalState.NORMAL, "no ragdoll and no death from ordinary damage while godmode is on")


func test_disable_restores_the_pool_and_refills() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	pc.toggle_godmode()
	pc.toggle_godmode()
	assert_eq(player.state.parameters.max_durability, 100, "disable restores the original max pool")
	assert_eq(player.state.durability, 100, "disable refills to the restored max, the same full refill 3.x produced")


func test_godmode_off_damage_is_normal() -> void:
	var player := await _spawn_player()
	var hurtbox := _hurtbox(player)
	hurtbox.damage(5, GlobalConsts.AttackTypes.BLUDGEONING, Vector3.ZERO, Vector3.ZERO)
	assert_eq(player.state.durability, 95, "with godmode off the normal damage path is unchanged")
