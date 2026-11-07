# Pins the additive separately bindable triggers (issue #606, extends the
# #307 declarative map): kick, interact and ads are NEW InputMap actions
# that ship UNBOUND, so the contextual integrated paths (sprint tap kick,
# RMB tap interact, RMB hold ADS) remain the sole behavior by default and
# binding a key adds a dedicated trigger alongside. The additive wiring
# lives in interact_controller.gd (non-frozen); the contextual kick trigger
# lives in the contributor-frozen player_controller.gd and is untouched.
# Same frame dedupe: both kick paths share the single HumanoidCharacter.kick()
# execution point, and the additive side also refuses when the kick cooldown
# is already running, so exactly one kick lands per frame (observed via the
# 50 stamina cost).
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const FLOOR_CANDELABRA_SCENE := "res://scenes/objects/large_objects/lighting/floor_candelabra.tscn"
const KICK := &"kick"
const INTERACT := &"interact"
const ADS := &"ads"


var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _delivered_candles : Array[CandleItem] = []


func before_each() -> void:
	# Same headless stub set as test_floor_candelabra_take: keeps the real
	# per-frame handlers of the spawned player error-free.
	_saved_game = GameManager.game
	_world = Node3D.new()
	_world.name = "TestWorld"
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
	# The three actions ship unbound: strip any temp binding a test added.
	for action in [KICK, INTERACT, ADS]:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
	_world.free()
	GameManager.game = _saved_game
	_game.free()
	_level.free()
	_ui.free()
	_hud.free()
	_free_delivered_candles()


func test_new_actions_ship_unbound() -> void:
	for action in [KICK, INTERACT, ADS]:
		assert_true(InputMap.has_action(action), "%s exists in InputMap" % action)
		assert_eq(InputMap.action_get_events(action).size(), 0,
				"%s has no default binding" % action)


func test_binding_map_registers_the_three_rows_in_their_families() -> void:
	var expected := {
		KICK: ["Footwork and Movement", "Kick (separate key)"],
		INTERACT: ["Player Actions", "Interact (separate key)"],
		ADS: ["Player Actions", "ADS (separate key)"],
	}
	for action in [KICK, INTERACT, ADS]:
		assert_true(Settings.has_setting(action), "row registered for %s" % action)
		assert_eq(Settings.get_setting_group(action), "Input Key Settings")
		assert_eq(str(Settings.get_setting_meta(action, "key_category")),
				expected[action][0])
		assert_eq(str(Settings.get_setting_meta(action, "display_name")),
				expected[action][1])
		assert_true(Settings.get_setting(action) is PackedStringArray,
				"row value populated for %s" % action)


func test_reset_keeps_the_new_actions_unbound() -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_P
	KeyInputSettings.apply_binding(KICK, key_event)
	assert_eq(InputMap.action_get_events(KICK).size(), 1,
			"precondition: the user bound a key to kick")
	KeyInputSettings.reset_actions()
	assert_eq(InputMap.action_get_events(KICK).size(), 0,
			"reset leaves kick unbound: no project.godot default exists")
	assert_eq(InputMap.action_get_events(INTERACT).size(), 0, "interact stays unbound")
	assert_eq(InputMap.action_get_events(ADS).size(), 0, "ads stays unbound")


func _spawn_player() -> Node3D:
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = Vector3(2.0, 0.0, 2.0)
	_world.add_child(player)
	return player


func _spawn_stand() -> Node:
	var stand : Node = (load(FLOOR_CANDELABRA_SCENE) as PackedScene).instantiate()
	_world.add_child(stand)
	return stand


func _interact_controller(player : Node3D) -> Node:
	return player.get_node("PlayerController/InteractController")


