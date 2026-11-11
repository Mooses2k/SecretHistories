class_name ShardOfTheComet
extends StrangeDevice

### Hurts player 3HP per 5 seconds when within 1m


var player_in_killzone = false

@onready var player_hitbox = null
@onready var dangerous_radiance = $DangerousRadiance


func _ready():
	$AnimationPlayer.play("flicker")


func _physics_process(delta):
	if player_in_killzone:
		if $OmniLight3D.light_energy >= 14:
			player_hitbox.damage(1, GlobalConsts.AttackTypes.SPECIAL)
	_pitch_alter_chant_based_on_distance()


# Alters pitch_scale of $AudioStreamPlayer based on distance from the player:
# the chant deepens toward its slowest as the player closes in and relaxes
# back toward natural pitch as they move away (3.x behavior).
func _pitch_alter_chant_based_on_distance():
	if is_instance_valid(GameManager.game):
		$AudioStreamPlayer.pitch_scale = _pitch_for_distance(
			self.global_position.distance_to(GameManager.game.player.global_position))


# 1 - 1/distance goes negative inside 1 m (the killzone range), so clamp to
# the deepest valid pitch instead of feeding Godot an invalid pitch_scale.
func _pitch_for_distance(distance: float) -> float:
	return clampf(1.0 - (1.0 / distance), 0.01, 1.0)


func _on_DangerousRadiance_body_entered(body):
	if body.is_in_group("PLAYER"):
		player_in_killzone = true
		player_hitbox = body


func _on_DangerousRadiance_body_exited(body):
	if body.is_in_group("PLAYER"):
		player_in_killzone = false
#		player_hitbox = null
