## Port of the 3.x blood screen (scenes/characters/player/player_hit.gd on
## origin/main, the HitEffect visual half): a per-hit blood splatter flash and
## a persistent blood vignette whose pulse strength follows the durability
## ladder. The overlay only renders what GameUI routes into it: Hurtbox
## damaged events and the DEAD physical state.
extends Control

const FLASH_FADE_TIME := 0.9

# Durability ladder from 3.x player_hit.gd (threshold, low alpha, high alpha,
# pulse speed). The 3.x script carried the tween speed in a variable that only
# some tiers updated, so a descent from full health resolves the speeds shown
# here; the same monotonic descent produces the same speeds.
const PULSE_TIERS := [
	[40, 0.05, 0.2, 0.7],
	[35, 0.1, 0.3, 0.7],
	[30, 0.2, 0.4, 0.6],
	[25, 0.3, 0.5, 0.6],
	[20, 0.4, 0.6, 0.5],
	[15, 0.5, 0.7, 0.5],
	[10, 0.6, 0.8, 0.4],
	[5, 0.7, 0.98, 0.4],
]

var _pulse_low := 0.0
var _pulse_high := 0.0
var _pulse_speed := 0.7
var _pulse_rising := false
var _pulse_running := false
var _is_dead := false
var _flash_tween : Tween = null
var _pulse_tween : Tween = null

@onready var _flash_rect: TextureRect = $HitFlashRect
@onready var _overlay_rect: TextureRect = $LowHealthRect


## A hit was taken: flash the splatter and refresh the vignette ladder from
## the durability read AFTER the damage was applied.
func on_player_hit(durability : int) -> void:
	if _is_dead:
		return
	_flash()
	# Tightest band first: 3.x checked the thresholds from the deepest rung
	# upward, so a durability sits in exactly one band (for example 34 in the
	# 35 rung, never the 40 one).
	var index := PULSE_TIERS.size() - 1
	while index >= 0:
		var tier : Array = PULSE_TIERS[index]
		if durability <= int(tier[0]):
			_pulse_low = float(tier[1])
			_pulse_high = float(tier[2])
			_pulse_speed = float(tier[3])
			if not _pulse_running:
				_start_pulse()
			return
		index -= 1
	# Above the top threshold there is no vignette. 3.x never stopped a pulse
	# once it was running (it had no healing path either), so a running pulse
	# keeps running with its previous strength.


## Death hides both layers for good (3.x player_hit.gd death hookup).
func set_dead() -> void:
	_is_dead = true
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_flash_rect.hide()
	_overlay_rect.hide()


func _flash() -> void:
	_flash_rect.show()
	_flash_rect.modulate.a = 1.0
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "modulate:a", 0.0, FLASH_FADE_TIME) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _start_pulse() -> void:
	_overlay_rect.show()
	_pulse_running = true
	_pulse_rising = true
	_run_pulse_segment()


func _run_pulse_segment() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	var target_alpha := _pulse_high if _pulse_rising else _pulse_low
	_pulse_tween.tween_property(_overlay_rect, "modulate:a", target_alpha, _pulse_speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.finished.connect(_on_pulse_segment_finished)


func _on_pulse_segment_finished() -> void:
	_pulse_rising = not _pulse_rising
	_run_pulse_segment()
