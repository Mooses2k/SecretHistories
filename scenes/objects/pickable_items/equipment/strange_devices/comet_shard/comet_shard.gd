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
			player_hitbox.damage(1, AttackTypes.Types.SPECIAL, player_hitbox)
	_pitch_alter_chant_based_on_distance()


# func which alters pitch_scale of $AudioStreamPlayer3D based on distance from player with 1 being when close
func _pitch_alter_chant_based_on_distance():
	if is_instance_valid(GameManager.game):
		$AudioStreamPlayer.pitch_scale = 1 - (1 / self.global_position.distance_to(GameManager.game.player.global_position))


func _on_DangerousRadiance_body_entered(body):
	if body.is_in_group("PLAYER"):
		player_in_killzone = true
		player_hitbox = body


func _on_DangerousRadiance_body_exited(body):
	if body.is_in_group("PLAYER"):
		player_in_killzone = false
#		player_hitbox = null
