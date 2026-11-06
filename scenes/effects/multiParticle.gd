@tool
extends GPUParticles3D
class_name MultiParticles3D


@export var others : Array[GPUParticles3D]
@export var test : bool:
	set(value):
		if !value: return
		fire()


func _ready():
	# Editor hint: do not auto-fire in the scene view; the "test" bool is the editor fire button.
	if Engine.is_editor_hint():
		return
	# Runtime fire (A1): mirrors the old smoke.gd contract of emitting in _ready().
	fire()
	# Cleanup (A2): the root is one_shot, so it emits finished when the plume ends.
	# Freeing the root frees the whole triggered chain with it (no node leak per shot).
	finished.connect(queue_free)


func fire():
	emitting = true
	for other in others:
		other.emitting = true
