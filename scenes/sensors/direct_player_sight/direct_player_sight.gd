tool
extends PlayerSensor


const DetectionArea = preload("res://scenes/sensors/direct_player_sight/direct_sight_area.gd")

export var character : NodePath
export var FOV : float = 70 setget set_fov
export var distance : float = 16 setget set_distance

onready var area : DetectionArea = $DirectSightArea
onready var raycast : RayCast = $RayCast
var _character

var sensor_up_to_date : bool = false
var player_visible : bool = false
var player_position : Vector3 = Vector3.ZERO
var player_near : bool = false
var player_seen : bool = false
var player_far : bool = true
var player_close : bool = false
var item_inside_listener = []


func is_player_detected() -> bool:
	if not sensor_up_to_date:
		update_sensor()
	return player_visible


func get_measured_position() -> Vector3:
	if not sensor_up_to_date:
		update_sensor()
	
	return player_position


func update_sensor():
	player_visible = false
	for body in area.get_overlapping_bodies():
		if body is Door and (body.light_level > 0.04 or (player_near and player_seen)):
			if not player_seen and player_near:
				player_seen = true
			var target = body.global_transform.origin
			target.y = raycast.global_transform.origin.y
			raycast.look_at(target, Vector3.UP)
			raycast.force_raycast_update()
			
			if (raycast.is_colliding() and raycast.get_collider().owner is Player and 
					(raycast.get_collider().owner.light_level > 0.04 or (player_near and player_seen))):
				player_visible = true
				player_position = body.global_transform.origin
				return
		
	if not player_visible:
		if check_sound_around():
			player_visible = true
			player_position = check_sound_around()
			print(check_sound_around())
			return
	
	sensor_up_to_date = true


func clear_sensor():
	sensor_up_to_date = false


func set_distance(value : float):
	distance = value
	queue_update()


func set_fov(value : float):
	FOV = value
	queue_update()


func queue_update():
	if not is_inside_tree():
		yield(self, "ready")
	if not get_tree().is_connected("idle_frame", self, "_update"):
		get_tree().connect("idle_frame", self, "_update", [], CONNECT_ONESHOT)


func _update():
	area.update_mesh(FOV, distance)
	raycast.cast_to.z = -distance
	pass


func _ready():
	if not Engine.editor_hint:
		_character = get_node(character)
		raycast.add_exception(_character)
	queue_update()
	get_tree().connect("idle_frame", self, "clear_sensor")


func check_sound_around():
	for item in item_inside_listener:
		if obj_sound_loud_enough(item):
			return item.global_transform.origin
	
	return null


func obj_sound_loud_enough(item):
	if item.noise_level > 0:
		return true 
	return false


func _on_PlayerDetector_body_entered(body):
	if body is Player:
		player_close = true
		player_far = false
		player_near = true
		if body.light_level > 0.04:
			player_seen = true


func _on_PlayerDetector_body_exited(body):
	if body is Player:
		player_close = false
		player_far = true
		player_near = false
		player_seen = false


func _on_FarSoundDetector_body_entered(body):
	if body is Player:
		player_far = true
		
	if body is ToolItem or body is GunItem or body is MeleeItem or body is EquipmentItem or body is BombItem:
		if !item_inside_listener.has(body):
			item_inside_listener.append(body)


func _on_FarSoundDetector_body_exited(body):
	if body is Player:
		player_far = false
	
	if body is ToolItem or body is GunItem or body is MeleeItem or body is EquipmentItem or body is BombItem:
		if item_inside_listener.has(body):
			item_inside_listener.remove(item_inside_listener.find(body))
