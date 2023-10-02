tool
extends PlayerSensor


export var character : NodePath

onready var area = $SensorArea
var _character

var player_touching : bool = false
var player_position : Vector3 = Vector3.ZERO


func is_player_detected() -> bool:
	return player_touching


func get_measured_position() -> Vector3:
	return player_position


func _ready():
	if not Engine.editor_hint:
		_character = get_node(character)


func _on_SensorArea_body_entered(body):
	player_touching = false
	for body in area.get_overlapping_bodies():
		if body is Player:
			player_position = body.global_transform.origin
			player_touching = true
			print("Character collided with Player")


func _on_SensorArea_body_exited(body):
	player_touching = false
	for body in area.get_overlapping_bodies():
		if body is Player:
			player_touching = true
