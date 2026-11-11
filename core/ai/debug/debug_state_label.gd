extends Label3D

## Floating debug label showing the brain's active state chain, nested
## machines included ("Combat / Approach"). Default off: toggle the node's
## visible flag to use it. Read at the debug label's process rate, which is
## display only; the state machine's own tick is the truth.

@onready var _brain: HFSM = get_parent()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var chain := PackedStringArray()
	var machine: HFSM = _brain
	while machine != null:
		if machine.active_state == null:
			chain.append("(none)")
			break
		chain.append(String(machine.active_state.name))
		machine = machine.active_state as HFSM
	text = " / ".join(chain)
