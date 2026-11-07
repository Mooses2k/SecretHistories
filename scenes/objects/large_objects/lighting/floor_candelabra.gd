extends LargeObject

## Floor candelabra: a burning large-object light with takeable candles
## (#359, #193). Interacting with the stand hands one whole candle to the
## character through the normal pickup path (hand > hotbar), lit when the
## stand's fire is burning and unlit otherwise. Owner-approved simple model:
## the stand does not model per-candle burn, so every taken candle carries a
## full 1.0 fill. The candle visuals are baked into the stand mesh (no
## per-candle mesh child exists to hide), so a take decrements the count and
## the last take extinguishes the fire; per-candle visual removal waits for
## the mesh-externalization objective. Taking is one-way: the stand is not a
## refill target.

const CandleScene : PackedScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")

## Whole candles left on the stand. -1 derives the authored count from the
## FireOrigin markers at ready; the votive stand (one consolidated fire,
## four baked candles) overrides it in its scene.
@export var candle_count : int = -1

# The lit variant burns permanently (the unlit look is a separate scene with
# hidden flames). MeshInstanceLayered on the flame quads reads this and keeps
# them from shadowing their own light.
var is_lit : bool = true

var _reject_sound : AudioStreamPlayer3D

@onready var floor_candelabra_drop_sound : AudioStream = load("res://resources/sounds/impacts/metal_and_gun/414848__link-boy__metal-bang.wav")

@onready var animation_player = $AnimationPlayer
@onready var firelight = $FireOrigin/Fire/Light3D


func _ready():
	self.item_max_noise_level = 5
	self.item_drop_sound = floor_candelabra_drop_sound
	super._ready()  # Call parent's _ready() to configure audio manager

	if candle_count < 0:
		candle_count = _count_candle_fires()
	var ignite : Interactable = get_node_or_null("Ignite") as Interactable
	if ignite != null:
		ignite.character_interacted.connect(_on_ignite_character_interacted)
	_reject_sound = AudioStreamPlayer3D.new()
	_reject_sound.name = "TakeRejectSound"
	_reject_sound.stream = floor_candelabra_drop_sound
	add_child(_reject_sound)


func _process(delta):
	if firelight.visible and !animation_player.is_playing():
		animation_player.play("flicker")


## The stand's fire state is the visible flame light: the lit variants author
## it visible, the unlit variant hides it in its scene, and fire_origin.gd
## hides it when the stand topples.
func _stand_is_burning() -> bool:
	return is_instance_valid(firelight) and firelight.visible


func _count_candle_fires() -> int:
	var count := 0
	for child in get_children():
		if child is Marker3D and child.has_node("Fire"):
			count += 1
	return count


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
	if candle_count <= 0:
		_play_take_rejected_cue()
		return

	var candle : CandleItem = CandleScene.instantiate()
	add_child(candle)
	candle.fuel.fill = 1.0
	if _stand_is_burning():
		candle.light()
	if not inventory.add_item(candle):
		candle.get_parent().remove_child(candle)
		candle.free()
		_play_take_rejected_cue()
		return

	candle_count -= 1
	if candle_count <= 0:
		_extinguish_stand()


## The existing interaction-fail cue pattern (a diegetic sound, like the
## locked-door rattle): the stand's own metal bang, played as a jiggle.
func _play_take_rejected_cue() -> void:
	if _reject_sound != null and not _reject_sound.playing:
		_reject_sound.play()


func _extinguish_stand() -> void:
	for child in get_children():
		if child is Marker3D and child.has_node("Fire"):
			var fire : Node3D = child.get_node("Fire")
			fire.visible = false
			var light_node : Node = fire.get_node_or_null("Light3D")
			if light_node is Light3D:
				light_node.visible = false
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()


#onready var burn_time = $Durability
#
#var has_ever_been_on = false
#var is_lit = false
#
#
#func _process(delta):
#	if is_lit == true:
#		burn_time.pause_mode = false
#	else:
#		burn_time.pause_mode = true
#	if has_ever_been_on == false:
#			burn_time.start()
#			has_ever_been_on = true
#			firelight.visible = not firelight.visible
#			$AnimationPlayer.play("flicker")
#			$FireOrigin/Fire.emitting = true
#			$FireOrigin/EmberDrip.emitting = true
#			$FireOrigin/Smoke.emitting = true
#			is_lit = true
#	else:
#		is_lit = false
#
#
#func _use_primary():
#	if !burn_time.is_stopped():
#		firelight.visible = not firelight.visible
#		$AnimationPlayer.play("flicker")
#		$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
#		$FireOrigin/EmberDrip.emitting = not $FireOrigin/EmberDrip.emitting
#		$FireOrigin/Smoke.emitting = not $FireOrigin/Smoke
#	else:
#		firelight.visible = false
#		$AnimationPlayer.stop()
#		$FireOrigin/Fire.emitting = false
#		$FireOrigin/EmberDrip.emitting = false
#		$FireOrigin/Smoke.emitting = false
#
#
#func _on_Durability_timeout():
#	firelight.visible = false
#	$AnimationPlayer.stop()
#	$FireOrigin/Fire.emitting = false
#	$FireOrigin/EmberDrip.emitting = false
#	$FireOrigin/Smoke.emitting = false
