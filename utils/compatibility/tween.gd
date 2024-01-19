extends Node
#TODO actually implement this
class_name TweenNode

@export var repeat : bool = false
@export var playback_process_mode : Tween.TweenProcessMode = Tween.TWEEN_PROCESS_IDLE
@export var playback_speed : float = 1.0

var _internal_tween : Tween

var _internal_tween_properties : Dictionary = {}

func is_active() -> bool :
	for object in _internal_tween_properties:
		for property in _internal_tween_properties[object]:
			var tween : Tween = _internal_tween_properties[object][property]
			if is_instance_valid(tween) and tween.is_running():
				return true
	return false

func clean_property(object : Object, property : NodePath):
	if _internal_tween_properties.has(object):
		var tween_properties = _internal_tween_properties[object] as Dictionary
		if is_instance_valid(tween_properties) and tween_properties.has(property):
			tween_properties.erase(property)
		if tween_properties.is_empty():
			_internal_tween_properties.erase(object)

func interpolate_property(
	object : Object, 
	property : NodePath, 
	initial_val, 
	final_val, 
	duration : float, 
	trans_type : Tween.TransitionType = Tween.TRANS_LINEAR, 
	ease_type : Tween.EaseType = Tween.EASE_IN_OUT,
	delay : float = 0.0
	) -> bool:
	
	var new_tween = get_tree().create_tween()
	var tweener = new_tween.tween_property(object, property, final_val, duration)\
		.set_delay(delay).set_ease(ease_type).set_trans(trans_type).from(initial_val)
	if is_instance_valid(tweener):
		new_tween.finished.connect(clean_property.bind(object, property))
		var property_tweens = _internal_tween_properties.get(object, {})
		if property_tweens.has(property):
			var existing_tween = property_tweens[property] as Tween
			existing_tween.kill()
		property_tweens[property] = new_tween
		_internal_tween_properties[object] = property_tweens
		return true
	return false
