extends MeshInstance3D

## Debug aid: parks the marker on the navigation adapter's current goal.
## Read-only copy of the frozen cultists-old helper, re-pointed from the
## CharacterState surface to the HFSM's NavigationAdapter.

@onready var _controller: Node = $"../../AIController"


func _process(_delta: float) -> void:
	var navigation: NavigationAdapter = _controller.navigation_adapter
	if navigation == null:
		return
	global_position = navigation.target_position
