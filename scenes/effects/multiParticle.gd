@tool
extends GPUParticles3D
class_name MultiParticles3D


@export var others : Array[GPUParticles3D]
@export var test : bool:
	set(value):
		if !value: return
		fire()


func fire():
	emitting = true
	for other in others:
		other.emitting = true
