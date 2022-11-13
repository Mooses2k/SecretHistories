extends ConsumableItem
class_name Dynamite


onready var countdown_timer = $Countdown
var countdown_started = false


func _ready():
	print($Explosion.lifetime)


func _process(delta):
	if countdown_started == true:
		$Explosion.lifetime -= delta
	if $Explosion.lifetime < 1.2:
		queue_free()
func _use_primary():


	if countdown_timer.is_stopped():
		countdown_timer.start()
	else:
		get_parent().get_parent().get_parent().drop_consumable(self)
#		get_parent().get_parent().get_parent().delete_bomb()
		pass


func _on_Countdown_timeout():
	$Explosion.emitting = true
	countdown_started = true
