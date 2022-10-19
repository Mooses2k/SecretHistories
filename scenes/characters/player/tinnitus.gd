extends AudioStreamPlayer


var occuring = false
export var curve : Curve
export var period = 1.0

var t = 0
var threshold = 1.0
var is_dead = false


func _ready():
	volume_db = curve.interpolate(0)


func enable():
	occuring = true


func _physics_process(delta):
	if not is_dead:
		var dir = 1.0 if occuring else -0.25
		t += delta*dir/period
		t = clamp(t, 0, 1)
		volume_db = curve.interpolate(t)
		var should_play = not is_equal_approx(t, 0)

		if playing != should_play:
			playing = should_play

		if should_play:
			$ScreenWhite/TextureRect.modulate.a = t
		else:
			$ScreenWhite/TextureRect.modulate.a = 0
			
		#Disable at frame end
		occuring = false


#if not in body
#	tinnitus = false


func _on_Player_character_died():
	is_dead = true
	playing = false
	$ScreenWhite/TextureRect.hide()
