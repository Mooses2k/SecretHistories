extends "res://scenes/characters/character.gd"
class_name Player

onready var cam = $Body/FPSCamera
onready var tinnitus = $Tinnitus
var enemies := [] # enemies inbound























# [ Sword positioning ]
func combat_mode_body_entered(body: Spatial):
	if is_instance_valid(body):
		if body.is_in_group("character"):
			enemies.append(body);

func combat_mode_body_exited(body):
	if is_instance_valid(body):
		if enemies.has(body):
			enemies.erase(body);

func get_nearest_enemy(x: Spatial, y: Spatial):
	return\
	cam.unproject_position(x.global_transform.origin).distance_to(OS.window_size/2) <\
	cam.unproject_position(y.global_transform.origin).distance_to(OS.window_size/2)

func get_current_enemy():
	if enemies.empty(): return null;
	enemies.sort_custom(self, "get_nearest_enemy");
	return enemies[0];

func get_blend_vector(enemy: Spatial) -> Vector2:
	return ((cam.unproject_position(enemy) / OS.window_size) * 2.0) - Vector2(1.0, 1.0);

