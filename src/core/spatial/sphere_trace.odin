package Spatial

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:testing"

Sphere_Trace :: distinct struct {
	using ray: Ray,
	radius:    f32,
}


calculate_rays_by_sphere_trace :: proc(
	sphere_trace: ^Sphere_Trace,
) -> (
	rays: [dynamic]Ray, // cells: map[Hash_Key]bool,
) {

	ray := &sphere_trace.ray
	ray_length := ray_length(ray)
	forward := ray_direction(ray^)

	up := linalg.normalize0(linalg.cross(forward, UP_VEC3))

	if up == ZERO_VEC3 {
		up = FORWARD_VEC3
	}


	right := linalg.normalize(linalg.cross(forward, up))

	start_location_center :=
		ray.origin -
		forward * sphere_trace.radius -
		sphere_trace.radius * up -
		sphere_trace.radius * right
	end_location_center :=
		ray.end +
		forward * sphere_trace.radius -
		sphere_trace.radius * up -
		sphere_trace.radius * right

	num_rays_per_side := i32(math.ceil(sphere_trace.radius * 2 / HASH_CELL_SIZE_METERS)) + 1

	for i: i32 = 0; i < num_rays_per_side * num_rays_per_side; i += 1 {
		x := f32((i % num_rays_per_side)) * (sphere_trace.radius * 2 / f32(num_rays_per_side - 1))
		y := f32(i / num_rays_per_side) * (sphere_trace.radius * 2 / f32(num_rays_per_side - 1))


		offset := right * f32(x) + up * f32(y)

		newt_gun_ray := Ray {
			origin = start_location_center + offset,
			end    = end_location_center + offset,
		}

		append_elem(&rays, newt_gun_ray)

		// cells_hit_by_ray := calculate_hashes_by(newt_gun_ray)
		// for key, _ in &cells_hit_by_ray{
		// 	cells[key] = true
		// }
	}

	return rays
}


sphere_trace_triangle_intersect :: proc(
	sphere_trace: ^Sphere_Trace,
	tri: ^Collision_Triangle,
	reaction: ^Vector,
) -> (
	bool,
	Vector,
) {
	if ray_length(&sphere_trace.ray) == 0 do return false, ZERO_VEC3

	i: i32
	nvelo := ray_direction(sphere_trace.ray)

	tri_normal := collision_triangle_normal(tri)

	if linalg.dot(tri_normal, nvelo) > -0.001 do return false, ZERO_VEC3

	minDist := max(f32)
	col: i32 = -1
	_distTravel: f32 = max(f32)

	plane := plane_comp_from_point_and_normal(tri.points.x, tri_normal)
	// pass1: sphere VS plane
	h: f32 = distance_to_plane_comp(&plane, &sphere_trace.origin)
	if h < -sphere_trace.radius do return false, ZERO_VEC3

	if h > sphere_trace.radius {
		h -= sphere_trace.radius
		dot := linalg.dot(tri_normal, nvelo)
		if (dot != 0) {
			t: f32 = -h / dot
			onPlane: Vector = sphere_trace.ray.origin + nvelo * t
			if (collision_triangle_point_inside(tri, &onPlane)) {
				if (t < _distTravel) {
					_distTravel = t
					if reaction != nil {
						reaction^ = tri_normal
					}
					col = 0
				}
			}
		}
	}

	// pass2: sphere VS triangle vertices
	for i: i32 = 0; i < 3; i += 1 {

		seg_pt0: Vector = tri.points[i]
		seg_pt1: Vector = seg_pt0 - nvelo
		v: Vector = seg_pt1 - seg_pt0

		inter1, inter2 := max(f32), max(f32)
		nbInter: i32 = 0
		res: bool = intersection_sphere_line(
			Sphere{sphere_trace.radius, sphere_trace.ray.origin},
			seg_pt0,
			seg_pt1,
			&nbInter,
			&inter1,
			&inter2,
		)
		if res == false do continue

		t: f32 = inter1
		if inter2 < t do t = inter2

		if t < 0 do continue

		if t < _distTravel {
			_distTravel = t
			onSphere: Vector = seg_pt0 + v * t
			if reaction != nil {
				reaction^ = sphere_trace.ray.origin - onSphere
			}
			col = 1
		}
	}

	// pass3: sphere VS triangle edges
	for i = 0; i < 3; i += 1 {
		edge0: Vector = tri.points[i]
		j: i32 = i + 1
		if j == 3 do j = 0
		edge1: Vector = tri.points[j]

		plane: Plane_Compressed = plane_comp_from_tri({edge0, edge1, edge1 - nvelo})
		d: f32 = distance_to_plane_comp(&plane, &sphere_trace.ray.origin)

		if d > sphere_trace.radius || d < -sphere_trace.radius do continue

		srr: f32 = sphere_trace.radius * sphere_trace.radius
		r: f32 = math.sqrt(srr - d * d)

		pt0: Vector = plane_comp_project(&plane, &sphere_trace.ray.origin) // center of the sphere slice (a circle)

		onLine: Vector
		h: f32 = distance_point_to_line_v2(pt0, edge0, edge1, &onLine)
		v: Vector = onLine - pt0
		v = linalg.normalize(v)
		pt1: Vector = v * r + pt0 // point on the sphere that will maybe collide with the edge

		// int a0 = 0, a1 = 1;
		a0, a1 := 0, 1
		pl_x: f32 = math.abs(plane.x)
		pl_y: f32 = math.abs(plane.y)
		pl_z: f32 = math.abs(plane.z)
		if (pl_x > pl_y && pl_x > pl_z) {
			a0 = 1
			a1 = 2
		} else {
			if (pl_y > pl_z) {
				a0 = 0
				a1 = 2
			}
		}

		vv: Vector = pt1 + nvelo

		t: f32

		res: bool = intersection_line_line(
			Vector2{pt1[a0], pt1[a1]},
			Vector2{vv[a0], vv[a1]},
			Vector2{edge0[a0], edge0[a1]},
			Vector2{edge1[a0], edge1[a1]},
			&t,
		)
		if (!res || t < 0) do continue

		inter: Vector = pt1 + nvelo * t

		r1: Vector = edge0 - inter
		r2: Vector = edge1 - inter
		if (linalg.dot(r1, r2) > 0) do continue

		if (t > _distTravel) do continue

		_distTravel = t
		if (reaction != nil) {
			reaction^ = sphere_trace.ray.origin - pt1
		}
		col = 2
	}

	if reaction != nil && col != -1 do reaction^ = linalg.normalize(reaction^)

	if _distTravel > ray_length(&sphere_trace.ray) do return false, ZERO_VEC3

	return col != -1, sphere_trace.origin + nvelo * _distTravel
	// return col == -1 ? false : true, .EOP
}


distance_point_to_line :: proc(p_on_line, v, point: ^Vector) -> f32 {
	to_point := (point^ - p_on_line^)
	c := linalg.cross(to_point, v^)
	return linalg.length(c) / linalg.length(v^)
}
