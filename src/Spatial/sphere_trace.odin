package Spatial

import hms "../handle_map/handle_map_static"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:testing"

Sphere_Trace :: distinct struct {
	ray:    Ray,
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

disance_point_to_line :: proc(p_on_line, v, point: ^Vector) -> f32 {
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

sphere_trace_triangle_intersect :: proc(sphere_trace: ^Sphere_Trace, tri: ^Collision_Triangle) {
	close
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
