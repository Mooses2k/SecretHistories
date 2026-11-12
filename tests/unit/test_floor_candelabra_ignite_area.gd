# Tests for the floor candelabra Ignite (interact) area (melee2 lane). The
# candle-take work enlarged the area to a radius 1.2 / height 1.6 column
# centered high on the stand, which put the GRAB prompt and the stand drag
# target up to a meter outside the visible candelabra (owner playtest defect).
# The area must be a snug enclosure of the stand body: big enough to win the
# interaction ray race against the stand's own collision from any side, small
# enough that the prompt only sits on the candelabra. Pins, derived from the
# baked mesh extents (body space x/z within 0.223, y -0.958..0.748) plus the
# flame quads above:
# 1. The shape is a cylinder.
# 2. It encloses the stand body and the flame tips.
# 3. It does not extend meaningfully beyond the visible body (no meter-out
#    prompt zone).
# 4. The GRAB indicator override for the candle take stays.
extends GutTest

const STAND_SCENE := preload("res://scenes/objects/large_objects/lighting/floor_candelabra.tscn")


func _stand_area() -> Dictionary:
	var stand : Node = STAND_SCENE.instantiate()
	autofree(stand)
	var ignite : Area3D = stand.get_node("Ignite") as Area3D
	var shape_node : CollisionShape3D = ignite.get_node("CollisionShape3D") as CollisionShape3D
	var cylinder := shape_node.shape as CylinderShape3D
	var mesh_node : MeshInstance3D = stand.get_node("MeshInstance3D") as MeshInstance3D
	var aabb := mesh_node.mesh.get_aabb()
	var from := mesh_node.transform * aabb.position
	var to := mesh_node.transform * (aabb.position + aabb.size)
	var lo := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z))
	var hi := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z))
	var center_y : float = shape_node.transform.origin.y + ignite.transform.origin.y
	return {
		"cylinder": cylinder,
		"center_y": center_y,
		"mesh_lo": lo,
		"mesh_hi": hi,
		"indicator": ignite.indicator_override,
	}


func test_ignite_shape_is_a_cylinder():
	var area := _stand_area()
	assert_not_null(area.cylinder, "the Ignite collision is a CylinderShape3D")


func test_ignite_area_encloses_the_stand_body_and_flames():
	var area := _stand_area()
	var cylinder : CylinderShape3D = area.cylinder
	var top : float = area.center_y + cylinder.height / 2.0
	var bottom : float = area.center_y - cylinder.height / 2.0
	assert_true(bottom <= area.mesh_lo.y, "the area starts at or below the stand base (%s vs %s)" % [bottom, area.mesh_lo.y])
	assert_true(top >= area.mesh_hi.y + 0.1, "the area covers the top candles and the flame tips (%s vs %s)" % [top, area.mesh_hi.y])
	assert_true(cylinder.radius >= area.mesh_hi.x, "the area radius encloses the widest visible body point")


func test_ignite_area_sits_on_the_body_not_a_meter_out():
	var area := _stand_area()
	var cylinder : CylinderShape3D = area.cylinder
	assert_true(cylinder.radius <= 0.5, "the area radius hugs the body (got %s, the defect shipped 1.2)" % cylinder.radius)
	assert_true(cylinder.height <= 2.2, "the area height hugs the stand (got %s)" % cylinder.height)


func test_grab_indicator_override_stays_for_the_take():
	var area := _stand_area()
	assert_eq(area.indicator, 1, "the candle take keeps the GRAB indicator override")
