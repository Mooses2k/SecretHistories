extends Node

export var cultist : PackedScene
var is_cultist_spawned = false
var free_cell = 0


func get_next_free_cell(data : WorldData) -> bool:
	free_cell += 1
	while data.get_cell_type(free_cell) == data.CellType.EMPTY and free_cell < data.cell_count:
		free_cell += 1
	return true
	if free_cell >= data.cell_count:
		return false


func spawn_items(data : WorldData):
	var tiny_item_scene = preload("res://scenes/objects/pickable_items/tiny/_tiny_item.tscn")
	var settings : SettingsClass = GameManager.game.local_settings
	get_next_free_cell(data)
	for s in settings.get_settings_list():
		var g = settings.get_setting_group(s)
		if g == "Equipment":
			var amount = settings.get_setting(s)
			var item_scene : PackedScene = load(s)
			for i in amount:
				if not get_next_free_cell(data):
					return
				var pos = data.get_local_cell_position(free_cell) + Vector3(0.75, 1.0, 0.75)

				var item
				if not is_cultist_spawned:
					is_cultist_spawned = true
					item = cultist.instance()
				else:
					item = item_scene.instance()
				(item as Spatial).translation = pos

				owner.add_child(item)
		elif g == "Tiny Items":
			var amount = settings.get_setting(s)
			if amount == 0:
				continue
			if not get_next_free_cell(data):
				return
			var pos = data.get_local_cell_position(free_cell) + Vector3(0.75, 1.0, 0.75)
			var item : TinyItem = tiny_item_scene.instance()
			item.amount = amount
			item.item_data = load(s)
			item.translation = pos
			owner.add_child(item)
			pass


func _on_ProceduralWorld_generation_finished() -> void:
	spawn_items(owner.world_data)
	pass # Replace with function body.
