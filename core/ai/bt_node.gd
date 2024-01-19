class_name BTNode extends Node


enum BTResult {
	OK,
	FAILED,
	RUNNING,
	SKIP,
}

var _current_status : int = BTResult.SKIP
var _root : BTNode = null
## Virtual functions (override these when implementing new nodes)

# This function will be called right before a tick
func _pre_tick():
	pass

# Called on each tick this node is executed
func _tick(_state : CharacterState) -> int:
	return BTResult.FAILED

# This function will be called right after a tick
func _post_tick():
	pass

# This function can be overridden to return useful data about this node,
# for debug purposes
func _get_node_state() -> Dictionary:
	return {}


# These functions are the entry points of the virtual ones
# and perform common functionality, usually should not be overriden

func on_pre_tick():
	_current_status = BTResult.SKIP
	_pre_tick()

func tick(_state : CharacterState) -> int:
	var result = _tick(_state)
	_current_status = result
	return result

func on_post_tick():
	_post_tick()

func get_node_state() -> Dictionary:
	return _get_node_state()

func get_current_status() -> int:
	return _current_status

func get_root() -> BTNode:
	return _root
