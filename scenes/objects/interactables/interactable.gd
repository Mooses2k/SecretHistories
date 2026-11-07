class_name Interactable
extends Area3D


signal character_interacted(character)

## Opt-in hold-to-interact semantics (Amnesia style, doors #17): when true,
## the player interact controller fires interact() when the button is HELD
## past the grab threshold instead of falling back to ADS, and a quick tap
## still calls interact() so the target itself can decide that a tap does
## nothing. Default false keeps the old tap-triggered behavior for every
## other interactable.
@export var hold_interact : bool = false

## Set by the player interact controller right before each interact() call:
## true when the call comes from a held press past the grab threshold,
## false when it comes from a quick tap. Targets that care read this; the
## controller owns the timing because only it sees the press duration.
var interact_press_was_hold : bool = false

## Node that receives hold-follow updates for this target. The player
## interact controller only sees the Area3D, so hold-to-drag targets (doors)
## register themselves here in _ready(); the relay below forwards the drag
## feed and the release into the real owner. Targets that only react to a
## tap or a hold without following a ray (no owner set) are unaffected.
var hold_follow_owner : Node = null


func interact(character):
	_interact(character)
	emit_signal("character_interacted", character)


## Relayed every physics frame while the player holds this target past the
## interact threshold (interact_controller._physics_process).
func interact_hold_update(origin : Vector3, dir : Vector3):
	if is_instance_valid(hold_follow_owner) and hold_follow_owner.has_method(&"interact_hold_update"):
		hold_follow_owner.interact_hold_update(origin, dir)


## Relayed when the player releases the held interact key.
func interact_hold_end():
	if is_instance_valid(hold_follow_owner) and hold_follow_owner.has_method(&"interact_hold_end"):
		hold_follow_owner.interact_hold_end()


func _interact(character):
	pass
