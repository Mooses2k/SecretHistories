class_name Blackboard
extends RefCounted

## The creature's world model: the alertness scalar, the last stimulus, the
## per-object percept map, the current target reference, and the threat model
## that maps stimuli onto alertness. Creature-agnostic; per-creature extras
## go on subclasses as plain typed properties. The `target` field is the save
## compatibility surface: the phase-1 AIController exposes the blackboard as
## its `ai_state`, so SaveManager's `ai_state.target` reads and restores keep
## working unchanged.


enum StimulusKind {
	SIGHT,
	SOUND,
	LIGHT,
	TOUCH,
	INTERACT,
}


enum WeaponMode {
	NONE,
	GUN,
	MELEE,
}


## One perception event, fresh from a sensor or from simulate_stimulus.
class Stimulus extends RefCounted:
	var kind: StimulusKind = StimulusKind.SOUND
	var position := Vector3.ZERO
	var interest := 0.0
	var object: Object = null


## The per-object percept entry, carried over conceptually from the BT's
## InterestMachine: the strongest event seen for that object and its age.
class Percept extends RefCounted:
	var object: Object = null
	var kind: StimulusKind = StimulusKind.SOUND
	var position := Vector3.ZERO
	var interest := 0.0
	var age := 0.0


## How strongly each stimulus kind raises alertness per unit of interest.
## Light is halved per the owner's ruling that a light sighting buys an
## investigate response, never a combat conclusion. Sound interest arrives
## already filtered by the SoundSensor's wall count and sensitivity, so it
## maps onto the alertness scale directly.
const STIMULUS_WEIGHTS := {
	StimulusKind.SIGHT: 1.0,
	StimulusKind.SOUND: 1.0,
	StimulusKind.LIGHT: 0.5,
	StimulusKind.TOUCH: 1.0,
	StimulusKind.INTERACT: 0.5,
}

var alertness := 0.0
## Alertness bands: below investigate_bar is Suspicious territory, at or
## above it Investigate, at or above combat_bar Combat (Combat additionally
## requires a target, which only direct sight of a Player grants).
var investigate_bar := 30.0
var combat_bar := 70.0
## Seconds a stimulus holds alertness up before decay starts, and the
## per-second decay once it does.
var attention_span := 5.0
var decay_rate := 10.0

var last_stimulus: Stimulus = null
## Object -> Percept. Freed objects are pruned on tick.
var percepts := {}
## The current target reference: the Player when directly seen, else null.
## This is the field the save capture and restore read and write.
var target: Object = null
var patrol_anchor := Vector3.ZERO
var weapon_mode: WeaponMode = WeaponMode.NONE
## Set by the death wiring (phase 1 connects the character's
## physical_state_changed); the Dead transition guard reads it.
var dead := false

var _time_since_stimulus := 0.0


## Feed one stimulus into the threat model. Sight of a Player is the one
## stimulus that concludes the player: it floors alertness at the combat bar
## and names the target. Every other kind only raises alertness.
func apply_stimulus(kind: StimulusKind, interest: float, position: Vector3, object: Object = null) -> void:
	var stimulus := Stimulus.new()
	stimulus.kind = kind
	stimulus.interest = interest
	stimulus.position = position
	stimulus.object = object
	last_stimulus = stimulus
	_time_since_stimulus = 0.0
	_upsert_percept(stimulus)
	var weight := stimulus_weight(kind)
	alertness = clampf(alertness + interest * weight, 0.0, 100.0)
	if kind == StimulusKind.SIGHT and object is Player:
		alertness = maxf(alertness, combat_bar)
		target = object


func stimulus_weight(kind: StimulusKind) -> float:
	var weight: float = STIMULUS_WEIGHTS.get(kind, 1.0)
	return weight


## Advance time: percept ages and stimulus decay. Called once per brain tick
## by the root HFSM.
func tick(delta: float) -> void:
	_time_since_stimulus += delta
	_prune_freed_percepts()
	for percept: Percept in percepts.values():
		percept.age += delta
	if _time_since_stimulus > attention_span:
		alertness = maxf(alertness - decay_rate * delta, 0.0)


func alert_reaches_investigate() -> bool:
	return alertness >= investigate_bar


func alert_reaches_combat() -> bool:
	return alertness >= combat_bar


func most_interesting_percept() -> Percept:
	var best: Percept = null
	for percept: Percept in percepts.values():
		if best == null or percept.interest > best.interest:
			best = percept
	return best


func _upsert_percept(stimulus: Stimulus) -> void:
	if stimulus.object == null:
		return
	var percept: Percept = percepts.get(stimulus.object)
	if percept == null:
		percept = Percept.new()
		percept.object = stimulus.object
		percepts[stimulus.object] = percept
	if stimulus.interest >= percept.interest:
		percept.interest = stimulus.interest
		percept.position = stimulus.position
		percept.kind = stimulus.kind
	percept.age = 0.0


func _prune_freed_percepts() -> void:
	var stale: Array = []
	for key in percepts:
		if not is_instance_valid(key):
			stale.append(key)
	for key in stale:
		percepts.erase(key)
