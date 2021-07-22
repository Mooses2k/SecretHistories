extends Spatial

export var light_duration = 0.2

onready var sound_effect = $AudioStreamPlayer3D
onready var particle_smoke = $Smoke
onready var light = $OmniLight


func handle_sound():
	sound_effect.play(0.0)
	yield(get_tree().create_timer(sound_effect.stream.get_length()), "timeout")
	sound_effect.stop()

func handle_light():
	light.visible = true
	yield(get_tree().create_timer(light_duration), "timeout")
	light.visible = false

func handle_particles():
	particle_smoke.emitting = true


func _on_Shotgun_gun_shot():
	handle_sound()
	handle_particles()
	handle_light()
	pass # Replace with function body.
