package tools

import spat "../../Spatial/"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

@(private)
PLANE_SIZE :: 34

@(private)
HALF_PLANE_SIZE :: PLANE_SIZE / 2

@(private)
BAR_SHORT_SIDE_SIZE :: 12


@(private)
calculate_dirs :: proc(target_location, camera_location: spat.Vector) -> (dirs: spat.Vector) {
	dirs.x = camera_location.x > target_location.x ? 1 : -1
	dirs.y = camera_location.y > target_location.y ? 1 : -1
	dirs.z = camera_location.z > target_location.z ? 1 : -1

	return dirs
}

// Planes are in order XZ, XY, ZY
//@(private)
calculate_drag_planes :: proc(
	tooltip_location, camera_location: spat.Vector,
) -> (
	planes_bounded: [3]spat.Plane_Bounded,
) {

	dirs: spat.Vector = calculate_dirs(tooltip_location, camera_location)
	dirs *= HALF_PLANE_SIZE * 1.2

	planes_bounded.x.center = {
		tooltip_location.x + dirs.x,
		tooltip_location.y,
		tooltip_location.z + dirs.z,
	}
	planes_bounded.y.center = {
		tooltip_location.x + dirs.x,
		tooltip_location.y + dirs.y,
		tooltip_location.z,
	}
	planes_bounded.z.center = {
		tooltip_location.x,
		tooltip_location.y + dirs.y,
		tooltip_location.z + dirs.z,
	}

	planes_bounded.x.normal = {0, 1, 0}
	planes_bounded.y.normal = {0, 0, 1}
	planes_bounded.z.normal = {1, 0, 0}

	planes_bounded.x.forward = {1, 0, 0}
	planes_bounded.y.forward = {1, 0, 0}
	planes_bounded.z.forward = {0, 0, 1}

	planes_bounded.x.lenghts = spat.Vector2{PLANE_SIZE, PLANE_SIZE}
	planes_bounded.y.lenghts = spat.Vector2{PLANE_SIZE, PLANE_SIZE}
	planes_bounded.z.lenghts = spat.Vector2{PLANE_SIZE, PLANE_SIZE}

	return planes_bounded
}

Interacted_Plane :: enum {
	None,
	XZ,
	XY,
	ZY,
}

Interacted_Bar :: enum {
	None,
	X,
	Y,
	Z,
}

get_normal_from_interacted_plane :: proc(interacted_plane: Interacted_Plane) -> spat.Vector {
	switch interacted_plane {
	case .None:
		return spat.ZERO_VEC3
	case .XZ:
		return spat.Vector{0, 1, 0}
	case .XY:
		return spat.Vector{0, 0, 1}
	case .ZY:
		return spat.Vector{1, 0, 0}
	}

	unreachable()
}

ray_transform_tool_planes_intersect :: proc(
	ray: ^spat.Ray,
	planes_bounded: ^[3]spat.Plane_Bounded,
) -> (
	interacter_plane: Interacted_Plane,
	hit_location, plane_normal: spat.Vector,
) {

	make_collision_tris_from_plane_bounded :: proc(
		plane: ^spat.Plane_Bounded,
	) -> (
		tris: [2]spat.Collision_Triangle,
	) {
		x := linalg.normalize(plane.forward)
		y := linalg.normalize(linalg.cross(plane.forward, plane.normal))

		tri1: spat.Collision_Triangle
		tri1.points.x = +x + y
		tri1.points.y = +x - y
		tri1.points.z = -x + y

		tri2: spat.Collision_Triangle
		tri2.points.x = -x - y
		tri2.points.y = +x - y
		tri2.points.z = -x + y

		for &p in &tri1.points {
			p *= plane.lenghts.x / 2
			p += plane.center
		}

		for &p in &tri2.points {
			p *= plane.lenghts.x / 2
			p += plane.center
		}

		tris.x = tri1
		tris.y = tri2
		return tris
	}

	{
		coll_tris := make_collision_tris_from_plane_bounded(&planes_bounded.x)
		hit, loc := spat.ray_triangle_intersect(ray, &coll_tris.x)
		if hit do return Interacted_Plane.XZ, loc, planes_bounded.x.normal

		hit, loc = spat.ray_triangle_intersect(ray, &coll_tris.y)
		if hit do return Interacted_Plane.XZ, loc, planes_bounded.x.normal

	}
	{
		coll_tris := make_collision_tris_from_plane_bounded(&planes_bounded.y)
		hit, loc := spat.ray_triangle_intersect(ray, &coll_tris.x)
		if hit do return Interacted_Plane.XY, loc, planes_bounded.y.normal

		hit, loc = spat.ray_triangle_intersect(ray, &coll_tris.y)
		if hit do return Interacted_Plane.XY, loc, planes_bounded.y.normal

	}
	{
		coll_tris := make_collision_tris_from_plane_bounded(&planes_bounded.z)
		hit, loc := spat.ray_triangle_intersect(ray, &coll_tris.x)
		if hit do return Interacted_Plane.ZY, loc, planes_bounded.z.normal


		hit, loc = spat.ray_triangle_intersect(ray, &coll_tris.y)
		if hit do return Interacted_Plane.ZY, loc, planes_bounded.z.normal

	}


	return Interacted_Plane.None, spat.ZERO_VEC3, spat.ZERO_VEC3
}

