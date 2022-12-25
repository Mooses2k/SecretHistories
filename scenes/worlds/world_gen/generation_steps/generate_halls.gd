extends GenerationStep


export var max_hall_size : int = 8
export var hall_creation_chance : float = 0.5

export(Array, WorldData.CellType) var valid_neighbours = [WorldData.CellType.CORRIDOR]


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var random = RandomNumberGenerator.new()
	random.seed = generation_seed
	generate_halls(data, random)
	pass


func generate_halls(data : WorldData, random : RandomNumberGenerator):
	var region_id : PoolIntArray = PoolIntArray()
	region_id.resize(data.cell_count)
	region_id.fill(-1)
	var current_region = 0
	var region_valid : Array = Array()
	var region_size : Array = Array()
	for i in data.cell_count:
		if region_id[i] < 0 and data.get_cell_type(i) == data.CellType.EMPTY:
			if current_region == 1:
				pass
			region_valid.push_back(true)
			var queue = Array()
			var queue_idx = 0
			queue.push_back(i)
			region_id[i] = current_region
			while queue_idx < queue.size():
				var current = queue[queue_idx]
				if data.get_cell_type(current) == data.CellType.EMPTY:
					for dir in data.Direction.DIRECTION_MAX:
						var neighbour = data.get_neighbour_cell(current, dir)
						if neighbour < 0:
							region_valid[neighbour] = false
							continue
						var neighbour_type = data.get_cell_type(neighbour)
						if neighbour_type == data.CellType.EMPTY:
							if region_id[neighbour] < 0:
								region_id[neighbour] = current_region
								queue.push_back(neighbour)
						elif not valid_neighbours.has(neighbour_type):
							region_valid[current_region] = false
				queue_idx += 1
			region_size.push_back(queue_idx)
			if queue_idx > max_hall_size:
				region_valid[current_region] = false
			if region_valid[current_region]:
				var chance = random.randf() <= hall_creation_chance and not hall_creation_chance == 0.0
				region_valid[current_region] = chance
			current_region += 1
	for i in data.cell_count:
		if region_id[i] >= 0 and region_valid[region_id[i]]:
			data.set_cell_type(i, data.CellType.HALL)
	pass
