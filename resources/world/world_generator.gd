extends Resource
class_name WorldGenerator
#basic test generator, override for more complex behavior
func get_data() -> WorldData:
	var data = WorldData.new()

	return data
