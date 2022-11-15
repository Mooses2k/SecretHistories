extends ToolItem
class_name LanternItem


var has_ever_been_on = false 
var is_lit = true # true for testing to provide some light

onready var firelight = $Light
onready var DurableTimer = $Durability


func _ready():
	pass


func _process(delta):
	if is_lit == true:
		DurableTimer.pause_mode = false
	else:
		DurableTimer.pause_mode = true
	if self.mode == equipped_mode and has_ever_been_on == false:
			DurableTimer.start()
			has_ever_been_on = true
			firelight.visible = true
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !DurableTimer.is_stopped():
		firelight.visible = not firelight.visible


func _on_Durability_timeout():
	firelight.visible = false
