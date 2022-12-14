extends ToolItem


var has_ever_been_on = false 
var is_lit = false

onready var firelight = $FireOrigin/Fire/Light
onready var durable_timer = $Durability


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
			$AnimationPlayer.play("flicker")
			$FireOrigin/Fire.emitting = true
			$FireOrigin/EmberDrip.emitting = true
			$FireOrigin/Smoke.emitting = true
			firelight.visible = not firelight.visible
			$MeshInstance.cast_shadow = false
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !durable_timer.is_stopped():
		$AnimationPlayer.play("flicker")
		$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
		$FireOrigin/EmberDrip.emitting = not $FireOrigin/EmberDrip.emitting
		$FireOrigin/Smoke.emitting = not $FireOrigin/Smoke
		firelight.visible = not firelight.visible
		$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
	else:
		$AnimationPlayer.stop()
		$FireOrigin/Fire.emitting = false
		$FireOrigin/EmberDrip.emitting = false
		$FireOrigin/Smoke.emitting = false
		firelight.visible = false
		$MeshInstance.cast_shadow = true


func _on_Durability_timeout():
	$AnimationPlayer.stop()
	$FireOrigin/Fire.emitting = false
	$FireOrigin/EmberDrip.emitting = false
	$FireOrigin/Smoke.emitting = false
	firelight.visible = false
	$MeshInstance.cast_shadow = true
