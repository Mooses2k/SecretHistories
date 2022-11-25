extends Particles


onready var bombcasts = $"%bombcasts"
func _ready():
	pass




func _process(delta):
	pass


func _on_Bomb_explosion():
	after_effects()



func after_effects():
	for b in bombcasts.get_children():
		if b.is_colliding():
			print(b.get_collider())
