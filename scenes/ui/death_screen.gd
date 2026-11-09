## Port of the 3.x death screen (scenes/characters/player/player_death.gd on
## origin/main): black cover, death sound, grayscale reveal of the frozen
## scene, any-key fade out, then back to the title menu. Runs while the tree
## is paused (the corpse stays frozen; the camera work stays out of this
## port on purpose, that is issue #414's character lane).
extends Control

const TITLE_MENU_PATH := "res://scenes/ui/title_menu.tscn"
const BW_REVEAL_DELAY := 1.5
const BW_FADE_TIME := 0.5
const INPUT_FADE_TIME := 0.7
const INPUT_FADE_WAIT := 1.0

var _started := false
var _fade_started := false

@onready var _black_rect: ColorRect = $BlackRect
@onready var _bw_rect: ColorRect = $BWRect
@onready var _death_sound: AudioStreamPlayer = $DeathSound


## Entry: GameUI routes the player's DEAD physical state here once.
func start_sequence() -> void:
	if _started:
		return
	_started = true
	GameManager.is_player_dead = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_black_rect.show()
	_black_rect.modulate.a = 1.0
	_death_sound.play()
	# create_timer runs while the tree is paused.
	await get_tree().create_timer(BW_REVEAL_DELAY).timeout
	_reveal()


func _reveal() -> void:
	_bw_rect.show()
	var tween := create_tween()
	tween.tween_property(_black_rect, "modulate:a", 0.0, BW_FADE_TIME)


## ESC is its own escape hatch (owner playtest defect 6): the pause gating
## keys off GameManager.is_player_dead and would otherwise swallow ESC on the
## death screen, so the screen consumes ESC itself, from the moment the
## sequence starts, before the grayscale reveal. Any other pressed key or
## mouse click still waits for the reveal, per the 3.x is_bw contract.
func _input(event : InputEvent) -> void:
	if not _started or _fade_started:
		return
	if event.is_action_pressed(&"esc_menu") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_fade_out_to_title()
		return
	if not _bw_rect.visible:
		return
	var pressed_key : bool = event is InputEventKey and event.pressed and not event.echo
	var pressed_mouse : bool = event is InputEventMouseButton and event.pressed
	if pressed_key or pressed_mouse:
		get_viewport().set_input_as_handled()
		_fade_out_to_title()


func _fade_out_to_title() -> void:
	if _fade_started:
		return
	_fade_started = true
	var tween := create_tween()
	tween.tween_property(_black_rect, "modulate:a", 1.0, INPUT_FADE_TIME)
	await tween.finished
	await get_tree().create_timer(INPUT_FADE_WAIT).timeout
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_MENU_PATH)
