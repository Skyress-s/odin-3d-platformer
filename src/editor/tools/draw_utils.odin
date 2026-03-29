package tools

import col "../../color"
import spat "../../engine/core/spatial/"
import gent "../../game/game_entities/"
import hm "core:container/handle_map"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:sort"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

@(private)
PLANE_SIZE :: 24

@(private)
HALF_PLANE_SIZE :: PLANE_SIZE / 2

@(private)
BAR_SHORT_SIDE_SIZE :: 6


@(private)
calculate_dirs :: proc(target_location, camera_location: spat.Vector) -> (dirs: spat.Vector) {
	dirs.x = camera_location.x > target_location.x ? 1 : -1
	dirs.y = camera_location.y > target_location.y ? 1 : -1
	dirs.z = camera_location.z > target_location.z ? 1 : -1

	return dirs
}

transform_axis_planes :: proc(
	planes: ^[3]spat.Plane_Bounded,
	transform: spat.Transform,
	local: bool,
) {


	if local {
		mat := linalg.matrix4_from_trs(transform.position, transform.rotation, spat.ONE_VEC3)
		rot_mat := linalg.matrix4_from_quaternion(transform.rotation)

		for &plane in planes {
			spat.mult(mat, &plane.center)
			spat.mult(rot_mat, &plane.forward)
			spat.mult(rot_mat, &plane.normal)
		}
	} else {
		for &plane in planes {
			plane.center += transform.position
		}
	}
}

generate_axis_planes_with_distance_scaling :: proc(
	camera_location: spat.Vector,
	tool_location: spat.Vector,
) -> (
	planes_bounded: [3]spat.Plane_Bounded,
) {
	distance := linalg.distance(camera_location, tool_location)
	axis_planes := generate_axis_planes(camera_location)
	for &plane in axis_planes {
		plane.lenghts *= distance * 0.1 // TODO: Not finshed
	}

	return axis_planes

}

generate_axis_planes :: proc(
	camera_location: spat.Vector,
) -> (
	planes_bounded: [3]spat.Plane_Bounded,
) {
	tooltip_location := spat.ZERO_VEC3
	// dirs: spat.Vector = calculate_dirs(tooltip_location, camera_location)
	dirs: spat.Vector = spat.ONE_VEC3
	dirs *= HALF_PLANE_SIZE * 1.5
	// dirs *= 3

	planes_bounded.x.center = {
		tooltip_location.x,
		tooltip_location.y + dirs.y,
		tooltip_location.z + dirs.z,
	}
	planes_bounded.y.center = {
		tooltip_location.x + dirs.x,
		tooltip_location.y,
		tooltip_location.z + dirs.z,
	}
	planes_bounded.z.center = {
		tooltip_location.x + dirs.x,
		tooltip_location.y + dirs.y,
		tooltip_location.z,
	}

	planes_bounded.x.normal = {1, 0, 0}
	planes_bounded.y.normal = {0, 1, 0}
	planes_bounded.z.normal = {0, 0, 1}

	planes_bounded.x.forward = {0, 1, 0}
	planes_bounded.y.forward = {0, 0, 1}
	planes_bounded.z.forward = {1, 0, 0}

	planes_bounded.x.lenghts = spat.Vector2{PLANE_SIZE, PLANE_SIZE}
	planes_bounded.y.lenghts = spat.Vector2{PLANE_SIZE, PLANE_SIZE}
	planes_bounded.z.lenghts = spat.Vector2{PLANE_SIZE, PLANE_SIZE}

	return planes_bounded
}

Interacted_Plane :: enum {
	None,
	X,
	Y,
	Z,
}

Interacted_Bar :: enum {
	None,
	X,
	Y,
	Z,
}

interacted_bar_to_axis_vector :: proc(interacted_bar: Interacted_Bar) -> spat.Vector {
	switch interacted_bar {
	case .X:
		return {1, 0, 0}
	case .Y:
		return {0, 1, 0}
	case .Z:
		return {0, 0, 1}
	case .None:
	}


	unreachable()
}

get_normal_from_interacted_plane :: proc(interacted_plane: Interacted_Plane) -> spat.Vector {
	switch interacted_plane {
	case .None:
		return spat.ZERO_VEC3
	case .X:
		return spat.Vector{0, 1, 0}
	case .Y:
		return spat.Vector{0, 0, 1}
	case .Z:
		return spat.Vector{1, 0, 0}
	}

	unreachable()
}


