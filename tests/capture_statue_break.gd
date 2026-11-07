extends Node3D

## Windowed capture: spawns statue_gargoyle_2 in front of a camera, captures
## a before screenshot, drives the kick damage entry (accumulate_break_damage
## with the authored kick_damage of 15) until the break threshold crosses,
## then captures an after screenshot and quits.

const KICK_DAMAGE := 15.0
const OUT_DIR := "res://docs/captures"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)
	add_child(_make_ground())
	var statue : Node3D = load("res://scenes/objects/large_objects/statuary/statue_gargoyle_2.tscn").instantiate()
	add_child(statue)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(3.0, 2.2, 4.5)
	cam.look_at_from_position(cam.position, statue.global_position + Vector3(0, 1.5, 0))
	cam.current = true
	for i in 12:
		await get_tree().process_frame
	_capture("statue_break_before.png")
	print("CAPTURE: before saved, statue=", statue.name, " type=", statue.get_class(), " breakable=", statue.is_breakable())
	# Hit it with kicks until it breaks.
	var kicks := 0
	while is_instance_valid(statue) and not statue.is_queued_for_deletion():
		statue.accumulate_break_damage(KICK_DAMAGE)
		kicks += 1
		if kicks > 20:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var broken : Node3D = null
	for child in get_children():
		if child is Node3D and child.name.contains("Broken"):
			broken = child
	print("CAPTURE: kicks=", kicks, " broken_present=", broken != null)
	if broken:
		print("CAPTURE: broken transform origin=", broken.global_position, " intact was=", statue.global_position if is_instance_valid(statue) else Vector3.INF)
	_capture("statue_break_after.png")
	print("CAPTURE: after saved")
	get_tree().quit(0 if broken else 1)


func _capture(file_name : String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUT_DIR + "/" + file_name)


func _make_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.5, 30)
	shape.shape = box
	shape.position = Vector3(0, -0.25, 0)
	ground.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	mesh_instance.mesh = plane
	ground.add_child(mesh_instance)
	return ground
