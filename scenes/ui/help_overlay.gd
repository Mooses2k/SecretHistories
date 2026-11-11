extends Control
class_name HelpOverlay

## The F1 help overlay (3.x scenes/characters/player/player_hit.gd on
## origin/main): toggling misc|help_info shows or hides two labels, the
## keybind defaults list and a live player debug readout.

const KEYBIND_DEFAULTS_TEXT := """WASD - movement
Space - jump
LCtrl or C - crouch
LShift (move forward) - sprint
LShift (without moving forward) - kick (doors, objects, opponents)

LMB - main-hand primary use
RMB (tap) - interact, pick up, otherwise main-hand secondary use
RMB (held) - grab & drag things around
Number row & mouse-wheel - cycle main-hand item
MMB - throw main-hand item

LAlt - use off-hand item
Tab - cycle off-hand items
T or G - throw off-hand item

R (tap) - reload
R (held) - unload

B - binocs/spyglass (if you have the item)
F or N - night vision / darksight (if you have the item)
Z - zap spell (if you have one)
M - minimap (currently for debug/cheating)
J - journal
I - inventory
L - toggle the debug light
F11 - fullscreen toggle

F1 - show/hide this menu

(almost all keys rebindable as you like)"""

@onready var debug_label : RichTextLabel = $DebugInfo
@onready var keybind_label : RichTextLabel = $KeybindDefaults

var _player : Node = null
var _state : HumanoidCharacterState = null


func _ready() -> void:
	keybind_label.text = KEYBIND_DEFAULTS_TEXT
	set_player(GameManager.game.player if is_instance_valid(GameManager.game) else null)


## Rewires to a freshly spawned player (floors re-emit player_spawned).
func set_player(player : Node) -> void:
	_player = player
	_state = null
	if player != null and player.has_node("State"):
		_state = player.get_node("State") as HumanoidCharacterState


func toggle() -> void:
	visible = not visible


func _process(_delta : float) -> void:
	if not visible:
		return
	debug_label.text = (
		"Player durability = " + str(_state.durability if _state != null else -1) + "\n"
		+ "Player stamina = " + str(snappedf(_state.stamina_ratio if _state != null else 0.0, 0.01)) + "\n"
		+ "Player on ground = " + str(_state.is_on_ground if _state != null else false) + "\n"
		+ "Current strata = " + str(GameManager.game.current_floor_level if is_instance_valid(GameManager.game) else 0) + "\n"
		+ "Player position = " + str(_player.global_position if _player != null else Vector3.ZERO) + "\n"
		+ "Current FPS = " + str(Performance.get_monitor(Performance.TIME_FPS)) + "\n"
	)