ray_axis_planes_intersect :: proc(
	ray: spat.Ray,
	planes_bounded: ^[3]spat.Plane_Bounded,
) -> (
	interacter_plane: Interacted_Plane,
	hit_location, plane_normal: spat.Vector,
) {

	Hit_Data :: struct {
		interacted_plane: Interacted_Plane,
		location:         spat.Vector,
		hit:              bool,
	}

	shortest_dist: f32 = max(f32)
	int_plane: Interacted_Plane
	s_norm: spat.Vector
	s_loc: spat.Vector


	hit, loc, norm := spat.intersect_plane_bounded(ray, &planes_bounded.x)
	// if hit != .None do return .X, loc, norm
	if hit {
		shortest_dist = linalg.distance(ray.origin, loc)
		int_plane = .X
		s_norm = norm
		s_loc = loc
	}

	hit, loc, norm = spat.intersect_plane_bounded(ray, &planes_bounded.y)

	if hit {
		new_dist := linalg.distance(ray.origin, loc)

		if new_dist < shortest_dist {
			shortest_dist = new_dist
			int_plane = .Y
			s_norm = norm
			s_loc = loc
		}
	}

	hit, loc, norm = spat.intersect_plane_bounded(ray, &planes_bounded.z)

	if hit {
		new_dist := linalg.distance(ray.origin, loc)

		if new_dist < shortest_dist {
			shortest_dist = new_dist
			int_plane = .Z
			s_norm = norm
			s_loc = loc
		}
	}


	return int_plane, s_loc, s_norm
}

scale_bars_to_tris :: proc(
	scale_bars: ^[3]spat.Box_Better,
) -> (
	tris: [3][12]spat.Collision_Triangle,
) {

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

	translate_planes :: proc(planes: ^[6]spat.Plane_Bounded, offset: spat.Vector) {
		for &plane in planes {
			plane.center += offset
		}
	}

	translate_planes(&local_planes_x, scale_bars.x.position)
	translate_planes(&local_planes_y, scale_bars.y.position)
	translate_planes(&local_planes_z, scale_bars.z.position)

	//rl.DrawPlane(local_planes_x[0].center, local_planes_x[0].lenghts, rl.MAGENTA)

	tris_x := spat.make_collision_tris_from_planes_bounded(&local_planes_x)
	tris_y := spat.make_collision_tris_from_planes_bounded(&local_planes_y)
	tris_z := spat.make_collision_tris_from_planes_bounded(&local_planes_z)


	tris[0] = tris_x
	tris[1] = tris_y
	tris[2] = tris_z

	return tris
}

