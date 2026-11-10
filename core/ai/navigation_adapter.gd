class_name NavigationAdapter
extends Node

## Owns the navigation queries the old CharacterState carried: the world
## navigation map path query, the walkable-cell clamp through WorldData, and
## the scene's optional NavigationAgent3D. States call go_to, at_destination
## and move_intent and never touch the navigation server directly.
## The world_data reference is injected by the controller (it comes from the
## live level); with it null the clamp is skipped.


var character: Node3D = null
var agent: NavigationAgent3D = null
var world_data: WorldData = null
## Distance at which a goal counts as reached (the 3.x ReachTarget threshold).
var arrive_distance := 0.3

var target_position := Vector3.ZERO
var path: Array = []


## Head to a position, clamped to the navmesh and to walkable world-data
## cells like CharacterState.set_target_position did. A goal on an
## unwalkable cell is dropped and the previous goal stands.
func go_to(goal: Vector3) -> void:
	if character == null or not is_instance_valid(character):
		return
	var map: RID = character.get_world_3d().navigation_map
	var clamped: Vector3 = NavigationServer3D.map_get_closest_point(map, goal)
	if world_data != null:
		var cell: int = world_data.get_cell_index_from_local_position(clamped)
		if world_data.get_cell_type(cell) == world_data.CellType.EMPTY:
			return
	target_position = clamped
	if agent != null and is_instance_valid(agent):
		agent.target_position = clamped
	path = NavigationServer3D.map_get_path(map, character.global_position, clamped, false)


func at_destination() -> bool:
	if agent != null and is_instance_valid(agent):
		return agent.is_navigation_finished()
	if character == null:
		return true
	return character.global_position.distance_to(target_position) <= arrive_distance


## Direction toward the next path point; waypoints already inside the arrive
## distance are consumed. Empty when there is nothing to walk.
func move_intent() -> Vector3:
	if character == null:
		return Vector3.ZERO
	while not path.is_empty() \
			and character.global_position.distance_to(path[0]) <= arrive_distance:
		path.pop_front()
	if path.is_empty():
		return Vector3.ZERO
	var step: Vector3 = path[0]
	return step - character.global_position


## Clear all movement, used by the Dead state and on teardown.
func stop() -> void:
	path = []
	if character != null and is_instance_valid(character):
		target_position = character.global_position
	else:
		target_position = Vector3.ZERO
