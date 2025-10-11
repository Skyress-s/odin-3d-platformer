package Spatial

import hms "../handle_map/handle_map_static"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:testing"

Sphere_Trace :: distinct struct {
	using ray:    Ray,
	radius: f32,
}

calculate_hashes_by_sphere :: proc(
	radius: f32,
	location: ^Vector,
) -> (
	hash_keys: map[Hash_Key]bool,
) {
	assert(radius >= 0)
	rad := radius
	rad_bigger := rad * 1.3 // 30% percent bigger for now
	radius_vector := Vector{rad, rad, rad}
	bound := Bound {
		min = location^ - radius_vector,
		max = location^ + radius_vector,
	}

	return calculate_overlapping_cells(bound)

}

// TODO create testing
@(test)
test_calculate_hashes_by_sphere :: proc(t: ^testing.T) {
	zero_vec := ZERO_VEC3

	hash_keys: map[Hash_Key]bool = calculate_hashes_by_sphere(5, &zero_vec)
	defer delete(hash_keys)

	some_arr: [dynamic]i32 = make([dynamic]i32)
	defer delete(some_arr)
	append_elem(&some_arr, 757)

	// some_arr2 :[dynamic]i32
	// defer delete(some_arr2)

	testing.expect(t, 1 == 1)
}

calculate_hashes_by_sphere_trace :: proc(
	sphere_trace: ^Sphere_Trace,
) -> (
	cells: map[Hash_Key]bool,
) {
	rays := calculate_rays_by_sphere_trace(sphere_trace)
	defer delete(rays)

	hashes := calculate_hashes_by_rays(&rays)
	return hashes

	// // To start out with, we use a sphere that is 30 % bigger that the original
	// trace_length := ray_length(&sphere_trace.ray)
	// trace_direction := ray_direction(sphere_trace.ray)
	// rad := sphere_trace.radius
	// rad_bigger := rad * 1.3 // 30% percent bigger for now
	//
	//
	// walk_distance := math.sqrt(rad_bigger * rad_bigger - rad * rad) // Application of Pythagoras
	//
	// current_dist: f32 = 0.0
	//
	// for current_dist < trace_length {
	// 	current_location := sphere_trace.ray.origin + trace_direction * current_dist
	// 	new_cells := calculate_hashes_by_sphere(rad, &current_location)
	// 	defer delete(new_cells)
	//
	// 	for cell in &new_cells {
	// 		cells[cell] = true
	// 	}
	//
	// 	current_dist += walk_distance
	// }
	//
	// return cells
}

distance_point_to_line :: proc(p_on_line, v, point: ^Vector) -> f32 {
	to_point := (point^ - p_on_line^)
	c := linalg.cross(to_point, v^)
	return linalg.length(c) / linalg.length(v^)
}

sphere_trace_spatial_hash_grid :: proc(
	sphere_trace: ^Sphere_Trace,
	shg: ^Spatial_Hash_Grid,
	com: ^Collision_Object_Handle_Map,
) -> (
	hit: bool,
	id: Collision_Object_Id,
	location: Vector,
) {
	rays := calculate_rays_by_sphere_trace(sphere_trace)
	defer delete(rays)

	hashes := calculate_hashes_by_rays(&rays)
	defer delete(hashes)

	for hash_key in &hashes {
		object_ids, ok := shg[hash_key]
		if ok {
			for object_id in &object_ids.objects_ids {
				object := hms.get(com, object_id)
				for &tri in &object.tris {


				}
			}
		}
	}

	return
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

Return_Reason :: enum
{ Paralell, Two, EOP  }

sphere_trace_triangle_intersect :: proc(
	sphere_trace: ^Sphere_Trace,
	tri: ^Collision_Triangle,
	reaction: ^Vector,
) -> (i32, Return_Reason) {
	i: i32
	nvelo := ray_direction(sphere_trace.ray)

	tri_normal := collision_triangle_normal(tri)

	if linalg.dot(tri_normal, nvelo) > -0.001 do return -1, .Paralell

	minDist := max(f32)
	col: i32 = -1
	_distTravel: f32 = max(f32)


	plane:  = plane_comp_from_point_and_normal(tri.points.x, tri_normal)
	// pass1: sphere VS plane
	h: f32 = distance_to_plane_comp(&plane, &sphere_trace.origin)
	if h < -sphere_trace.radius do return -1, .Two

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
		fmt.println("distance_to_plane: ", d)

		if d > sphere_trace.radius || d < -sphere_trace.radius do continue

		srr: f32 = sphere_trace.radius * sphere_trace.radius
		r: f32 = math.sqrt(srr - d*d)

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

	return col, .EOP
	// return col == -1 ? false : true, .EOP
}


calculate_hashes_by_rays :: proc(rays: ^[dynamic]Ray) -> (hashes: map[Hash_Key]bool) {
	for &ray in rays {
		new_hashes := calculate_hashes_by(ray)
		defer delete(new_hashes)

		for hash in &new_hashes {
			hashes[hash] = true
		}
	}

	return hashes
}


sphere_trace_triangle :: proc(
    sphere_start: Vector,
    sphere_end: Vector,
    radius: f32,
    tri_a: Vector,
    tri_b: Vector,
    tri_c: Vector,
    t_out: ^f32,         // Optional: time of impact (0..1)
    hit_point: ^Vector   // Optional: point of contact
) -> bool {
    dir := sphere_end - sphere_start
    length := linalg.length(dir)

    if length < 1e-6 {
        return false // Not moving
    }

    norm_dir := linalg.normalize(dir)

    // Triangle edges and normal
    edge1 := tri_b - tri_a
    edge2 := tri_c - tri_a
    tri_normal := linalg.normalize(linalg.cross(edge1, edge2))

    // Plane equation: dot(N, X) + d = 0
    plane_d := -linalg.dot(tri_normal, tri_a)
    dist_to_plane := linalg.dot(tri_normal, sphere_start) + plane_d

    // Adjust distance by sphere radius
    expanded_dist := dist_to_plane - radius
    denom := linalg.dot(tri_normal, norm_dir)

    if math.abs(denom) < 1e-6 {
        return false // Ray is parallel to triangle
    }

    t := -expanded_dist / denom
    if t < 0.0 || t > 1.0 {
        return false // Not in movement range
    }

    contact_point := sphere_start + norm_dir * (t * length)

    // Point-in-triangle test (barycentric coordinates)
    v0 := edge1
    v1 := edge2
    v2 := contact_point - tri_a

    d00 := linalg.dot(v0, v0)
    d01 := linalg.dot(v0, v1)
    d11 := linalg.dot(v1, v1)
    d20 := linalg.dot(v2, v0)
    d21 := linalg.dot(v2, v1)

    denom_bary := d00 * d11 - d01 * d01
    if math.abs(denom_bary) < 1e-6 {
        return false // Degenerate triangle
    }

    v := (d11 * d20 - d01 * d21) / denom_bary
    w := (d00 * d21 - d01 * d20) / denom_bary
    u := 1.0 - v - w

    if u >= 0 && v >= 0 && w >= 0 {
        if t_out != nil do t_out^ = t
        if hit_point != nil do hit_point^ = contact_point
        return true
    }

    return false
}
