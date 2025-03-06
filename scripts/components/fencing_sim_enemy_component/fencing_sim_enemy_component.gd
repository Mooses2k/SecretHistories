extends Node3D
## fencing_sim_enemy_component.gd - Written by Vinicius - 02/28/2025
## A component that dictates that the owner of this component is a Fencing Sim Enemy
class_name FencingSimEnemyComponent


## A refence to what candle is responsible for this agent
@export var my_candle: Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("fencing_sim_enemies")

func die() -> void:
	if is_instance_valid(my_candle): # in case that the original candle was freed by circle resize
		var candle = my_candle as CandleItem
		
		candle.play_blowout_sound()
		candle.unlight()
		SignalBus.candle_unlit.emit(my_candle)
	get_parent().queue_free()
