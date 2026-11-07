## Port of the 3.x tinnitus effect (scenes/characters/player/tinnitus.gd on
## origin/main): an ear-ring audio loop with a white screen wash. The ring
## intensity t rises while triggers arrive and decays at a quarter rate, so
## rapid triggers refresh the ring instead of stacking it. Producers emit
## Events.tinnitus_triggered(strength); strength is the amount of ring to add
## on the 0..1 scale (a continuous producer passes its frame delta, a gunshot
## passes its normalized loudness).
extends AudioStreamPlayer

const SILENCE_DB := -100.0
const FULL_VOLUME_DB := 0.0
## 3.x decay rate: t falls at a quarter of the rise rate (dir = -0.25).
const DECAY_RATE := 0.25

var _t := 0.0
var _triggered_this_frame := false
var _is_dead := false

@onready var _white_rect: TextureRect = $ScreenWhite/TextureRect


func _ready() -> void:
	volume_db = SILENCE_DB


## Adds ring intensity on the 0..1 scale. Later triggers while already
## ringing raise (or hold) the level; nothing stacks beyond full.
func trigger(strength : float = 1.0) -> void:
	if _is_dead:
		return
	_t = clampf(_t + strength, 0.0, 1.0)
	_triggered_this_frame = true


## Death stops the ring and the white wash for good (3.x death hookup).
func set_dead() -> void:
	_is_dead = true
	playing = false
	_white_rect.hide()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if not _triggered_this_frame:
		_t = clampf(_t - delta * DECAY_RATE, 0.0, 1.0)
	_triggered_this_frame = false
	# The 3.x volume curve is exactly linear from (0, -100 dB) to (1, 0 dB).
	volume_db = lerpf(SILENCE_DB, FULL_VOLUME_DB, _t)
	var should_play := not is_equal_approx(_t, 0.0)
	if playing != should_play:
		playing = should_play
	if should_play:
		_white_rect.modulate.a = _t
	else:
		_white_rect.modulate.a = 0.0
