# Heal over time for single-use medicals (owner model b): a used item starts a
# regen pool on the owner's HumanoidCharacterState durability. Pins: durability
# climbs over real physics frames, a hit mid-regen does not cancel the pool,
# restore caps at max durability, pools from two uses stack additively,
# regen dies with death, a stacked in-hand use materializes the next unit, and
# a container spends exactly the charges the missing durability needs.
extends GutTest

const MEDICAL_SCRIPT = preload("res://scenes/objects/pickable_items/equipment/consumable/medical/_medical_item.gd")
const CANDLES_STACK := "res://resources/inventory/stackables/candles_stack.tres"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _world : Node3D
var _tracked : Array[Node] = []
var _game : Game
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _game_stubbed : bool = false


func before_each() -> void:
	_world = Node3D.new()
	_world.name = "TestWorld"
	add_child(_world)


func after_each() -> void:
	_world.free()
	for node in _tracked:
		if is_instance_valid(node):
			node.free()
	_tracked.clear()


func after_all() -> void:
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_ui):
		_ui.free()
	if is_instance_valid(_hud):
		_hud.free()
	if _game_stubbed:
		GameManager.game = _saved_game


func _game_setup() -> void:
	# Headless stub for the player scene's UI access (mirrors
	# test_stack_consume_flows). Idempotent: only the first call captures the
	# real game reference.
	if not _game_stubbed:
		_saved_game = GameManager.game
		_game_stubbed = true
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_ui):
		_ui.free()
	if is_instance_valid(_hud):
		_hud.free()
	_game = Game.new()
	_game.level = null
	_ui = GameUI.new()
	_hud = HUD.new()
	var indicators : Array[TextureRect] = [
		TextureRect.new(), TextureRect.new(), TextureRect.new(),
	]
	for indicator in indicators:
		_hud.add_child(indicator)
	_hud.indicators = indicators
	_ui.hud_root = _hud
	_game.ui_root = _ui
	GameManager.game = _game


func _spawn_player() -> Node3D:
	_game_setup()
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	for i in 5:
		await get_tree().physics_frame
	return player


## A single-use medical with the $Sounds nodes and a $UseTime timer; bare
## .new() nodes have no scene children.
func _make_single_use(heal : int, duration : float) -> MedicalItem:
	var item : MedicalItem = MEDICAL_SCRIPT.new()
	item.max_charges_held = 1
	item.charges_held = 1
	item.heal_amount = heal
	item.heal_duration = duration
	item.time_to_use = 1
	item.item_name = "Bandage"
	item.item_size = GlobalConsts.ItemSize.SIZE_MEDIUM
	var sounds : Node = Node.new()
	sounds.name = "Sounds"
	var use_sound : AudioStreamPlayer = AudioStreamPlayer.new()
	use_sound.name = "Use"
	use_sound.stream = load("res://resources/sounds/fabric/678008__mandy2__fabric-rubbing.mp3")
	sounds.add_child(use_sound)
	var complete_sound : AudioStreamPlayer = AudioStreamPlayer.new()
	complete_sound.name = "UseComplete"
	complete_sound.stream = load("res://resources/sounds/fabric/678008__mandy2__fabric-rubbing.mp3")
	sounds.add_child(complete_sound)
	item.add_child(sounds)
	var use_timer : Timer = Timer.new()
	use_timer.name = "UseTime"
	use_timer.wait_time = 1.0
	use_timer.timeout.connect(item._on_UseTime_timeout)
	item.add_child(use_timer)
	# A bare .new() item is kept out of the tree (its _ready would fail on the
	# scene-only nodes); the @onready use_timer is assigned directly.
	item.use_timer = use_timer
	_tracked.append(item)
	return item


## A charged medical container (doctor's bag shape) with the sound node the
## timeout plays on.
func _make_container(charges : int, heal : int) -> MedicalItem:
	var item : MedicalItem = MEDICAL_SCRIPT.new()
	item.max_charges_held = 10
	item.charges_held = charges
	item.heal_amount = heal
	item.item_name = "Container"
	var sounds : Node = Node.new()
	sounds.name = "Sounds"
	var complete_sound : AudioStreamPlayer = AudioStreamPlayer.new()
	complete_sound.name = "UseComplete"
	sounds.add_child(complete_sound)
	item.add_child(sounds)
	_tracked.append(item)
	return item