ray_axis_bars_intersect :: proc(
	ray: spat.Ray,
	scale_bars: ^[3]spat.Box_Better,
) -> (
	interacter_bar: spat.Axis,
	hit_location: spat.Vector,
) {

	tris := scale_bars_to_tris(scale_bars)

	ray_intersect_6 :: proc(
		ray: spat.Ray,
		tris: ^[12]spat.Collision_Triangle,
	) -> (
		hit: bool,
		location: spat.Vector,
	) {
		dist := max(f32)
		loc := spat.ZERO_VEC3
		for &t in tris {
			hit, new_location := spat.ray_triangle_intersect(ray, t)
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

	Hit_Data :: struct {
		interacted_bar: spat.Axis,
		location:       spat.Vector,
		distance:       f32,
		hit:            bool,
	}

	hits: [3]Hit_Data

	hit, location := ray_intersect_6(ray, &tris.x)
	if hit {
		hits[0].interacted_bar = spat.Axis.X
		hits[0].location = location
		hits[0].distance = linalg.length(location - ray.origin)
		hits[0].hit = true
		// return spat.Axis.X, location
	}

	hit, location = ray_intersect_6(ray, &tris.y)
	if hit {
		hits[1].interacted_bar = spat.Axis.Y
		hits[1].location = location
		hits[1].distance = linalg.length(location - ray.origin)
		hits[1].hit = true
		// return spat.Axis.Y, location
	}

	hit, location = ray_intersect_6(ray, &tris.z)
	if hit {
		hits[2].interacted_bar = spat.Axis.Z
		hits[2].location = location
		hits[2].distance = linalg.length(location - ray.origin)
		hits[2].hit = true
		// return spat.Axis.Z, location
	}


	// trying to solve this by sorting.
	lam := proc(lhs, rhs: Hit_Data) -> int {
		if lhs.hit != rhs.hit do return int(rhs.hit) - int(lhs.hit)

		if lhs.distance > rhs.distance do return 1
		if lhs.distance < rhs.distance do return -1
		return 0

	}

	slice := hits[:]
	sort.quick_sort_proc(slice, lam)

	if hits[0].hit do return hits[0].interacted_bar, hits[0].location

	return spat.Axis.None, spat.ZERO_VEC3
}

draw_tooltip :: proc(
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	tool: ^Transform_Tool_Data,
	player_pos: spat.Vector,
) {
	found_object: ^gent.Entity = hm.get(collision_object_map, tool.target_object_id)
	if found_object != nil {
		ent_transform := found_object.transform_component.transform

		switch &active_tool in tool.active_tool {
		case Position_Tool:
			axis_planes := generate_axis_planes(player_pos)
			transform_axis_planes(&axis_planes, ent_transform, tooltip_local)
			draw_position_tooltip_new(axis_planes)

			axis_boxes := generate_axis_bars()
			transform_axis_bars(&axis_boxes, ent_transform, tooltip_local)
			draw_scale_boxes(axis_boxes)
		case Rotation_Tool:
			axis_planes := generate_axis_planes(player_pos)
			transform_axis_planes(&axis_planes, ent_transform, tooltip_local)
			draw_position_tooltip_new(axis_planes)
		case Scale_Tool:
			scale_bars := generate_axis_bars()
			transform_axis_bars(&scale_bars, ent_transform, true) // Only makes sense to use local with scaling bars.
			draw_scale_boxes(scale_bars)
		}
	}

}


draw_position_tooltip_new :: proc(planes_bounded: [3]spat.Plane_Bounded) {
	planes_bounded := planes_bounded
	planeXZ := planes_bounded.x
	planeXY := planes_bounded.y
	planeZY := planes_bounded.z

	get_transform_from_plane :: proc(plane: spat.Plane_Bounded) -> spat.Transform {
		pos := plane.center


		quat_from_forward_up :: proc(forward, up: linalg.Vector3f32) -> linalg.Quaternionf32 {
			// Normalize input vectors
			f := linalg.normalize(forward)
			r := linalg.normalize(linalg.cross(up, f)) // right = up × forward
			u := linalg.cross(f, r) // recompute up to ensure orthogonality

			// Build rotation matrix (column-major)
			m := linalg.Matrix3f32{r.x, u.x, f.x, r.y, u.y, f.y, r.z, u.z, f.z}

			// Convert to quaternion
			return linalg.quaternion_from_matrix3(m)
		}

		rot := quat_from_forward_up(plane.forward, plane.normal)

		rot = linalg.normalize(rot)
		scale := spat.ONE_VEC3
		return spat.Transform{pos, rot, scale}
	}

	draw_plane :: proc(plane: spat.Plane_Bounded, color: col.Color) {
		plane := plane

		trans := get_transform_from_plane(plane)
		{
			rlgl.PushMatrix()
			defer rlgl.PopMatrix()
			mat := spat.matrix_from_transform(trans)

			matrix_data := transmute([16]f32)mat
			rlgl.MultMatrixf(auto_cast &matrix_data)

			rl.DrawPlane(spat.ZERO_VEC3, plane.lenghts, color)
		}

		plane.normal = -plane.normal
		trans = get_transform_from_plane(plane)
		{
			rlgl.PushMatrix()
			defer rlgl.PopMatrix()
			mat := spat.matrix_from_transform(trans)

			matrix_data := transmute([16]f32)mat
			rlgl.MultMatrixf(auto_cast &matrix_data)

			rl.DrawPlane(spat.ZERO_VEC3, plane.lenghts, color)
		}


		// rl.DrawLine3D(plane.center, plane.center + plane.forward * 100, col.RED)
		// rl.DrawLine3D(plane.center, plane.center + plane.normal * 100, col.SKYBLUE)
	}

	draw_plane(planeXZ, col.RED)
	draw_plane(planeXY, col.GREEN)
	draw_plane(planeZY, col.BLUE)

}


@(private)
calculate_rotation_planes :: proc(
	tooltip_location, camera_location: spat.Vector,
) -> [3]spat.Plane_Bounded {
	return generate_axis_planes(camera_location)
}


// draw_rotation_tooltip :: proc(){
//
// }

transform_axis_bars :: proc(boxes: ^[3]spat.Box_Better, transform: spat.Transform, local: bool) {

	if local {
		mat := linalg.matrix4_from_trs(transform.position, transform.rotation, spat.ONE_VEC3)
		for &box in boxes {
			spat.mult(mat, &box.position)
			box.rotation = transform.rotation
			// box.size *= transform.scale
		}
	} else {
		for &box in boxes {
			box.position += transform.position
		}
	}
}

generate_axis_bars :: proc() -> (boxes: [3]spat.Box_Better) { 	// Dima would like this name
	// dirs := calculate_dirs(target_transform.position, camera_location)
	dirs := spat.ONE_VEC3
	dirs *= HALF_PLANE_SIZE * 1.2

	// target_location := target_transform.position
	target_location := spat.Vector{0, 0, 0}

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

determine_what_axis_bar_hit :: proc(index: u8) {
}

draw_scale_boxes :: proc(boxes: [3]spat.Box_Better) {
	boxes := boxes
	box_x := boxes.x
	box_y := boxes.y
	box_z := boxes.z

	draw_box :: proc(box: ^spat.Box_Better, color: col.Color) {
		rlgl.PushMatrix()
		defer rlgl.PopMatrix()

		mat := spat.matrix_from_transform(spat.Transform{box.position, box.rotation, box.size})

		matrix_data := transmute([16]f32)mat
		rlgl.MultMatrixf(auto_cast &matrix_data)
		// rlgl.Translatef(box.position.x, box.position.y, box.position.z)
		rl.DrawCube(spat.ZERO_VEC3, 1, 1, 1, color)
	}

	draw_box(&boxes.x, col.RED)
	draw_box(&boxes.y, col.GREEN)
	draw_box(&boxes.z, col.BLUE)
}
