extends LargeObject

## Floor candelabra: a burning large-object light with takeable candles
## (#359, #193). Interacting with the stand hands one whole candle to the
## character through the normal pickup path (hand > hotbar), lit when the
## stand's fire is burning and unlit otherwise. Floor stands deliver the
## TALL candle item (the candle_scene default); the votive stand's scene
## overrides it to the small candle (owner mapping: votive = small only).
## Owner-approved simple model:
## each stand yields exactly ONE candle (owner ruling: allow only one
## candle from each), taken candles carry a full 1.0 fill, the stand keeps
## burning after the take (the baked wax stays: per-candle visual removal
## waits for the mesh-externalization objective), and a spent stand plays
## the diegetic reject cue. Taking is one-way: the stand is not a refill
## target.

const TALL_CANDLE_SCENE_PATH := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle_tall.tscn"

## The candle item this stand hands out. Tall candle by default because
## every spawning variant is a floor stand; the votive stand's scene
## overrides it to the small candle.
@export var candle_scene : PackedScene = preload(TALL_CANDLE_SCENE_PATH)

## Whole candles left to take from this stand. One per stand (owner ruling).
@export var takes_remaining : int = 1

# The lit variant burns permanently (the unlit look is a separate scene with
# hidden flames). MeshInstanceLayered on the flame quads reads this and keeps
# them from shadowing their own light.
var is_lit : bool = true

var _reject_sound : AudioStreamPlayer3D
var _reject_tween : Tween
var _mesh_to_shake : MeshInstance3D = null
var _mesh_rest_position := Vector3.ZERO

@onready var floor_candelabra_drop_sound : AudioStream = load("res://resources/sounds/impacts/metal_and_gun/414848__link-boy__metal-bang.wav")

@onready var animation_player = $AnimationPlayer
@onready var firelight = $FireOrigin/Fire/Light3D


func _ready():
	self.item_max_noise_level = 5
	self.item_drop_sound = floor_candelabra_drop_sound
	super._ready()  # Call parent's _ready() to configure audio manager

	var ignite : Interactable = get_node_or_null("Ignite") as Interactable
	if ignite != null:
		ignite.character_interacted.connect(_on_ignite_character_interacted)
	_reject_sound = AudioStreamPlayer3D.new()
	_reject_sound.name = "TakeRejectSound"
	_reject_sound.stream = floor_candelabra_drop_sound
	add_child(_reject_sound)
	# The shake target is the stand's baked candle mesh (one MeshInstance3D per
	# stand, candelabra-take-and-refill.md section 1).
	for node in find_children("*", "MeshInstance3D", true, false):
		_mesh_to_shake = node as MeshInstance3D
		_mesh_rest_position = _mesh_to_shake.position
		break


func _process(delta):
	if firelight.visible and !animation_player.is_playing():
		animation_player.play("flicker")


## The stand's fire state is the visible flame light: the lit variants author
## it visible, the unlit variant hides it in its scene, and fire_origin.gd
## hides it when the stand topples.
func _stand_is_burning() -> bool:
	return is_instance_valid(firelight) and firelight.visible


func _on_ignite_character_interacted(character) -> void:
	_take_candle(character)


## Take flow: one candle per interaction, delivered through the normal
## pickup path (add_item: hand > hotbar). The fresh candle is lit at the
## stand so the ignite sound plays in the world before the hand attach.
## If the character cannot receive it, the fresh node is freed and the count
## is untouched: nothing is lost (no-destroy guarantee).
func _take_candle(character) -> void:
	var inventory : Inventory = null
	if character is Node:
		inventory = character.get("inventory")
	if inventory == null:
		return
	if takes_remaining <= 0:
		_play_take_rejected_cue()
		return

	var candle : CandleItem = candle_scene.instantiate()
	add_child(candle)
	candle.fuel.fill = 1.0
	if _stand_is_burning():
		candle.light()
	if not inventory.add_item(candle):
		candle.get_parent().remove_child(candle)
		candle.free()
		_play_take_rejected_cue()
		return

	takes_remaining -= 1


## The unmissable reject cue (owner playtest): the diegetic metal bang plus a
## brief shake of the stand's baked mesh, so a spent stand is felt and seen,
## not only heard faintly. The rigid body itself is never moved: only the
## mesh child wobbles and always returns to its authored rest position.
func _play_take_rejected_cue() -> void:
	if _reject_sound != null and not _reject_sound.playing:
		_reject_sound.play()
	_shake_stand_mesh()


func _shake_stand_mesh() -> void:
	if _mesh_to_shake == null:
		return
	if _reject_tween != null and _reject_tween.is_valid():
		_reject_tween.kill()
		_mesh_to_shake.position = _mesh_rest_position
	_reject_tween = create_tween()
	var step_time : float = 0.05
	for i in 3:
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.02
		_reject_tween.tween_property(_mesh_to_shake, "position", _mesh_rest_position + offset, step_time)
	_reject_tween.tween_property(_mesh_to_shake, "position", _mesh_rest_position, step_time)
