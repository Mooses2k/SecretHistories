class_name Effect
extends Node3D


@export var light_duration = 0.05

@export var smoke_particles : PackedScene
@export var sound_effect : PackedScene
@export var hit_effect : PackedScene

# Tolerant fetches: some Effect scenes (dynamite) only use one of the
# optional origins, and missing nodes error on every spawn otherwise.
@onready var sound_origin : Node3D = get_node_or_null("SoundOrigin")
@onready var smoke_origin : Node3D = get_node_or_null("SmokeOrigin")
@onready var flash : Node3D = get_node_or_null("Flash")
@onready var flash_timer : Timer = get_node_or_null("Flash/FlashTimer")


func handle_sound():
	var sound_instance = sound_effect.instantiate()
	sound_instance.set_as_top_level(true)
	# Fall back to the Effect node itself when a scene has no SoundOrigin.
	var origin_node : Node3D = sound_origin if sound_origin != null else self
	sound_instance.transform.origin = origin_node.global_transform.origin
	var world_scene
	if is_instance_valid(GameManager.game):
		world_scene = GameManager.game.level
	else:
		world_scene = owner.owner_character.owner as Node3D

	world_scene.call_deferred("add_child", sound_instance)


func handle_flash():
	if flash == null or flash_timer == null:
		return
	flash.visible = true
	flash_timer.start(light_duration)


func _on_FlashTimer_timeout():
	flash.visible = false


func handle_particles():
	if smoke_origin == null:
		return
	var smoke_instance = smoke_particles.instantiate()
	smoke_origin.call_deferred("add_child", smoke_instance)
