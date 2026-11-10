class_name AIStateDead
extends AIState

## Terminal state: clear the movement intents, announce the death, and do
## nothing from here on. The table must carry no outgoing rows from Dead;
## the machine parks on this state.


signal died


func enter() -> void:
	super.enter()
	if brain != null and brain.navigation != null:
		brain.navigation.stop()
	died.emit()


func tick(_delta: float) -> void:
	pass