func _key_press(keycode : Key, pressed : bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


func _temp_bind(action : StringName, keycode : Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _free_delivered_candles() -> void:
	for candle : CandleItem in _delivered_candles:
		if is_instance_valid(candle):
			candle.free()
	_delivered_candles.clear()


func _delivered_candle_count(inv : Inventory) -> int:
	var found := 0
	for slot in inv.hotbar:
		var item := slot as CandleItem
		if item != null and is_instance_valid(item):
			found += 1
			_delivered_candles.append(item)
	return found


func test_kick_action_kicks_without_any_movement_context() -> void:
	var player : Node3D = _spawn_player()
	var character := player as HumanoidCharacter
	var state := character.state
	state.stamina = 100.0
	state.time_since_kick = 10.0
	_temp_bind(KICK, KEY_P)

	# No movement, no sprint: the only source is the just-pressed kick key.
	_interact_controller(player)._unhandled_input(_key_press(KEY_P, true))

	assert_almost_eq(state.stamina, 50.0, 0.0001,
			"the kick key fires the real kick (50 stamina cost)")


func test_contextual_kick_and_kick_action_in_one_frame_kick_once() -> void:
	var player : Node3D = _spawn_player()
	var character := player as HumanoidCharacter
	var state := character.state
	state.stamina = 100.0
	state.time_since_kick = 10.0
	_temp_bind(KICK, KEY_P)
	var ic : Node = _interact_controller(player)

	# Contextual path fires (player_controller calls the shared
	# HumanoidCharacter.kick()), then the key event lands the same frame.
	character.kick()
	ic._unhandled_input(_key_press(KEY_P, true))
	assert_almost_eq(state.stamina, 50.0, 0.0001,
			"the additive side dedupes against a fresh contextual kick")

	# Reverse order: the key lands first, the contextual call is blocked
	# by the shared execution point's cooldown guard.
	state.time_since_kick = 10.0
	state.stamina = 100.0
	ic._unhandled_input(_key_press(KEY_P, true))
	character.kick()
	assert_almost_eq(state.stamina, 50.0, 0.0001,
			"one kick per frame regardless of trigger order")


func test_interact_action_taps_interact_without_rmb() -> void:
	var player : Node3D = _spawn_player()
	var stand : Node = _spawn_stand()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var ic : Node = _interact_controller(player)
	ic.interact_target = stand.get_node("Ignite")
	_temp_bind(INTERACT, KEY_I)

	ic._unhandled_input(_key_press(KEY_I, true))

	assert_eq(_delivered_candle_count(inv), 1,
			"the interact key tap goes through the real interact path")


func test_interact_action_prefers_the_pickup_target() -> void:
	var player : Node3D = _spawn_player()
	var candle : Node3D = (load(
			"res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle_tall.tscn") as PackedScene).instantiate()
	_world.add_child(candle)
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var ic : Node = _interact_controller(player)
	ic.pick_target = candle as PickableItem
	_temp_bind(INTERACT, KEY_I)

	ic._unhandled_input(_key_press(KEY_I, true))

	assert_eq(_delivered_candle_count(inv), 1,
			"the tiny pickup arbitration wins on the interact key too")
	assert_null(ic.pick_target, "the pick is consumed")


func test_ads_action_engages_and_disengages_ads() -> void:
	var player : Node3D = _spawn_player()
	var ic : Node = _interact_controller(player)
	_temp_bind(ADS, KEY_V)

	ic._unhandled_input(_key_press(KEY_V, true))
	assert_eq(ic.interact_state, ic.InteractState.ADS, "the ads key engages ADS")

	ic._unhandled_input(_key_press(KEY_V, false))
	assert_eq(ic.interact_state, ic.InteractState.NONE, "the ads key release disengages")


func test_ads_holds_until_both_sources_release() -> void:
	var player : Node3D = _spawn_player()
	var ic : Node = _interact_controller(player)
	_temp_bind(ADS, KEY_V)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true

	# Contextual hold engages ADS on empty air.
	ic._unhandled_input(rmb)
	assert_eq(ic.interact_state, ic.InteractState.ADS, "RMB hold engages ADS")
	# The ads key joins the hold.
	ic._unhandled_input(_key_press(KEY_V, true))
	assert_true(ic._ads_action_held, "the ads key is tracked as held")
	# RMB releases first: the ads key keeps the state.
	var rmb_up := rmb.duplicate() as InputEventMouseButton
	rmb_up.pressed = false
	ic._unhandled_input(rmb_up)
	assert_eq(ic.interact_state, ic.InteractState.ADS,
			"ADS stays engaged while the ads key is still held")
	# The ads key releases: both sources are up, ADS disengages.
	ic._unhandled_input(_key_press(KEY_V, false))
	assert_eq(ic.interact_state, ic.InteractState.NONE,
			"ADS disengages when both sources are released")


func test_contextual_ads_works_while_the_new_actions_stay_unbound() -> void:
	var player : Node3D = _spawn_player()
	var ic : Node = _interact_controller(player)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	var rmb_up := InputEventMouseButton.new()
	rmb_up.button_index = MOUSE_BUTTON_RIGHT

	assert_eq(InputMap.action_get_events(ADS).size(), 0, "precondition: ads unbound")
	ic._unhandled_input(rmb)
	assert_eq(ic.interact_state, ic.InteractState.ADS, "RMB alone still engages ADS")
	ic._unhandled_input(rmb_up)
	assert_eq(ic.interact_state, ic.InteractState.NONE, "RMB release disengages")


func test_unbound_new_actions_never_fire() -> void:
	var player : Node3D = _spawn_player()
	var character := player as HumanoidCharacter
	var state := character.state
	state.stamina = 100.0
	state.time_since_kick = 10.0
	var ic : Node = _interact_controller(player)
	# The key events match nothing while the actions carry zero events.
	ic._unhandled_input(_key_press(KEY_P, true))
	ic._unhandled_input(_key_press(KEY_I, true))
	ic._unhandled_input(_key_press(KEY_V, true))
	ic._unhandled_input(_key_press(KEY_V, false))

	assert_almost_eq(state.stamina, 100.0, 0.0001, "no kick fired")
	assert_eq(ic.interact_state, ic.InteractState.NONE, "no ADS engaged")
