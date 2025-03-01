@tool
## This class is used specificaaly for Fencing Sim, to avoid unwanted behaviors, avoid setting variables directly
class_name CandleCircle
extends Node3D

@export_range(0, 20, 0.1) var diameter: float = 5.0: set = _diameter_setter
@export_range(0, 12, 1) var candle_count: int = 8: set = _candle_count_setter
@export var candle_scene: PackedScene

## A Dictionary containing data for each candle, key is CandleItem and value is another dict with useful data [br]
## has [code]global_position[/code] [code]spawned_enemy[/code] [code]direction_to_center[/code]
var candles: Dictionary = {}

func _ready() -> void:
	_generate_candles(); # This is called cause the script is a tool script, but for spawning when the game starts, you need to put the logic inside _ready
	
	for candle : CandleItem in get_children():
		candle.light()

func _generate_candles() -> void:
	var radius = diameter / 2.0
	
	# clear children
	for child in get_children():
		candles.erase(child)
		child.queue_free()
	
	for i in range(candle_count):
		var theta = 2 * PI * i / candle_count
		var x = radius * cos(theta)
		var z = radius * sin(theta)
		
		var candle_instance = candle_scene.instantiate() as CandleItem
		add_child(candle_instance)
		candle_instance.global_position = Vector3(x, 0, z)
		var new_data: Dictionary = {
			"global_position" = candle_instance.global_position,
			"direction_to_center" = candle_instance.global_position.direction_to(global_position),
			"enemy_spawned" = false
		}
		
		candles[candle_instance] = new_data
		

## Returns a dictionary containing the index and position of a candle [br]
## Ex of return: {1: Vector3(69, 69, 420) }
func get_candles_world_position() -> Dictionary:
	var positions: Dictionary
	for child_index: int in get_child_count():
		positions[child_index] = get_child(child_index).global_position
	
	return positions

## Returns useful data from each candle [br]
## keys are candle index as child from candle_circle [br]
## [code]global_position[/code][br]
## [code]direction_to_center[/code][br]
func get_candles_data() -> Dictionary:
	#var data: Dictionary
	#
	#for child_index: int in get_child_count():
		#var child: CandleItem = get_child(child_index)
		#var new_data: Dictionary = {
			#"node" = child,
			#"global_position" = child.global_position,
			#"direction_to_center" = child.global_position.direction_to(global_position),
			#"enemy_spawned" = false
		#}
		#data[child_index] = new_data
	return candles


## Use this method whenever you need to update the circle
func update_circle(new_diameter: float, new_candle_count: int) -> void:
	diameter = new_diameter
	candle_count = new_candle_count

## Access candles data and set a candle .enemy_spawned = spawned_enemy
func set_candle_spawned_enemy(candle: Node3D, spawned_enemy: bool) -> bool:
	
	#if get_children().find(candle) != null:
	if candles[candle] != null: # Check if candle existis
		candles[candle].spawned_enemy = spawned_enemy
		return true
	
	return false


## -------------- SETTERS - Do not call from outside, or do --------


func _diameter_setter(new_diameter: float) -> void:
	print('set diameter')
	diameter = new_diameter
	if is_inside_tree():
		_generate_candles()

func _candle_count_setter(new_count: int) -> void:
	print('set candle count')
	candle_count = new_count
	if is_inside_tree():
		_generate_candles()
