extends ToolItem


onready var firelight = $Light
onready var DurableTimer = $Durability

var has_onned = false # onned?
var is_lit = false


func _ready():
	pass


func _process(delta):
	if is_lit == true:
		DurableTimer.pause_mode = false
	else:
		DurableTimer.pause_mode = true
	if self.mode == equipped_mode and has_onned == false:
			DurableTimer.start()
			has_onned = true
			firelight.visible = true
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !DurableTimer.is_stopped():
		firelight.visible = not firelight.visible


func _on_Durability_timeout():
	firelight.visible = false
