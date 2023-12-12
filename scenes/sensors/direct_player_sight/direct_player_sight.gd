tool class_name PlayerSensor extends Area


# Whatever you do, for the love of Cthulhu, please don't set Mask 1 for the DirectSightArea
# You will lag so hard
# Don't remove this comment :)


export var distance := 32.0 setget set_distance
export var fov := 120.0 setget set_fov
export var _character : NodePath
var character: Character


onready var raycast := RayCast.new()


#--------------------------------------------------------------------------#
#                 Programmatically sets the vision frustrum.               #
#--------------------------------------------------------------------------#
onready var _collision_shape := CollisionShape.new()
onready var _mesh_instance := MeshInstance.new()
var _mesh : CylinderMesh = CylinderMesh.new()


func add_area_nodes() -> void:
	add_child(_collision_shape)
	add_child(_mesh_instance)
	_mesh_instance.mesh = _mesh


func update_mesh_and_collision() -> void:
	if !is_inside_tree():
		return
	
	_mesh.rings = 0
	_mesh.radial_segments = 4
	_mesh.height = distance
	_mesh.top_radius = 0.0
	_mesh.bottom_radius = distance * tan(deg2rad(fov / 2)) / (sqrt(2) * 0.5)
	_mesh_instance.transform.origin.z = -distance * 0.5
	_collision_shape.shape = _mesh.create_convex_shape()
	_collision_shape.transform.origin.z = -distance * 0.5
#---------------------------------------------------------------------------#


var player_position := Vector3.ZERO
var sensor_up_to_date := false
var player_visible := false


func is_player_detected() -> bool:
	if not sensor_up_to_date:
		update_sensor()
	
	return player_visible


func get_measured_position() -> Vector3:
	if not sensor_up_to_date:
		update_sensor()
	
	return player_position


# Having tested, a sensible range seems to be from .005 to .01 (with light_energy 0.25 candles).
# Two factors I consider: 1) Would I feel lit up at that brightness?
# 2) If I'm standing next to a candle, I need to be visible.
func update_sensor() -> void:
	player_visible = false
	
	for body in get_overlapping_bodies():
		if body is Player and (body.light_level > 0.01 or (player_near and player_seen)):
			if not player_seen and player_near:
				player_seen = true
			var target = body.global_transform.origin
			target.y = raycast.global_transform.origin.y
			raycast.look_at(target, Vector3.UP)
			raycast.force_raycast_update()
			
			if (raycast.is_colliding() and raycast.get_collider().owner is Player and 
					(raycast.get_collider().owner.light_level > 0.01 or (player_near and player_seen))):
				player_visible = true
				player_position = body.global_transform.origin
				return
	
	sensor_up_to_date = true


func clear_sensor() -> void:
	sensor_up_to_date = false


func set_distance(value : float) -> void:
	distance = value
	queue_update()


func set_fov(value : float) -> void:
	fov = value
	queue_update()


func queue_update() -> void:
	if !is_inside_tree(): yield(self, "ready")
	if !get_tree().is_connected("idle_frame", self, "_update"):
		get_tree().connect("idle_frame", self, "_update", [], CONNECT_ONESHOT)


func _update() -> void:
	raycast.cast_to.z = -distance
	update_mesh_and_collision()


func _ready() -> void:
	if !Engine.editor_hint:
		character = get_node(_character)
		raycast.add_exception(character)
	queue_update()
	get_tree().connect("idle_frame", self, "clear_sensor")
