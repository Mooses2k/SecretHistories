extends ToolItem


onready var firelight = $FireOrigin/Fire/Light
onready var durable_timer = $Durability

var has_ever_been_on = false 
var is_lit = true


func _ready():
	durable_timer.start()


func _process(delta):
	if is_lit == true:
		durable_timer.pause_mode = false
	else:
		durable_timer.pause_mode = true
	if self.mode == equipped_mode and has_ever_been_on == false:
			durable_timer.start()
			has_ever_been_on = true
			firelight.visible = not firelight.visible
			$AnimationPlayer.play("flicker")
			$FireOrigin/Fire.visible = not $FireOrigin/Fire.visible
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !durable_timer.is_stopped():
		$FireOrigin/Fire.visible = not $FireOrigin/Fire.visible
		firelight.visible = not firelight.visible
	else:
		$AnimationPlayer.stop()
		$FireOrigin/Fire.visible = false
		firelight.visible = false


func _on_Durability_timeout():
	$FireOrigin/Fire.visible = false
	firelight.visible = false
	$AnimationPlayer.stop()
