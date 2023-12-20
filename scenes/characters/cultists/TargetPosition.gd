extends MeshInstance


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var state = owner.character_state as CharacterState
	if is_instance_valid(state):
		var path = state.path
		if not path.empty():
			var pos = state.path[0]
			global_translation = pos
