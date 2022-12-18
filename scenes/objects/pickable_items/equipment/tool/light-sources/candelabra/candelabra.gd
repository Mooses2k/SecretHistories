extends ToolItem
class_name CandelabraItem


# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that

# function this out better, lots of duplicated lines

# emission turn off doesn't work

onready var firelight = $Candle1/FireOrigin/Fire/Light
onready var durable_timer = $Durability

var has_ever_been_on = false 
var is_lit = false

var material
var newMat

func _ready():
	material = $Candle1/MeshInstance.get_surface_material(0)
	newMat = material.duplicate()
	$Candle1/MeshInstance.set_surface_material(0,newMat)
	durable_timer.start()


func _process(delta):
	if is_lit == true:
		durable_timer.pause_mode = false
	else:
		durable_timer.pause_mode = true
	if self.mode == equipped_mode and has_ever_been_on == false:
			durable_timer.start()
			has_ever_been_on = true
#			firelight.visible = not firelight.visible
			$AnimationPlayer.play("flicker")
#			$Candle1/FireOrigin/Fire.visible = not $Candle1/FireOrigin/Fire.visible
#			$Candle1/MeshInstance.get_surface_material(0).emission_enabled = not  $Candle1/MeshInstance.get_surface_material(0).emission_enabled
#			$Candle1/MeshInstance.cast_shadow = not $Candle1/MeshInstance.cast_shadow
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !durable_timer.is_stopped():
		$Candle1/FireOrigin/Fire.visible = not $Candle1/FireOrigin/Fire.visible
		firelight.visible = not firelight.visible
#		$Candle1/MeshInstance.cast_shadow = not $Candle1/MeshInstance.cast_shadow
		$Candle1/MeshInstance.get_surface_material(0).emission_enabled  = not $Candle1/MeshInstance.get_surface_material(0).emission_enabled 
	else:
		$AnimationPlayer.stop()
		$Candle1/MeshInstance.get_surface_material(0).emission_enabled = false
		$Candle1/FireOrigin/Fire.emitting = false
		firelight.visible = false
		$Candle1/MeshInstance.cast_shadow = true
		

func _on_Durability_timeout():
	$Candle1/FireOrigin/Fire.emitting = false
	firelight.visible = false
	$AnimationPlayer.stop()
	$Candle1/MeshInstance.get_surface_material(0).emission_enabled = false
#	$Candle1/MeshInstance.cast_shadow = true

