extends GameWorld

@export var enemy_spawner: FencingSimEnemySpawner
var number_of_candles := [3]

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_switch_mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
	
	ImGui.Begin("Debug Panel")
	ImGui.Text("Settings: enemies_with_darkvision = " + str(Settings.get_setting("enemies_with_darkvision")))
	if ImGui.Button("Spawn Test Enemy"):
		enemy_spawner.spawn_enemy_on_random_candle()
		pass
	if ImGui.Button("Kill random enemy"):
		print("killing random enemy")
		var dummies: Array[Node] = get_tree().get_nodes_in_group("dummies")

		if dummies.size() == 0: return

		var random_dummy = dummies.pick_random()
		for child in random_dummy.get_children():
			if child is FencingSimEnemyComponent:
				child.die()
	
	if ImGui.SliderFloat("N° of Candles", number_of_candles, 3, 8):
		var number: int = floor(number_of_candles[0])
		enemy_spawner.candle_circle.candle_count = number
	
	# Debug candle circle
	if ImGui.BeginTable("Candle Circle", 4):
		ImGui.TableSetupColumn("Candle")
		#ImGui.TableSetupColumn("global_position")
		ImGui.TableSetupColumn("direction_to_center")
		ImGui.TableSetupColumn("enemy_spawned")
		ImGui.TableHeadersRow()
		
		for candle in enemy_spawner.candle_circle.candles.keys():
			ImGui.TableNextRow()
			ImGui.TableNextColumn()
			ImGui.Text(candle.name)
			#ImGui.TableNextColumn()
			#ImGui.Text(str(enemy_spawner.candle_circle.candles[candle].global_position))
			ImGui.TableNextColumn()
			ImGui.Text(str(enemy_spawner.candle_circle.candles[candle].direction_to_center))
			ImGui.TableNextColumn()
			ImGui.Text(str(enemy_spawner.candle_circle.candles[candle].enemy_spawned))
		ImGui.EndTable()
	
	ImGui.End()
