extends GameWorld
class_name FencingSimWorld

@export var enemy_spawner: FencingSimEnemySpawner
@export var candle_circle: CandleCircle
@export var current_wave: int = 1

@export var wave_colors: Dictionary = {
	5: Color.FIREBRICK
}

@export_subgroup("Wave settings")
var wave_settings: Dictionary = {
	1: {
		"amount_of_enemies": 3,
		"enemy_spawn_time": 10
	},
	
	2: {
		"amount_of_enemies": 5,
		"enemy_spawn_time": 7
	},
	
	3: {
		"amount_of_enemies": 7,
		"enemy_spawn_time": 6
	},
	
	4: {
		"amount_of_enemies": 10,
		"enemy_spawn_time": 5
	},
	
	5: {
		"amount_of_enemies": 12,
		"enemy_spawn_time": 3
	}
}

@export_subgroup("Scene Nodes")
@export var central_light: SpotLight3D

#region Debug Panel Variables
# this variables shouldn't be used in game logic, they are containers for communicating with ImGui
var number_of_candles := [3]
#endregion

func _ready() -> void:
	begin_wave(1)
	
	SignalBus.candle_unlit.connect(func(candle_unlit: CandleItem): # Listens for candles unlit, to see if needs to trigger next wave
		
		if candle_circle.candles.has(candle_unlit):
			candle_circle.candles[candle_unlit].is_lit = false
		
		var candle_data: Dictionary = candle_circle.get_candles_data()
		var amount_of_candles_off: int = 0
		for candle in candle_data:
			if candle_data[candle].is_lit == false:
				amount_of_candles_off += 1
		
		if amount_of_candles_off == candle_circle.candle_count:
			begin_wave(current_wave + 1)
		)
	

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_switch_mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
	
	
	if Engine.has_singleton("ImGuiAPI"): # prevents from everything breaking when we export without ImGui
		var ImGui: Object = Engine.get_singleton("ImGuiAPI")
	
	ImGui.Begin("Debug Panel")
	ImGui.Text("Settings: enemies_with_darkvision = " + str(Settings.get_setting("enemies_with_darkvision")))
	ImGui.Text("Current wave: " + str(current_wave))
	
	if ImGui.Button("Spawn Test Enemy"):
		enemy_spawner.spawn_enemy_on_random_candle()
		
	if ImGui.Button("Kill random enemy"):
		print("killing random enemy")
		var dummies: Array[Node] = get_tree().get_nodes_in_group("dummies")

		if dummies.size() == 0: return

		var random_dummy = dummies.pick_random()
		for child in random_dummy.get_children():
			if child is FencingSimEnemyComponent:
				child.die()
	
	if ImGui.Button("Increase Wave"):
		begin_wave(current_wave + 1)
	
	if ImGui.SliderInt("N° of Candles", number_of_candles, 3, 8):
		var number: int = floor(number_of_candles[0])
		candle_circle.candle_count = number
		
	# Debug candle circle
	if ImGui.BeginTable("Candle Circle", 4):
		ImGui.TableSetupColumn("Candle")
		#ImGui.TableSetupColumn("global_position")
		ImGui.TableSetupColumn("direction_to_center")
		ImGui.TableSetupColumn("enemy_spawned")
		ImGui.TableHeadersRow()
		
		for candle in candle_circle.candles.keys():
			ImGui.TableNextRow()
			ImGui.TableNextColumn()
			ImGui.Text(candle.name)
			#ImGui.TableNextColumn()
			#ImGui.Text(str(enemy_spawner.candle_circle.candles[candle].global_position))
			ImGui.TableNextColumn()
			ImGui.Text(str(candle_circle.candles[candle].direction_to_center))
			ImGui.TableNextColumn()
			ImGui.Text(str(candle_circle.candles[candle].enemy_spawned))
		ImGui.EndTable()
	
	ImGui.End()


func _physics_process(delta: float) -> void:
	match current_wave:
		5:
			central_light.light_color = wave_colors[current_wave]
		_: # default
			central_light.light_color = Color.WHITE
			
	# Move the ceiling while transitioning to a new wave
	if !$ceiling/StopMovingTimer.is_stopped():
		$ceiling.global_position.y += 0.2 * delta


func begin_wave(wave_to_begin: int) -> void:
	current_wave = wave_to_begin
	
	# When final candle of wave unlit, wait a moment, then start cave wind sound
	await get_tree().create_timer(1.2).timeout
	
	match current_wave:
		2:
			$CaveWindSoundEmitter.stream = load("res://resources/sounds/cave_wind/130975__brandonnyte__wailing-winds_1.mp3")
		3:
			$CaveWindSoundEmitter.stream = load("res://resources/sounds/cave_wind/130975__brandonnyte__wailing-winds_2.mp3")
		4:
			$CaveWindSoundEmitter.stream = load("res://resources/sounds/cave_wind/130975__brandonnyte__wailing-winds_3.mp3")
		5:
			$CaveWindSoundEmitter.stream = load("res://resources/sounds/cave_wind/130975__brandonnyte__wailing-winds_4.mp3")
	$CaveWindSoundEmitter.play()
	
	# ceiling raises over course of 5 seconds.
	if current_wave > 1:
		$ceiling/StopMovingTimer.start()
	
	# A few seconds after cave wind sound completes, light candles for the next wave
	$CaveWindSoundEmitter.finished.connect(func():
		await get_tree().create_timer(1).timeout
		candle_circle.candle_count = wave_settings[current_wave]["amount_of_enemies"]
		enemy_spawner.spawn_time = wave_settings[current_wave]["enemy_spawn_time"]
		)
	
	if current_wave == 1: # first wave doesnt play sound so we have to force it
		candle_circle.candle_count = wave_settings[current_wave]["amount_of_enemies"]
		enemy_spawner.spawn_time = wave_settings[current_wave]["enemy_spawn_time"]
	
	pass
