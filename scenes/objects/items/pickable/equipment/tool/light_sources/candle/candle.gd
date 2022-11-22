extends ToolItem


onready var firelight=$FireOrigin/Fire/Light
onready var DurableTimer=$Durability
var has_onned=false
var is_on=true
func _ready():
	DurableTimer.start()


func _process(delta):
	if is_on==true:
		DurableTimer.pause_mode=false
	else:
		DurableTimer.pause_mode=true
	if self.mode==equipped_mode and has_onned==false:
#			DurableTimer.start()
#			has_onned=true
			is_on=true
	else:
		is_on=false
func _use_primary():
	if !DurableTimer.is_stopped():
		firelight.visible = not firelight.visible


func _on_Durability_timeout():
	firelight.visible=false
