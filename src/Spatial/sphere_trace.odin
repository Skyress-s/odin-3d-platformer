package Spatial

import "core:math"
import "core:fmt"
import "core:math/linalg"
import "core:testing"

Sphere_Trace :: distinct struct {
	ray:    Ray,
	radius: f32,
}

calculate_hashes_by_sphere :: proc(radius: f32, location: ^Vector) -> (hash_keys: map[Hash_Key]bool) {
	assert(radius >= 0)
	rad := radius
	rad_bigger := rad * 1.3 // 30% percent bigger for now
	radius_vector := Vector{rad, rad, rad}
	bound := Bound{min= location^ - radius_vector, max = location^ + radius_vector}

	return calculate_overlapping_cells(bound)

}

// TODO create testing
@(test)
test_calculate_hashes_by_sphere :: proc(t: ^testing.T) {
	zero_vec := ZERO_VEC3
	
	hash_keys :map[Hash_Key]bool = calculate_hashes_by_sphere(5, &zero_vec)
	defer delete(hash_keys)

	some_arr :[dynamic]i32= make([dynamic]i32)
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
	// To start out with, we use a sphere that is 30 % bigger that the original
	trace_length := ray_length(&sphere_trace.ray)
	trace_direction := ray_direction(sphere_trace.ray)
	rad := sphere_trace.radius
	rad_bigger := rad * 1.3 // 30% percent bigger for now


	walk_distance := math.sqrt(rad_bigger * rad_bigger - rad * rad) // Application of Pythagoras

	current_dist :f32= 0.0

	for current_dist < trace_length {
		current_location := sphere_trace.ray.origin + trace_direction * current_dist
		new_cells := calculate_hashes_by_sphere(rad, &current_location)
		defer delete(new_cells)

		for cell in &new_cells{
			 cells[cell] = true
		}

		current_dist += walk_distance
	}

	return cells
}
