class_name ClamberManager
extends Object


# Having clamber as a seperate class let's any object use the clamber function,
# it just needs a clamber manager.

var _camera : Camera = null
var _world : World = null
var _user : KinematicBody = null


func _init(User : KinematicBody, Current_Camera : Camera, User_World : World):
	_camera = Current_Camera
	_user = User
	_world = User_World


func _get_world():
	return _world


func attempt_clamber(is_crouching:bool, is_jumping:bool) -> Vector3:
	var v = _test_clamber_vent()
	
	# If user has a bulky item, don't allow clambering, TODO: UNTESTED
	if _user.inventory.has_bulky_item():
		print("Trying to clamber with a bulky item - this should not work.")
		return Vector3.ZERO
	
#	if _camera.rotation_degrees.x < 20.0:
#		var v = _test_clamber_vent()
#		if v != Vector3.ZERO:
#			return v
#		v = _test_clamber_ledge()
#		if v != Vector3.ZERO:
#			return v
#	elif _camera.rotation_degrees.x > 20.0:
#		var v = _test_clamber_ledge()
#		if v != Vector3.ZERO:
#			return v
#		v = _test_clamber_vent()
#		if v != Vector3.ZERO:
#			return v
#	return Vector3.ZERO
	
	if v == Vector3.ZERO:
		v = _test_clamber_ledge()
		if v == Vector3.ZERO:
			return Vector3.ZERO
	
	if is_jumping:
		if v.y >= 2.0 and _camera.rotation_degrees.x > 10.0:
			return v
	
	if is_crouching:
		if v.y < 0.8 and _camera.rotation_degrees.x < 5.0:
			return v
		if (v.y < 2.0 and v.y > 0.8) and _camera.rotation_degrees.x > 20.0:
			return v
		return Vector3.ZERO
	
	if is_jumping and v.y < 1.8 and _camera.rotation_degrees.x < 5.0:
		return v
	elif v.y < 1.6 and _camera.rotation_degrees.x < 5.0:
		return v
	elif !is_jumping and (v.y > 1.6 and v.y < 2.0) and _camera.rotation_degrees.x > 20.0:
		return v
	return Vector3.ZERO


func _test_clamber_ledge() -> Vector3:
	var user_forward = -_user.global_transform.basis.z.normalized() * 0.1
	var space = _world.direct_space_state
	var pos = _user.global_transform.origin
	var d1 = pos + Vector3.UP * 2.3 #1.25
	var d2 = d1 + user_forward 
	var d3 = d2 + Vector3.DOWN * 32 #16

	if not space.intersect_ray(pos, d1):
		for i in range(5):
			if not space.intersect_ray(d1, d2 + user_forward * i):
				for j in range(5):
					d2 = d1 + user_forward * (j + 1)
					var r = space.intersect_ray(d2, d3)
					if r and r.collider.is_in_group("CLAMBERABLE"):
						var ground_check = space.intersect_ray(pos, 
								pos + Vector3.DOWN * 2)

						if !ground_check:
							return Vector3.ZERO
						
						if ground_check.collider == r.collider:
							return Vector3.ZERO
				
						var offset = _check_clamber_box(r.position + Vector3.UP * 0.175)
						if offset == -Vector3.ONE:
							return Vector3.ZERO
				
						if r.position.y < pos.y:
							return Vector3.ZERO
					
						return r.position + offset
				
	return Vector3.ZERO


func _test_clamber_vent() -> Vector3:
	var cam_forward = -_camera.global_transform.basis.z.normalized() * 0.1#0.4
	var space = _world.direct_space_state
	var pos = _user.global_transform.origin
	var d1 = _camera.global_transform.origin + cam_forward
	var d2 = d1 + Vector3.DOWN * 6 #6
	
	if not space.intersect_ray(pos, d1, [_user]):
		for i in range(5):
			var r = space.intersect_ray(d1 + cam_forward * i, d2, [_user])
			if r and r.collider.is_in_group("CLAMBERABLE"):
				var ground_check = space.intersect_ray(pos,
						pos + Vector3.DOWN * 2)
			
				if ground_check and ground_check.collider == r.collider:
					return Vector3.ZERO
				
				var offset = _check_clamber_box(r.position + Vector3.UP * 0.175)
				if offset == -Vector3.ONE:
					return Vector3.ZERO
				
				if r.position.y < pos.y:
					return Vector3.ZERO
				
				return r.position + offset
				
	return Vector3.ZERO


# Nudging may need some refining
func _check_clamber_box(pos : Vector3, box_size : float = 0.15) -> Vector3:
	var state = _world.direct_space_state
	var shape = BoxShape.new()
	shape.extents = Vector3.ONE * box_size
	
	var params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = pos
	var result = state.intersect_shape(params)
	
	for i in range(result.size() - 1):
		if result[i].collider == _user:
			result.remove(i)
	
	if result.size() == 0:
		return Vector3.ZERO
		
	if result.size() == 1 and result[0].collider.global_transform.origin.y < pos.y:
		return Vector3.ZERO
	
	if !_check_gap(pos + Vector3.FORWARD * 0.15):
		return -Vector3.ONE

	if !_check_gap(pos + Vector3.BACK * 0.15):
		return -Vector3.ONE
		
	if !_check_gap(pos):
		return -Vector3.ONE
		
	var offset = Vector3.ZERO
	var checkPos = Vector3.ZERO
	
	var dir = -_camera.global_transform.basis.z.normalized()
	dir.y = 0
		
	for i in range(4):
		var j = (i + 1) * 0.4
		checkPos = pos + dir * j
		params.transform.origin = checkPos
		var r = state.intersect_shape(params)
		if r.size() == 0:
			offset = dir * j
			break
	
	if checkPos != Vector3.ZERO:
		if state.intersect_ray(checkPos, checkPos + Vector3.DOWN * 2):
			return offset
	
	return -Vector3.ONE


func _check_gap(pos : Vector3) -> bool:
	var space = _world.direct_space_state
	
	var c = 0
	
	for i in range(4):
		var r = i * 90
		var v = Vector3.UP.rotated(Vector3.FORWARD, deg2rad(r))
		var result = space.intersect_ray(pos, pos + v, [_user])
		if result and (result.position - pos).length() < 0.2:
			c += 1
			
	if c >= 3:
		return false
	
	return true
