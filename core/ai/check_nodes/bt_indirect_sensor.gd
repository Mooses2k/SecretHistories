class_name BTIndirectSensor extends BTNode


var memory := {}


func add_sensory_input(position: Vector3, id, interest := 0) -> void:
	if !memory.keys().has(interest): memory[interest] = {}
	memory[interest][id] = position


func remove_sensory_input(id) -> void:
	if memory.has(id): memory.erase(id)


func get_most_interesting(delete_after_fetch := false) -> Dictionary:
	var interest_levels := memory.keys()
	while !interest_levels.empty():
		interest_levels.sort()
		
		if memory[interest_levels[-1]].empty():
			interest_levels.remove(-1)
			continue
			
		break
	
	if interest_levels.empty(): return {}
	
	var result :=\
	{
		"position": memory[interest_levels[-1]].values()[-1]["position"],
		"id": 		memory[interest_levels[-1]].values()[-1]["id"],
	}
	
	if delete_after_fetch:
		memory[interest_levels[-1]].erase(memory[interest_levels[-1]].keys()[-1])
	
	return result
