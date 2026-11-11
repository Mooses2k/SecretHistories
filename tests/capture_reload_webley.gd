extends Node3D

## Windowed capture for the Phase 1 weapon-side reload animations (owner
## playtest aid; headless runs cannot render, so this must be started
## windowed, for example:
##   Godot_v4.7-stable_win64_console.exe --path . res://tests/capture_reload_webley.tscn
## The webley press starts the 8.067 s composite (break open, six insertion
## beats, cylinder close); frames land in docs/captures/. Printed values are
## the text truth (state, ammo, animation name and time) for every frame.

const OUT_DIR := "res://docs/captures"
const WBLEY_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn"
const AMMO := "res://resources/tiny_items/ammunition/455_webley.tres"

var webley : Node = null
var state = null
var inventory = null


class CaptureOwnerStub extends Node:
	var state = null
	var inventory = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)
	add_child(_make_ground())
	var owner_stub := CaptureOwnerStub.new()
	owner_stub.name = "CaptureOwner"
	add_child(owner_stub)
	state = load("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd").new()
	state.name = "State"
	owner_stub.add_child(state)
	state.owner = owner_stub
	owner_stub.state = state
	inventory = load("res://scenes/characters/inventory.gd").new()
	inventory.name = "Inventory"
	add_child(inventory)
	owner_stub.inventory = inventory
	webley = (load(WBLEY_SCENE) as PackedScene).instantiate()
	add_child(webley)
	webley.position = Vector3(0, 0.6, 0)
	webley.freeze = true
	webley.owner_character = owner_stub
	webley.current_ammo_type = load(AMMO)
	webley.current_ammo = 0
	inventory.tiny_items[webley.current_ammo_type] = 12
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.9, 0.9, 1.2)
	cam.look_at_from_position(cam.position, webley.global_position)
	cam.current = true
	for i in 8:
		await get_tree().process_frame
	print("CAPTURE text-truth: press starts the composite")
	webley.reload()
	await _capture_at(0.7, "webley_reload_open.png")
	await _capture_at(1.5, "webley_reload_insert_1.png")
	await _capture_at(2.0, "webley_reload_insert_mid.png")
	await _capture_at(3.3, "webley_reload_close_start.png")
	await _capture_at(0.8, "webley_reload_closed.png")
	print("CAPTURE text-truth: second press interrupted at 0.5 s; the abort plays the close beat before the state clears")
	webley.current_ammo = 2
	webley.reload()
	await get_tree().create_timer(0.5).timeout
	webley.request_reload_abort()
	await get_tree().create_timer(0.5).timeout
	await _capture_at(0.0, "webley_abort_close_beat.png")
	await get_tree().create_timer(0.7).timeout
	print("CAPTURE text-truth: after the close beat is_reloading=", state.is_reloading)
	get_tree().quit(0)


func _capture_at(wait : float, file_name : String) -> void:
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	var player : AnimationPlayer = webley.animation_player
	print("CAPTURE %s: is_reloading=%s ammo=%d anim=%s pos=%.2f" % [
		file_name, str(state.is_reloading), webley.current_ammo,
		player.current_animation, player.current_animation_position])
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
