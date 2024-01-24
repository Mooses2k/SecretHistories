@tool
class_name TouchSensor extends CharacterSense

# Kinesthetic sense. Bumping up against something.


@export var touch_interest := 300

var player_touching = false


#
#func _ready() -> void:
#	connect("area_entered", self, "on_body_entered")
#	connect("area_exited", self, "on_body_exited")


func on_body_entered(body: Node3D) -> void:
	if body is Player:
		emit_signal\
		(
			"event",
			touch_interest,
			body.global_transform.origin,
			body,
			self
		)
		player_touching = true
		print("Touch detected by Player")


func on_body_exited(_body: Node3D) -> void:
	if _body is Player:
		player_touching = false
