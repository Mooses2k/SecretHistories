extends GutTest

## Pins issue #749 (cultist drop sounds). The 3.x ground truth:
## origin/main scenes/characters/character.gd:326-331 drops the hands'
## equipment when a NON-player character dies, so the falling items play
## their impact sounds (origin/main scenes/objects/pickable_items/
## pickable_item.gd play_drop_sound, the per-item drop sound family). Dev4
## cultists never dropped anything on death, so the sound machinery had no
## trigger. Pins:
## 1. A dead cultist drops the mainhand item into the live level in DROPPED
##    state, which is what lets the item audio manager play the drop sound
##    and set the noise level for AI hearing.
## 2. The drop goes through the inventory API (hands and hotbar clear).
## 3. The player is excluded exactly as 3.x excluded it.

const NEOPHYTE_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const TORCH_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.tscn"

var _saved_game : Game
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD


func before_each() -> void:
	# Same stub set as the bomb scenario pins: a Game with a level for the
	# inventory drop path, and a GameUI/HUD pair so per-frame handlers stay
	# error-free when the player dies.
	_saved_game = GameManager.game
	_game = Game.new()
	_level = GameWorld.new()
	_level.name = "Level"
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
	GameManager.game = _saved_game
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_level):
		_level.free()
	if is_instance_valid(_ui):
		_ui.free()
	if is_instance_valid(_hud):
		_hud.free()
	_game = null
	_level = null
	_ui = null
	_hud = null


func _boot_cultist() -> Node:
	var cultist : Node = (load(NEOPHYTE_SCENE) as PackedScene).instantiate()
	add_child_autofree(cultist)
	return cultist


func _equip_torch(inventory : Inventory) -> EquipmentItem:
	var torch : EquipmentItem = (load(TORCH_SCENE) as PackedScene).instantiate()
	# The torch scene is the suite's proven warning-free equipment item.
	assert_true(inventory.add_item(torch), "the character picks the item up")
	inventory.equip_mainhand_item()
	# equip_mainhand_item is async (the 0.5 s issue #409 timer): wait it out
	# before asserting the equipped state.
	await get_tree().create_timer(0.6).timeout
	return torch


func test_dead_cultist_drops_the_mainhand_item_into_the_level() -> void:
	var cultist := _boot_cultist()
	var inventory : Inventory = cultist.get_node("Inventory")
	var torch : EquipmentItem = await _equip_torch(inventory)
	assert_eq(torch.item_state, GlobalConsts.ItemState.EQUIPPED,
			"the item is equipped before death")
	assert_true(cultist.is_ancestor_of(torch),
			"the item rides the cultist before death")

	cultist.state.durability = 0

	assert_eq(torch.item_state, GlobalConsts.ItemState.DROPPED,
			"death drops the mainhand item into DROPPED state")
	assert_true(_level.is_ancestor_of(torch),
			"the dropped item re-parents to the live level so it can fall and sound")
	assert_null(inventory.get_mainhand_item(), "the hand is empty after the death drop")


func test_player_death_does_not_drop_equipment() -> void:
	var player : HumanoidCharacter = (load(PLAYER_SCENE) as PackedScene).instantiate()
	add_child_autofree(player)
	var inventory : Inventory = player.get_node("Inventory")
	var torch : EquipmentItem = await _equip_torch(inventory)

	player.state.durability = 0

	assert_eq(torch.item_state, GlobalConsts.ItemState.EQUIPPED,
			"the player is excluded from the death drop, exactly as 3.x excluded it")
