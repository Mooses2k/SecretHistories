extends ToolItem
class_name CandelabraItem


# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that

# this candelabra has NOT BEEN TESTED AT ALL

onready var firelight = $Candle1/FireOrigin/Fire/Light
onready var DurableTimer = $Durability

var has_ever_been_on = false 
var is_lit = false


#func _ready():
#	pass


func _process(delta):
	if is_lit == true:
		DurableTimer.pause_mode = false
	else:
		DurableTimer.pause_mode = true
	if has_ever_been_on == false:
			DurableTimer.start()
			has_ever_been_on = true
			firelight.visible = not firelight.visible
			$AnimationPlayer.play("flicker")
			$Candle1/FireOrigin/Fire.emitting = true
			$Candle2/FireOrigin/Fire.emitting = true
			$Candle3/FireOrigin/Fire.emitting = true
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !DurableTimer.is_stopped():
		firelight.visible = not firelight.visible
		$AnimationPlayer.play("flicker")
		$Candle1/FireOrigin/Fire.emitting = not $Candle1/FireOrigin/Fire.emitting
		$Candle2/FireOrigin/Fire.emitting = not $Candle2/FireOrigin/Fire.emitting
		$Candle3/FireOrigin/Fire.emitting = not $Candle3/FireOrigin/Fire.emitting
	else:
		firelight.visible = false
		$AnimationPlayer.stop()
		$Candle1/FireOrigin/Fire.emitting = false
		$Candle2/FireOrigin/Fire.emitting = false
		$Candle3/FireOrigin/Fire.emitting = false


func _on_Durability_timeout():
	firelight.visible = false
	$AnimationPlayer.stop()
	$Candle1/FireOrigin/Fire.emitting = false
	$Candle2/FireOrigin/Fire.emitting = false
	$Candle3/FireOrigin/Fire.emitting = false
