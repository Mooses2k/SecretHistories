extends Node3D
class_name FencingSimEnemySpawner

@onready var enemy_spawner_timer: Timer = $Timer

@export_subgroup("Scene Behavior")
@export var spawn_time: float
@export var distance_from_candle: float = 0.7

@export_subgroup("Scene Configuration")
@export var candle_circle: CandleCircle
## Wich node to add the enemy as child
@export var spawn_root: Node3D
@export var ENEMY_SCENE: PackedScene


func _ready() -> void:
	randomize()
	enemy_spawner_timer.timeout.connect(_on_spawn_timer_timeount)

## When the timer runs out, pick a random localtion and spawn at it
func _on_spawn_timer_timeount() -> void:
	spawn_enemy_on_random_candle()

## Spawn an enemy, needs to know where to spawn and what candle is the origin of the enemy
func spawn_enemy(spawn_position: Vector3, origin_candle: Node3D) -> void:
	if ENEMY_SCENE == null:
		push_error("No scene for the enemy instance was defined")
		return
	
	var enemy: Node3D = ENEMY_SCENE.instantiate()
	enemy.global_position = spawn_position

	# adds an FencingSimEnemyComponent to the instantiated scene, to be easier to identify it later
	var new_component: FencingSimEnemyComponent = FencingSimEnemyComponent.new()
	new_component.my_candle = origin_candle
	enemy.add_child(new_component)

	spawn_root.add_child(enemy)


## Util func - Prepares data for spawning an enemy, calls spawn_enemy()
func spawn_enemy_on_random_candle() -> void:
	var candles_data: Dictionary = candle_circle.get_candles_data()
	var random_index: int = randi_range(0, candles_data.size() - 1)
	var random_candle_data: Dictionary = {}

	# Klugde to find a candle that has not spawned an enemy yet, basically assumes that the first candle has spawned an enemy and tries to get the first that hasnt
	#region I don't recommend touching here, if needed you can call me on discord: visnicio
	var spawned_enemy = true
	var max_iterations: int = 10 # controller to avoid stack overflow
	var iterations: int = 0
	while spawned_enemy:
		random_index = randi_range(0, candles_data.size() - 1)
		random_candle_data = candles_data[candles_data.keys()[random_index]]
		
		spawned_enemy = random_candle_data.enemy_spawned
		iterations += 1
		if iterations >= max_iterations:
			break
	
	if spawned_enemy: 
		print_debug("Fencing Sim Spawner - Couldn't find available candle")
		return
	#endregion
	
	# Adds an offset to spawn a little further from the candle, in the darkness
	var spawn_position: Vector3 = random_candle_data.global_position - (random_candle_data.direction_to_center - Vector3(0,0,distance_from_candle))
	
	var target_position: Vector3 = spawn_position
	var origin_candle: Node3D = candles_data.keys()[random_index]
	
	spawn_enemy(target_position, origin_candle)
	random_candle_data.enemy_spawned = true # works
	#candle_circle.set_candle_spawned_enemy(origin_candle, true) # doest work


func start_spawning() -> void:
	enemy_spawner_timer.start()


func stop_spawning() -> void:
	enemy_spawner_timer.stop()
