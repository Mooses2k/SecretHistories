extends Control
class_name HUD

enum Indicator {
	DOT,
	GRAB,
	IGNITE,
	NONE,
}
# same order as enum
@onready var indicators : Array[TextureRect] = [
	$IndicatorDot,$IndicatorGrab,$IndicatorIgnite
]

var active_indicator : Indicator = Indicator.NONE:
	set(value):
		hide_indicators()
		active_indicator = value
		print(active_indicator)
		if value != Indicator.NONE:
			indicators[value].show()

func hide_indicators():
	for i in indicators:
		i.hide()

func _ready() -> void:
	hide_indicators()

func exit_state():
	self.visible = false


func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	self.visible = true
