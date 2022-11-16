extends Spatial
class_name Effect


export var light_duration = 0.05

export var smoke_particles : PackedScene
export var sound_effect : PackedScene
export var hit_effect : PackedScene

onready var sound_origin = $SoundOrigin
onready var smoke_origin = $SmokeOrigin
onready var flash = $Flash
onready var flash_timer = $Flash/FlashTimer


func handle_sound():
	var sound_instance = sound_effect.instance()
	sound_instance.set_as_toplevel(true)
	sound_instance.transform.origin = sound_origin.global_transform.origin
	GameManager.game.level.call_deferred("add_child", sound_instance)


func handle_flash():
	flash.visible = true
	flash_timer.start(light_duration)


func _on_FlashTimer_timeout():
	flash.visible = false


func handle_particles():
	var smoke_instance = smoke_particles.instance()
	smoke_origin.call_deferred("add_child", smoke_instance)
