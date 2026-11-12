extends Node
## Filters the HUD crosshair indicators with the 3.x conditions the dev4
## interact controller does not apply (origin/main
## scenes/characters/player/fps_control_mode.gd:104-132): while the player is
## grabbing, every prompt hides (3.x hid grab, ignite and dot while
## is_grabbing); the ignite prompt only applies while the ignitable item is
## DROPPED; and a dead player never shows prompts, the death screen owns the
## screen. The driver only ever downgrades: the interact controller stays the
## single writer of the indicator choice, and this node processes after
## PlayerController in tree order, so the filtered value is the final state of
## the frame.

const DROPPED_STATE : int = GlobalConsts.ItemState.DROPPED

@export var interact_controller_path : NodePath = ^"../PlayerController/InteractController"

@onready var _interact_controller : Node = get_node(interact_controller_path)


func _process(_delta : float) -> void:
	var game : Game = GameManager.game
	if game == null or game.ui_root == null:
		return
	var hud : HUD = game.ui_root.hud_root
	if hud == null:
		return
	if GameManager.is_player_dead:
		hud.active_indicator = HUD.Indicator.NONE
		return
	if _is_grabbing():
		hud.active_indicator = HUD.Indicator.NONE
		return
	if hud.active_indicator == HUD.Indicator.IGNITE and not _ignite_target_is_dropped():
		hud.active_indicator = HUD.Indicator.NONE


func _is_grabbing() -> bool:
	# InteractState.GRAB is read through the script's constant map: dot access
	# on script constants through an instance does not resolve.
	var constants : Dictionary = _interact_controller.get_script().get_script_constant_map()
	var states : Variant = constants.get("InteractState")
	if states is Dictionary and states.get("GRAB") != null:
		return _interact_controller.interact_state == states.get("GRAB") \
				and is_instance_valid(_interact_controller.grabbed_item)
	return false


func _ignite_target_is_dropped() -> bool:
	var target : Node = _interact_controller.interact_target as Node
	if target == null or not is_instance_valid(target):
		return false
	var item : Node = target.get_parent()
	if item == null:
		return false
	var state : Variant = item.get("item_state")
	return state != null and state == DROPPED_STATE
