class_name SoundListener
extends Node


# Purpose of this was to detect if can see player then don't worry about hearing, I think
#export var sensor : NodePath
#onready var player_sight_sensor : PlayerSensor = get_node(sensor) as PlayerSensor   # Relevant how?

var sound_detected : bool = false
var sensor_up_to_date : bool = false
var sound_position : Vector3 = Vector3.ZERO
var player_inside_near_listener : bool = false
var player_inside_listener : bool = false
var item_inside_listener = []
var item_too_near = []
var player_body : Object
var item_heared : Object
#var sound_was_heared : bool = false   # Dupe usage of sound_detected

export var hearing_sensitivity = 4   # Lower levels for more acute hearing, with 1 able to hear player's normal breathing


func _ready():
	get_tree().connect("idle_frame", self, "clear_sensor")   # Makes sensor not up to date after each frame


func is_sound_detected() -> bool:
	if not sound_detected:
		if not sensor_up_to_date:
			update_sensor()
	
	return sound_detected


func get_measured_position() -> Vector3:
	if not sound_detected:
		if not sensor_up_to_date:
			update_sensor()
	
	return sound_position


func update_sensor():
	sound_detected = false
	check_sound_around()
	sensor_up_to_date = true


func clear_sensor():
	sensor_up_to_date = false


func check_sound_around():
	if player_inside_listener:
		if obj_sound_loud_enough(player_body, check_if_behind_wall(player_body)):
			sound_detected = true
#			sound_was_heared = true
			sound_position = player_body.global_transform.origin
	
	for item in item_inside_listener:
		if obj_sound_loud_enough(item, check_if_behind_wall(item)):
			sound_detected = true
#			sound_was_heared = true
			sound_position = item.global_transform.origin


func obj_sound_loud_enough(item, behind_wall : int):
	if behind_wall > 0:
		item.noise_level /= behind_wall
		if item.noise_level >= 4:   # If a normal-hearing-detectable amount of noise
			print(item.noise_level, " noise after passing through wall(s)")
	if item.noise_level >= hearing_sensitivity:
		if player_inside_near_listener == true or !item_too_near.empty():
			print("Player or object near and heard")
			return true
	if item.noise_level >= hearing_sensitivity * 2.5:
		if player_inside_listener == true or item_inside_listener == true:
			return true
	return false


func check_if_behind_wall(obj : Object):
	if item_too_near.has(obj):
		return false
		
	var space_state = owner.get_world().direct_space_state
	var result = (space_state.intersect_ray(owner.global_transform.origin + Vector3.UP * 1.5, 
			obj.global_transform.origin, [owner]))
	var passes : int = 0
	if result:
		# TODO make this more general by group maybe?
		for each in result:
			if (result["collider"].name == "wall_xp" or result["collider"].name == "wall_zp" or
			 result["collider"].name == "wall_xn" or result["collider"].name == "wall_zn" or
			 result["collider"].name == "ceiling" or result["collider"].name == "ground"):
				passes += 1
		return passes
	return false


func _on_NearSoundDetector_body_entered(body):
	if body is Player:
		player_body = body
		player_inside_listener = true
		player_inside_near_listener = true
		print("Player entered near sound alert range!")
	
	if body is ToolItem or body is GunItem or body is MeleeItem or body is EquipmentItem or body is BombItem:
		if not item_too_near.has(body):
			item_too_near.append(body)


func _on_NearSoundDetector_body_exited(body):
	if body is Player:
		player_inside_listener = false
		player_inside_near_listener = false
	
	if body is ToolItem or body is GunItem or body is MeleeItem or body is EquipmentItem or body is BombItem:
		if item_too_near.has(body):
			item_too_near.remove(item_too_near.find(body))


func _on_FarSoundDetector_body_entered(body):
	if body is Player:
		player_body = body
		player_inside_listener = true
	
	if body is ToolItem or body is GunItem or body is MeleeItem or body is EquipmentItem or body is BombItem:
		if not item_inside_listener.has(body):
			item_inside_listener.append(body)


func _on_FarSoundDetector_body_exited(body):
	if body is Player:
		player_inside_listener = false
	
	if body is ToolItem or body is GunItem or body is MeleeItem or body is EquipmentItem or body is BombItem:
		if item_inside_listener.has(body):
			item_inside_listener.remove(item_inside_listener.find(body))
