extends Spatial

export var light_duration = 0.2

onready var sound_effect = $AudioStreamPlayer3D
onready var particle_smoke = $Smoke
onready var light = $OmniLight


func handle_sound():
	var sound_instance = sound_effect.duplicate()
	call_deferred("add_child", sound_instance)
	yield(sound_instance, "ready")
	sound_instance.play(0.0)
	yield(get_tree().create_timer(sound_effect.stream.get_length()), "timeout")
	sound_instance.stop()
	sound_instance.queue_free()

func handle_light():
	light.visible = true
	yield(get_tree().create_timer(light_duration), "timeout")
	light.visible = false

func handle_particles():
	var smoke_instance = particle_smoke.duplicate()
	call_deferred("add_child", smoke_instance)
	yield(smoke_instance, "ready")
	smoke_instance.emitting = true
	yield(get_tree().create_timer(smoke_instance.lifetime), "timeout")
	smoke_instance.queue_free()


func _on_Shotgun_gun_shot():
	handle_sound()
	handle_particles()
	handle_light()
	pass # Replace with function body.
