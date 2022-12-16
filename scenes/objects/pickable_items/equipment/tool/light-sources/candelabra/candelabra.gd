extends ToolItem
class_name CandelabraItem


# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that

# function this out better, lots of duplicated lines

# emission turn off doesn't work

onready var firelight = $Candle1/FireOrigin/Fire/Light
onready var durable_timer = $Durability

var has_ever_been_on = false 
var is_lit = false


func _ready():
	durable_timer.start()


func _process(delta):
	if is_lit == true:
		durable_timer.pause_mode = false
	else:
		durable_timer.pause_mode = true
	if has_ever_been_on == false:
			durable_timer.start()
			has_ever_been_on = true
			$AnimationPlayer.play("flicker")
			$Candle1/FireOrigin/Fire.visible = true
#			$Candle1/MeshInstance.emission_enabled = true
			if $Candle2 != null:
				$Candle2/FireOrigin/Fire.visible = true
			if $Candle3 != null:
				$Candle3/FireOrigin/Fire.visible = true
			firelight.visible = true
#			$MeshInstance.cast_shadow = false
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !durable_timer.is_stopped():
		$AnimationPlayer.play("flicker")
		$Candle1/FireOrigin/Fire.visible = not $Candle1/FireOrigin/Fire.visible
#		$Candle1/MeshInstance.emission_enabled = not $Candle1/MeshInstance.emission_enabled
		if $Candle2 != null:
			$Candle2/FireOrigin/Fire.visible = not $Candle2/FireOrigin/Fire.visible
		if $Candle3 != null:
			$Candle3/FireOrigin/Fire.visible = not $Candle3/FireOrigin/Fire.visible
		firelight.visible = not firelight.visible
#		$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
	else:
		$AnimationPlayer.stop()
		$Candle1/FireOrigin/Fire.visible = false
#		$Candle1/MeshInstance.emission_enabled = false
		if $Candle2 != null:
			$Candle2/FireOrigin/Fire.visible = false
		if $Candle3 != null:
			$Candle3/FireOrigin/Fire.visible = false
		firelight.visible = false
#		$MeshInstance.cast_shadow = true


func _on_Durability_timeout():
	$AnimationPlayer.stop()
	$Candle1/FireOrigin/Fire.visible = false
#	$Candle1/MeshInstance.emission_enabled = false
	if $Candle2 != null:
		$Candle2/FireOrigin/Fire.visible = false
	if $Candle3 != null:
		$Candle3/FireOrigin/Fire.visible = false
	firelight.visible = false
#	$MeshInstance.cast_shadow = true
