# Test observer for generate_atmosphere_group.gd routing (GUT helper, not a test).
# Records the weather decision the group routes to it. The atmosphere group
# addresses its children through weather_scene_path / room_paths, so this
# helper declares those members itself.
extends GenerationStep

@export var accepts_fog_weather := true

var weather_scene_path := ""
var room_paths := {}

var captured_weather_scene_path := ""
var captured_room_paths := {}


func _execute_step(_data : WorldData, _gen_data : Dictionary, _generation_seed : int):
	captured_weather_scene_path = weather_scene_path
	captured_room_paths = room_paths
