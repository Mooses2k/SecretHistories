## Port of the 3.x death screen (scenes/characters/player/player_death.gd on
## origin/main): black cover, death sound, grayscale reveal of the frozen
## scene, any-key fade out, then back to the title menu. Issue #414 puts a
## ragdoll window in front of it: the tree keeps running while the death cam
## rides the falling body, the black cover fades in slowly over that window
## behind an eye-closing stencil (two soft-edged lids closing from the top
## and the bottom), and the tree pauses only when the cover is fully down so
## the corpse freezes for the grayscale reveal.
extends Control

signal fade_out_started()

const TITLE_MENU_PATH := "res://scenes/ui/title_menu.tscn"
const BW_REVEAL_DELAY := 1.5
const BW_FADE_TIME := 0.5
const INPUT_FADE_TIME := 0.7
const INPUT_FADE_WAIT := 1.0
## Fraction of the viewport each stencil lid travels to close the eye.
const LID_CLOSED_FRACTION := 0.5

## Length of the unpaused ragdoll window: the cover fade, the stencil and
## the death cam's fall all run inside it.
@export var death_fade_time : float = 4.0

var _started := false
var _fade_started := false
var _cover_tween : Tween

@onready var _black_rect: ColorRect = $BlackRect
@onready var _bw_rect: ColorRect = $BWRect
@onready var _lid_top: TextureRect = $LidTop
@onready var _lid_bottom: TextureRect = $LidBottom
@onready var _death_sound: AudioStreamPlayer = $DeathSound


## Entry: GameUI routes the player's DEAD physical state here once.
func start_sequence() -> void:
	if _started:
		return
	_started = true
	GameManager.is_player_dead = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_death_sound.play()
	_close_eyes()


func _close_eyes() -> void:
	var viewport_height : float = get_viewport().get_visible_rect().size.y
	var lid_travel : float = viewport_height * LID_CLOSED_FRACTION
	_black_rect.show()
	_black_rect.modulate.a = 0.0
	_lid_top.show()
	_lid_top.offset_bottom = 0.0
	_lid_bottom.show()
	_lid_bottom.offset_top = 0.0
	_cover_tween = create_tween().set_parallel()
	_cover_tween.tween_property(_black_rect, "modulate:a", 1.0, death_fade_time)
	_cover_tween.tween_property(_lid_top, "offset_bottom", lid_travel, death_fade_time)
	_cover_tween.tween_property(_lid_bottom, "offset_top", -lid_travel, death_fade_time)
	await _cover_tween.finished
	_cover_down()


## The cover is fully down: freeze the corpse, then run the 3.x reveal
## contract (1.5 s of darkness, then the grayscale layer with the cover
## fading out under it).
func _cover_down() -> void:
	if _fade_started:
		return
	_lid_top.hide()
	_lid_bottom.hide()
	get_tree().paused = true
	await get_tree().create_timer(BW_REVEAL_DELAY).timeout
	_reveal()


func _reveal() -> void:
	_bw_rect.show()
	var tween := create_tween()
	tween.tween_property(_black_rect, "modulate:a", 0.0, BW_FADE_TIME)


## ESC is its own escape hatch (owner playtest defect 6): the pause gating
## keys off GameManager.is_player_dead and would otherwise swallow ESC on the
## death screen, so the screen consumes ESC itself, from the moment the
## sequence starts, through the ragdoll window and the grayscale reveal. Any
## other pressed key or mouse click still waits for the reveal, per the 3.x
## is_bw contract.
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
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	_lid_top.hide()
	_lid_bottom.hide()
	fade_out_started.emit()
	var tween := create_tween()
	tween.tween_property(_black_rect, "modulate:a", 1.0, INPUT_FADE_TIME)
	await tween.finished
	await get_tree().create_timer(INPUT_FADE_WAIT).timeout
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_MENU_PATH)