// ray_scale_bars_collision :: proc(
// 	ray: ^spat.Ray,
// 	scale_bars: ^[3]spat.Box_Better,
// ) -> (
// 	interacter_bar: Interacted_Bar,
// 	hit_location, plane_normal: spat.Vector,
// ) {
//
//
// }


draw_position_tooltip_new :: proc(planes_bounded: [3]spat.Plane_Bounded) {
	planeXZ := planes_bounded.x
	planeXY := planes_bounded.y
	planeZY := planes_bounded.z

	rlgl.PushMatrix()
	rlgl.Translatef(planeXZ.center.x, planeXZ.center.y, planeXZ.center.z)
	rl.DrawPlane(spat.ZERO_VEC3, planeXZ.lenghts, rl.ColorLerp(rl.RED, rl.BLUE, 0.5))
	rlgl.Rotatef(180, 1, 0, 0)
	rl.DrawPlane(spat.ZERO_VEC3, planeXZ.lenghts, rl.ColorLerp(rl.RED, rl.BLUE, 0.5))
	rlgl.PopMatrix()

	rlgl.PushMatrix()
	rlgl.Translatef(planeXY.center.x, planeXY.center.y, planeXY.center.z)
	rlgl.Rotatef(90, planeXY.forward.x, planeXY.forward.y, planeXY.forward.z)
	rl.DrawPlane(spat.ZERO_VEC3, planeXY.lenghts, rl.ColorLerp(rl.RED, rl.GREEN, 0.5))
	rlgl.Rotatef(180, planeXY.forward.x, planeXY.forward.y, planeXY.forward.z)
	rl.DrawPlane(spat.ZERO_VEC3, planeXY.lenghts, rl.ColorLerp(rl.RED, rl.GREEN, 0.5))
	rlgl.PopMatrix()


	rlgl.PushMatrix()
	rlgl.Translatef(planeZY.center.x, planeZY.center.y, planeZY.center.z)
	rlgl.Rotatef(90, planeZY.forward.x, planeZY.forward.y, planeZY.forward.z)
	rl.DrawPlane(spat.ZERO_VEC3, planeZY.lenghts, rl.ColorLerp(rl.BLUE, rl.GREEN, 0.5))
	rlgl.Rotatef(180, planeZY.forward.x, planeZY.forward.y, planeZY.forward.z)
	rl.DrawPlane(spat.ZERO_VEC3, planeZY.lenghts, rl.ColorLerp(rl.BLUE, rl.GREEN, 0.5))
	rlgl.PopMatrix()
}


@(private)
calculate_rotation_planes :: proc(
	tooltip_location, camera_location: spat.Vector,
) -> [3]spat.Plane_Bounded {
	return calculate_drag_planes(tooltip_location, camera_location)
}


// draw_rotation_tooltip :: proc(){
//
// }


calculate_scale_bars :: proc(
	target_transform: spat.Transform,
	camera_location: spat.Vector,
) -> (
	boxes: [3]spat.Box_Better,
) { 	// Dima would like this name
	dirs := calculate_dirs(target_transform.position, camera_location)
	dirs *= HALF_PLANE_SIZE * 1.2

	target_location := target_transform.position

	boxes.x.position = {target_location.x + dirs.x, target_location.y, target_location.z}
	boxes.y.position = {target_location.x, target_location.y + dirs.y, target_location.z}
	boxes.z.position = {target_location.x, target_location.y, target_location.z + dirs.z}


	boxes.x.size.x = PLANE_SIZE
	boxes.x.size.y = BAR_SHORT_SIDE_SIZE
	boxes.x.size.z = BAR_SHORT_SIDE_SIZE

	boxes.y.size.x = BAR_SHORT_SIDE_SIZE
	boxes.y.size.y = PLANE_SIZE
	boxes.y.size.z = BAR_SHORT_SIDE_SIZE

	boxes.z.size.x = BAR_SHORT_SIDE_SIZE
	boxes.z.size.y = BAR_SHORT_SIDE_SIZE
	boxes.z.size.z = PLANE_SIZE

	return boxes
}

draw_scale_boxes :: proc(boxes: [3]spat.Box_Better) {

	box_x := boxes.x
	box_y := boxes.y
	box_z := boxes.z

	draw_box :: proc(box: ^spat.Box_Better) {
		rlgl.PushMatrix()
		rlgl.Translatef(box.position.x, box.position.y, box.position.z)
		rl.DrawCube(
			spat.ZERO_VEC3,
			box.size.x,
			box.size.y,
			box.size.z,
			rl.ColorLerp(rl.RED, rl.BLUE, 0.5),
		)
		rlgl.PopMatrix()
	}

	draw_box(&box_x)
	draw_box(&box_y)
	draw_box(&box_z)
}
