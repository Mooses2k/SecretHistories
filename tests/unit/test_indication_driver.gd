extends GutTest
## The indication driver (3.x origin/main fps_control_mode.gd:104-132
## remainder): while grabbing, every prompt hides; the ignite prompt only
## applies while the ignitable item is DROPPED; a dead player shows no
## prompts. The driver only downgrades: the interact controller's choice is
## filtered, never upgraded.

const DRIVER_SCRIPT := "res://scenes/characters/player/indication_driver.gd"

const STATE_GRAB : int = 2
const STATE_DROPPED : int = 0
const STATE_INVENTORY : int = 1

var _world : Node3D
var _game : Game
var _saved_game : Game
var _ui : GameUI


class InteractStub extends Node:
	# The driver reads GRAB through the script constant map, so the stub
	# mirrors the real InteractState enum.
	const InteractState := {"NONE": 0, "PENDING": 1, "GRAB": 2, "ADS": 3, "HOLD_INTERACT": 4}
	var interact_state : int = 0
	var grabbed_item : RigidBody3D = null
	var interact_target : Node = null


class ItemStub extends Node:
	var item_state : int = 0


func before_each() -> void:
	_saved_game = GameManager.game
	_game = Game.new()
	GameManager.game = _game
	var ui : GameUI = preload("res://scenes/ui/game_ui.tscn").instantiate()
	add_child_autofree(ui)
	_game.ui_root = ui
	_ui = ui
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	GameManager.game = _saved_game
	GameManager.is_player_dead = false
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


## Builds the driver with its exported NodePath aimed at a sibling stub
## controller. The ignite target, when given, is parented to the item stub so
## the driver's real get_parent() walk matches the live ignite-area shape.
func _make_driver(grabbed_item : RigidBody3D = null, ignite_item : ItemStub = null) -> Node:
	var interact := InteractStub.new()
	interact.name = "InteractStub"
	interact.grabbed_item = grabbed_item
	_world.add_child(interact)
	if ignite_item != null:
		ignite_item.name = "ItemStub"
		_world.add_child(ignite_item)
		var ignite_target := Node.new()
		ignite_target.name = "IgniteArea"
		ignite_item.add_child(ignite_target)
		interact.interact_target = ignite_target
	var driver : Node = (load(DRIVER_SCRIPT) as GDScript).new()
	driver.set("interact_controller_path", NodePath("../" + interact.name))
	_world.add_child(driver)
	return driver


func _hud_active() -> int:
	return _ui.hud_root.active_indicator


func _set_active(value : int) -> void:
	_ui.hud_root.active_indicator = value


# --------------------------------------------------------------------------
# Dead: nothing shows over the death cover
# --------------------------------------------------------------------------
func test_dead_player_shows_no_indicator() -> void:
	var driver : Node = _make_driver()
	_set_active(1)  # HUD.Indicator.DOT
	GameManager.is_player_dead = true

	driver.call("_process", 0.016)

	assert_eq(_hud_active(), 3, "a dead player hides every prompt (HUD.Indicator.NONE)")


# --------------------------------------------------------------------------
# Grabbing: every prompt hides, 3.x hid grab, ignite and dot while is_grabbing
# --------------------------------------------------------------------------
func test_grabbing_hides_every_indicator() -> void:
	var body : RigidBody3D = autofree(RigidBody3D.new())
	var driver : Node = _make_driver(body)
	_world.get_node("InteractStub").interact_state = STATE_GRAB
	_set_active(1)  # DOT

	driver.call("_process", 0.016)

	assert_eq(_hud_active(), 3, "while grabbing, the dot hides (HUD.Indicator.NONE)")


func test_grab_state_without_a_body_keeps_the_indicator() -> void:
	var driver : Node = _make_driver(null)
	# A stale GRAB state with no grabbed body is not grabbing.
	var stub : Node = _world.get_node("InteractStub")
	stub.interact_state = STATE_GRAB
	_set_active(1)

	driver.call("_process", 0.016)

	assert_eq(_hud_active(), 1, "no valid grabbed body: the dot stays")


# --------------------------------------------------------------------------
# Ignite: only a DROPPED item shows the prompt, 3.x item_state check
# --------------------------------------------------------------------------
func test_ignite_on_dropped_item_stays() -> void:
	var item := ItemStub.new()
	item.item_state = STATE_DROPPED
	autofree(item)
	var driver : Node = _make_driver(null, item)

	_set_active(2)  # HUD.Indicator.IGNITE
	driver.call("_process", 0.016)

	assert_eq(_hud_active(), 2, "an ignite prompt on a DROPPED item stays")


func test_ignite_on_non_dropped_item_hides() -> void:
	var item := ItemStub.new()
	item.item_state = STATE_INVENTORY
	autofree(item)
	var driver : Node = _make_driver(null, item)

	_set_active(2)
	driver.call("_process", 0.016)

	assert_eq(_hud_active(), 3, "the ignite prompt hides for a non-dropped item")


func test_ignite_without_a_target_hides() -> void:
	var driver : Node = _make_driver()
	_set_active(2)

	driver.call("_process", 0.016)

	assert_eq(_hud_active(), 3, "an ignite prompt with no target hides")


# --------------------------------------------------------------------------
# The driver never upgrades: the interact controller stays the single writer
# --------------------------------------------------------------------------
func test_driver_never_upgrades_a_hidden_indicator() -> void:
	var item := ItemStub.new()
	item.item_state = STATE_DROPPED
	autofree(item)
	var driver : Node = _make_driver(null, item)

	_set_active(3)  # NONE, e.g. nothing under the crosshair
	driver.call("_process", 0.016)

	assert_eq(_hud_active(), 3, "the driver leaves NONE alone: no upgrade path")
