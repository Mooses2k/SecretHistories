extends Node


@export var threshold : float = -10.0


func _physics_process(delta: float) -> void:
	if owner.global_position.z < threshold:
		owner.queue_free()
