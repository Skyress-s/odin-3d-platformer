package tools

import spat "../../Spatial/"
import col "../../color"
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
generate_axis_planes :: proc(
	tooltip_location, camera_location: spat.Vector,
) -> (
	planes_bounded: [3]spat.Plane_Bounded,
) {

	dirs: spat.Vector = calculate_dirs(tooltip_location, camera_location)
	dirs *= HALF_PLANE_SIZE * 1.5

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

interacted_bar_to_axis_vector :: proc(interacted_bar: Interacted_Bar) -> spat.Vector{
	switch interacted_bar{
	case .X:
		return {1,0,0}
	case .Y:
		return {0,1,0}
	case .Z:
		return {0,0,1}
	case .None:
	}


	unreachable()
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


make_collision_tris_from_plane_bounded :: proc(
	plane: ^spat.Plane_Bounded,
) -> (
	tris: [2]spat.Collision_Triangle,
) {
	x := linalg.normalize(plane.forward)
	y := linalg.normalize(linalg.cross(plane.forward, plane.normal))

	tri1: spat.Collision_Triangle
	tri1.points.x = +x * plane.lenghts.x/ 2 + y * plane.lenghts.y/ 2
	tri1.points.y = +x* plane.lenghts.x/ 2 - y* plane.lenghts.y/ 2
	tri1.points.z = -x* plane.lenghts.x/ 2 + y* plane.lenghts.y/ 2

	tri2: spat.Collision_Triangle
	tri2.points.z = -x* plane.lenghts.x/ 2 - y* plane.lenghts.y/ 2
	tri2.points.y = +x* plane.lenghts.x/ 2 - y* plane.lenghts.y/ 2
	tri2.points.x = -x* plane.lenghts.x / 2 + y* plane.lenghts.y/ 2

	for &p in &tri1.points {
		// p = p + x * plane.lenghts.x / 2
		// p = p + y * plane.lenghts.y / 2
		//p *= plane.lenghts.x / 2
		p += plane.center
	}

	for &p in &tri2.points {
		// p = p + x * plane.lenghts.x / 2
		// p = p + y * plane.lenghts.y / 2
		//p *= plane.lenghts.x / 2
		p += plane.center
	}

	tris.x = tri1
	tris.y = tri2
	return tris
}

make_collision_tris_from_planes_bounded :: proc(
	planes: ^[6]spat.Plane_Bounded,
) -> (
	tris: [12]spat.Collision_Triangle,
) {
	i := 0
	for &plane in planes {
		new_tris := make_collision_tris_from_plane_bounded(&plane)
		tris[i]=  new_tris[0]
		i += 1
		tris[i]=  new_tris[1]
		i += 1
	}

	return tris

}

ray_axis_planes_intersect :: proc(
	ray: ^spat.Ray,
	planes_bounded: ^[3]spat.Plane_Bounded,
) -> (
	interacter_plane: Interacted_Plane,
	hit_location, plane_normal: spat.Vector,
) {

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

scale_bars_to_tris :: proc(scale_bars: ^[3]spat.Box_Better) -> (tris: [3][12]spat.Collision_Triangle){

	make_planes_local :: proc(box: spat.Box_Better) -> (planes: [6]spat.Plane_Bounded) {
		//planes[0].center = box.position + box.size.z / 2
		// TOP
		planes[0].center.y = box.size.y / 2
		planes[0].normal = {0, 1, 0}
		planes[0].forward = {1, 0, 0}
		planes[0].lenghts = {box.size.x, box.size.z}

		// BOTTOM 
		planes[1].center.y = -box.size.y / 2
		planes[1].normal = {0, -1, 0}
		planes[1].forward = {1, 0, 0}
		planes[1].lenghts = {box.size.x, box.size.z}

		// FRONT
		planes[2].center.x = box.size.x / 2
		planes[2].normal = {1, 0, 0}
		planes[2].forward = {0, 1, 0}
		planes[2].lenghts = {box.size.y, box.size.z}

		// BACK
		planes[3].center.x = -box.size.x / 2
		planes[3].normal = {-1, 0, 0}
		planes[3].forward = {0, 1, 0}
		planes[3].lenghts = {box.size.y, box.size.z}

		// RIGHT
		planes[4].center.z = box.size.z / 2
		planes[4].normal = {0, 0, 1}
		planes[4].forward = {0, 1, 0}
		planes[4].lenghts = {box.size.y, box.size.x}

		// LEFT
		planes[5].center.z = -box.size.z / 2
		planes[5].normal = {0, 0, -1}
		planes[5].forward = {0, 1, 0}
		planes[5].lenghts = {box.size.y, box.size.x}

		return planes
	}

	local_planes_x := make_planes_local(scale_bars.x)
	local_planes_y := make_planes_local(scale_bars.y)
	local_planes_z := make_planes_local(scale_bars.z)

	translate_planes :: proc(planes: ^[6]spat.Plane_Bounded, offset: spat.Vector){
		for &plane in planes {
			plane.center += offset
		}
	}

	translate_planes(&local_planes_x, scale_bars.x.position)
	translate_planes(&local_planes_y, scale_bars.y.position)
	translate_planes(&local_planes_z, scale_bars.z.position)

	//rl.DrawPlane(local_planes_x[0].center, local_planes_x[0].lenghts, rl.MAGENTA)

	tris_x := make_collision_tris_from_planes_bounded(&local_planes_x)
	tris_y := make_collision_tris_from_planes_bounded(&local_planes_y)
	tris_z := make_collision_tris_from_planes_bounded(&local_planes_z)


	tris[0] = tris_x
	tris[1] = tris_y
	tris[2] = tris_z

	return tris
}

ray_axis_bars_intersect :: proc(
	ray: ^spat.Ray,
	scale_bars: ^[3]spat.Box_Better,
) -> (
	interacter_bar: spat.Axis,
	hit_location: spat.Vector,
) {

	tris := scale_bars_to_tris(scale_bars)

	ray_intersect_6 :: proc(
		ray: ^spat.Ray,
		tris: ^[12]spat.Collision_Triangle,
	) -> (
		hit: bool,
		location: spat.Vector,
	) {
		dist := max(f32)
		loc := spat.ZERO_VEC3
		for &t in tris {
			hit, new_location := spat.ray_triangle_intersect(ray, &t)
			new_dist := linalg.distance(new_location, ray.origin)
			if hit && (new_dist < dist) {
				dist = new_dist
				loc = new_location
			}
		}

		if dist == max(f32) {
			return false, spat.ZERO_VEC3
		}

		return true, loc
	}
	hit, location := ray_intersect_6(ray, &tris.x)
	if hit {
		return spat.Axis.X, location, 
	}

	hit, location = ray_intersect_6(ray, &tris.y)
	if hit {
		return spat.Axis.Y, location, 
	}

	hit, location = ray_intersect_6(ray, &tris.z)
	if hit {
		return spat.Axis.Z, location, 
	}

	return spat.Axis.None, spat.ZERO_VEC3
}


draw_position_tooltip_new :: proc(planes_bounded: [3]spat.Plane_Bounded) {
	planes_bounded := planes_bounded
	for &p in planes_bounded{
		// p.normal = spat.mult()

	}
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
	return generate_axis_planes(tooltip_location, camera_location)
}


// draw_rotation_tooltip :: proc(){
//
// }


generate_axis_bars :: proc(
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

determine_what_axis_bar_hit :: proc(index: u8){
}

draw_scale_boxes :: proc(boxes: [3]spat.Box_Better) {

	box_x := boxes.x
	box_y := boxes.y
	box_z := boxes.z

	draw_box :: proc(box: ^spat.Box_Better, color: col.Color) {
		rlgl.PushMatrix()
		rlgl.Translatef(box.position.x, box.position.y, box.position.z)
		rl.DrawCube(
			spat.ZERO_VEC3,
			box.size.x,
			box.size.y,
			box.size.z,
			color
		)
		rlgl.PopMatrix()
	}

	draw_box(&box_x, col.RED)
	draw_box(&box_y, col.GREEN)
	draw_box(&box_z, col.BLUE)
}
