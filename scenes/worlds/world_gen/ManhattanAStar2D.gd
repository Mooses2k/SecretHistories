class_name ManhattanAStar2D
extends AStar2D

# Computes the true manhattan distance between 2 points
func _compute_cost(from_id: int, to_id: int) -> float:
	return get_manhattan_distance(get_point_position(from_id), get_point_position(to_id))

# Computes a biased manhattan distance between 2 points, giving less weight
# to longer edges. This makes it so the algorithm will prefer to move along
# shorter edges first, and avoid zig zags
func _estimate_cost(from_id: int, to_id: int) -> float:
	return get_biased_manhattan_distance(get_point_position(from_id), get_point_position(to_id))


func get_manhattan_distance(a : Vector2, b : Vector2) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)


func get_biased_manhattan_distance(a : Vector2, b : Vector2) -> float:
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return min(dx, dy) + 0.5*max(dx, dy)
