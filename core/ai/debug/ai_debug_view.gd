extends Tree

## One-glance HFSM debug panel: the active state name, the last five
## transitions with timestamps, the alertness value, and the blackboard's
## last stimulus line. Bind a brain's root HFSM with bind_machine() and call
## refresh() to update; nothing here ticks on its own.


const TRANSITION_ROWS := 5

var machine: HFSM = null


func bind_machine(root_machine: HFSM) -> void:
	machine = root_machine
	refresh()


func refresh() -> void:
	clear()
	if machine == null:
		return
	var root_item := create_item()
	_add_row(root_item, "Active state", _active_state_label())
	if machine.blackboard != null:
		_add_row(root_item, "Alertness", "%.1f" % machine.blackboard.alertness)
		_add_row(root_item, "Last stimulus", _stimulus_line())
	var history := machine.transition_log
	var first: int = maxi(0, history.size() - TRANSITION_ROWS)
	for i in range(history.size() - 1, first - 1, -1):
		var row: Dictionary = history[i]
		_add_row(root_item, "Transition", "%s -> %s at %.2fs" % [row["from"], row["to"], row["at"]])


func _active_state_label() -> String:
	if machine.active_state == null:
		return "(none)"
	return String(machine.active_state.name)


func _stimulus_line() -> String:
	var stimulus := machine.blackboard.last_stimulus
	if stimulus == null:
		return "(none)"
	var kinds: PackedStringArray = Blackboard.StimulusKind.keys()
	var kind_name: String = kinds[stimulus.kind]
	return "%s interest %.1f at %s" % [kind_name, stimulus.interest, stimulus.position]


func _add_row(parent: TreeItem, label: String, value: String) -> void:
	var item := create_item(parent)
	item.set_text(0, label)
	item.set_text(1, value)