func _state_of(player : Node3D) -> HumanoidCharacterState:
	return player.get_node("State") as HumanoidCharacterState


func test_single_use_ticks_durability_up_over_frames_and_consumes_the_last_unit():
	var player : Node3D = await _spawn_player()
	var state : HumanoidCharacterState = _state_of(player)
	var inv : Inventory = player.get_node("Inventory")
	# A real scene instance: the use drive needs the tree (UseTime timer and
	# the Sounds players), so bare .new() does not cut it here.
	var item : MedicalItem = (load("res://scenes/objects/pickable_items/equipment/consumable/medical/bandage.tscn") as PackedScene).instantiate()
	item.heal_amount = 10
	item.heal_duration = 0.5
	item.time_to_use = 1
	item.owner_character = player
	_world.add_child(item)
	_tracked.append(item)
	inv.hotbar[0] = item
	# One record unit: the consumed use is the last unit, so the slot and
	# record clear without materializing a fresh node (the materialize flow
	# is pinned by test_stack_consume_flows).
	inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 1)
	item.stack_record_id = 0
	inv._recount_encumbrance()
	state.durability = 50

	item._use_primary()

	assert_false(item.use_timer.is_stopped(), "the use started the use timer")
	item.use_timer.start(0.2)
	await get_tree().create_timer(0.35).timeout
	var first_sample : int = state.durability
	assert_gt(first_sample, 50, "durability already climbed above the wound floor")
	await get_tree().create_timer(0.5).timeout
	assert_gt(state.durability, first_sample, "durability kept climbing over later frames")
	assert_eq(state.durability, 60, "the use restored exactly its heal total")
	assert_eq(inv.stack_records.size(), 0, "the emptied record is destroyed")
	assert_eq(inv.hotbar[0], null, "the consumed unit's slot is cleared")
	if is_instance_valid(item):
		assert_true(item.is_queued_for_deletion(), "the consumed node is freed")
	else:
		assert_true(true, "the consumed node was already freed before the assert")


func test_hit_mid_regen_does_not_cancel_the_pool():
	var player : Node3D = await _spawn_player()
	var state : HumanoidCharacterState = _state_of(player)
	state.durability = 30
	state.begin_heal_over_time(20, 1.0)

	await get_tree().create_timer(0.2).timeout
	state.durability -= 5   # a hit lands mid-regen
	await get_tree().create_timer(1.0).timeout

	assert_eq(state.durability, 45, "30 - 5 from the hit plus the full 20 regen total")


func test_restore_caps_at_max_durability():
	var player : Node3D = await _spawn_player()
	var state : HumanoidCharacterState = _state_of(player)
	state.durability = 95
	state.begin_heal_over_time(20, 0.5)

	await get_tree().create_timer(1.2).timeout
	assert_eq(state.durability, 100, "the restore stopped at the durability max")
	await get_tree().create_timer(0.4).timeout
	assert_eq(state.durability, 100, "the exhausted pool restores nothing further")


func test_two_uses_stack_additively():
	var player : Node3D = await _spawn_player()
	var state : HumanoidCharacterState = _state_of(player)
	state.durability = 20
	state.begin_heal_over_time(10, 1.0)
	state.begin_heal_over_time(10, 1.0)

	# One pending pool ticks at the item's rate: 20 pending at 10 HP/s needs
	# 2.0 s to drain; stacking adds restore total, not rate.
	await get_tree().create_timer(2.2).timeout

	assert_eq(state.durability, 40, "both pending pools drained: 20 + 10 + 10")


func test_regen_dies_with_death():
	var player : Node3D = await _spawn_player()
	var state : HumanoidCharacterState = _state_of(player)
	state.durability = 50
	state.begin_heal_over_time(10, 1.0)
	state.physical_state = state.PhysicalState.DEAD

	await get_tree().create_timer(0.3).timeout

	assert_eq(state.durability, 50, "a dead character's pending regen restores nothing")


func test_container_spends_exactly_the_charges_the_missing_durability_needs():
	var player : Node3D = await _spawn_player()
	var state : HumanoidCharacterState = _state_of(player)
	var item := _make_container(3, 1)
	item.owner_character = player
	state.durability = 97

	item._on_UseTime_timeout()
	await get_tree().create_timer(0.5).timeout

	assert_eq(item.charges_held, 0, "the bag spent three charges for three missing HP")
	assert_eq(state.durability, 100, "the container's total healed over time up to the cap")
