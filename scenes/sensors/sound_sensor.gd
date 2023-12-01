class_name SoundSensor extends Area


signal sensory_input(position, id, interest)
signal sound_detected(source, interest)


const WALL_NAMES := ["wall_xp", "wall_zp", "wall_xn", "wall_zn", "ceiling", "ground"]


export var check_frame_interval := 10
export var hearing_sensitivity := 5.0


var sound_sources := []


func _ready() -> void:
	connect("body_entered", self, "on_body_entered")
	connect("body_exited", self, "on_body_exited")


func on_body_entered(body: Spatial) -> void:
	if !(body is Character or body is PickableItem or body is LargeObjectDropSound): return
	if !sound_sources.has(body): sound_sources.append(body)


func on_body_exited(body: Spatial) -> void:
	if sound_sources.has(body):
		sound_sources.erase(body)


func _process(_delta: float) -> void:
	if Engine.get_idle_frames() % check_frame_interval == 0:
		check_for_sounds()


func check_for_sounds() -> void:
	for object in sound_sources:
		var interest_level := get_interest_level(object) 
		if !interest_level: continue
		emit_signal("sound_detected", object, interest_level)
		emit_signal("sensory_input", object.global_transform.origin, object, interest_level)


func get_interest_level(source: Spatial) -> int:
	if !(source is Character or source is PickableItem or source is LargeObjectDropSound): return 0
	if !source.noise_level: return 0

	var interest := source.noise_level as int
	var walls_in_between := get_walls_in_between(source.global_transform.origin)
	if walls_in_between: interest /= walls_in_between
	
	var distance := global_transform.origin.distance_to(source.global_transform.origin)
	if source is BombItem and interest >= 80: interest += 100
	if distance < 1.0: interest += 100 

	return interest if interest >= hearing_sensitivity else 0


func get_walls_in_between(target_position : Vector3) -> int:
	var passes := 0
	
	var result: Dictionary = owner.get_world().direct_space_state.intersect_ray(global_transform.origin, target_position, [self, owner], 1 << 0)
	for each in result: if each.collider.name in WALL_NAMES:
		passes += 1
	return passes
