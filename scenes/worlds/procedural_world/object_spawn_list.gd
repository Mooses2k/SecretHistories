tool
class_name ObjectSpawnList
extends Resource


var _paths := []
var _weights := []
var _min_amounts := []
var _max_amounts := []

var _current_paths := []
var _current_weights := []
var _current_min_amounts := []
var _current_max_amounts := []

var _current_total_weight := 0

### Public Methods --------------------------------------------------------------------------------

func get_random_spawn_data(rng: RandomNumberGenerator) -> SpawnData:
	var spawn_data: SpawnData = SpawnData.new()
	
	if _current_paths.empty():
		_initialize_current_arrays()
	
	var random_value = rng.randi() % _current_total_weight
	var index := 0
	for value in _current_weights:
		var weight := value as int
		if random_value < weight:
			break
		else:
			random_value -= weight
			index += 1
	
	spawn_data.scene_path = _current_paths[index]
	spawn_data.amount = rng.randi_range(_current_min_amounts[index], _current_max_amounts[index])
	
	_exclude_used_index(index)
	_current_total_weight = _calculate_total_weight()
	
	return spawn_data

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _initialize_current_arrays() -> void:
	_current_paths = _paths.duplicate()
	_current_weights = _weights.duplicate()
	_current_min_amounts = _min_amounts.duplicate()
	_current_max_amounts = _max_amounts.duplicate()
	
	_current_total_weight = _calculate_total_weight()


func _exclude_used_index(p_index: int) -> void:
	_current_paths.remove(p_index)
	_current_weights.remove(p_index)
	_current_min_amounts.remove(p_index)
	_current_max_amounts.remove(p_index)


func _calculate_total_weight() -> int:
	var value := 0
	
	for weight in _current_weights:
		value += weight
	
	return value

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

const GROUP_PREFIX = "object_"


### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array:
	var properties: = []
	
	properties.append({
		name = "_paths",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_STORAGE,
	})
	
	properties.append({
		name = "_weights",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_STORAGE,
	})
	
	properties.append({
		name = "_min_amounts",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_STORAGE,
	})
	
	properties.append({
		name = "_max_amounts",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_STORAGE,
	})
	
	properties.append({
		name = "total_items",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_EDITOR,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,1,or_greater"
	})
	
	for index in _paths.size():
		var group_name = GROUP_PREFIX + str(index)
		properties.append({
			name = group_name,
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP,
			hint_string = "%s_"%[group_name]
		})
		
		properties.append({
			name = "%s_%s"%[group_name, "scene_path"],
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tscn"
		})
		
		properties.append({
			name = "%s_%s"%[group_name, "weight"],
			type = TYPE_INT,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1,2,1,or_greater"
		})
		
		properties.append({
			name = "%s_%s"%[group_name, "min_amount"],
			type = TYPE_INT,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1,2,1,or_greater"
		})
		
		properties.append({
			name = "%s_%s"%[group_name, "max_amount"],
			type = TYPE_INT,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1,2,1,or_greater"
		})
		
	return properties


func _get(property: String):
	var value
	
	if property == "total_items":
		value = _paths.size()
	elif property.begins_with(GROUP_PREFIX):
		var prop_data := property.replace(GROUP_PREFIX, "").split("_", false, 1) as PoolStringArray
		var index := (prop_data[0] as String).to_int()
		var key := prop_data[1] as String
		match key:
			"scene_path":
				if _paths[index] == null:
					_paths[index] = ""
				value = _paths[index]
			"weight":
				if _weights[index] == null:
					_weights[index] = 1
				value = _weights[index]
			"min_amount":
				if _min_amounts[index] == null:
					_min_amounts[index] = 1
				value = _min_amounts[index]
			"max_amount":
				if _max_amounts[index] == null:
					_max_amounts[index] = 1
				value = _max_amounts[index]
			_:
				push_error("Unrecognized loot property key: %s"%[key])
	
	return value


func _set(property: String, value) -> bool:
	var has_handled: = true
	
	if property == "total_items":
		for item in [_paths, _weights, _min_amounts, _max_amounts]:
			var array := item as Array
			array.resize(value)
			property_list_changed_notify()
	elif property.begins_with(GROUP_PREFIX):
		var prop_data := property.replace(GROUP_PREFIX, "").split("_", false, 1) as PoolStringArray
		var index := (prop_data[0] as String).to_int()
		var key := prop_data[1] as String
		match key:
			"scene_path":
				_paths[index] = value
			"weight":
				_weights[index] = value
			"min_amount":
				_min_amounts[index] = value
			"max_amount":
				_max_amounts[index] = value
			_:
				push_error("Unrecognized loot property key: %s"%[key])
	else:
		has_handled = false
	
	return has_handled

### -----------------------------------------------------------------------------------------------
