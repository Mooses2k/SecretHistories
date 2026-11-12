#extended only for class_name reasons
extends HumanoidCharacter
class_name Player


## The belt hook attach point (3.x scenes/characters/character.tscn:160
## BeltPosition, same translation): a stowed can_attach lantern parents here
## and keeps burning. Rigs without the marker leave this null, which keeps
## Inventory.attach_to_belt a safe no-op on NPCs and the bare humanoid.
@onready var belt_position: Marker3D = get_node_or_null("BeltPosition") as Marker3D

## The KinestheticSense darkness glow (3.x scenes/characters/player/player.gd:49-57
## plus the player.tscn OmniLight): a cyan light on the player that breathes up
## to energy 0.2 while light_level is at or below the sight-gate threshold and
## fades back to 0 in the light: the diegetic "it is dark here" affordance.
## The sampled light_level feeds this same condition, so the glow feeds back
## into its own trigger; 3.x bounded that loop, it did not exclude the light:
## the glow's light_cull_mask stayed at the all-layers default, and the
## feedback was tamed by the 1.0 s tween toward a target capped at 0.2, which
## settles as a slow relaxation loop around the tiny 0.003 threshold. The
## tween is recreated toward the current target every _process for the same
## per-frame retargeting behavior. Player-only: the node is authored on
## player.tscn, and rigs without it stay dark and null-safe.
const KINESTHETIC_DARKNESS_LEVEL : float = 0.003
const KINESTHETIC_DARK_ENERGY : float = 0.2
const KINESTHETIC_LIT_ENERGY : float = 0.0
const KINESTHETIC_TWEEN_TIME : float = 1.0

@onready var _kinesthetic_sense : OmniLight3D = get_node_or_null("KinestheticSense") as OmniLight3D
var _kinesthetic_tween : Tween = null


func _process(_delta : float) -> void:
	if _kinesthetic_sense == null:
		return
	var target_energy : float = KINESTHETIC_LIT_ENERGY
	if light_level <= KINESTHETIC_DARKNESS_LEVEL:
		target_energy = KINESTHETIC_DARK_ENERGY
	if absf(_kinesthetic_sense.light_energy - target_energy) < 0.0001:
		return
	if _kinesthetic_tween != null and _kinesthetic_tween.is_valid():
		_kinesthetic_tween.kill()
	_kinesthetic_tween = create_tween()
	_kinesthetic_tween.tween_property(_kinesthetic_sense, "light_energy",
			target_energy, KINESTHETIC_TWEEN_TIME)
