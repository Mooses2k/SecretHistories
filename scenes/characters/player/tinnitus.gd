extends AudioStreamPlayer

var occuring = false
export var curve : Curve
export var period = 1.0

var t = 0
var threshold = 1.0

func _ready():
	volume_db = curve.interpolate(0)

func enable():
	occuring = true

func _physics_process(delta):
	var dir = 1.0 if occuring else -1.0
	t += delta*dir/period
	t = clamp(t, 0, 1)
	volume_db = curve.interpolate(t)
	var should_play = not is_equal_approx(t, 0)
	if playing != should_play:
		playing = should_play
	#Disable at frame end
	occuring = false


#if not in body
#	tinnitus = false
