package collision_scene

import cc "../collision_channel/"
import cm "../collision_mesh/"
import hent "../entity_handle/"
import spat "../spatial/"
import "core:log"
import "core:reflect"


import "base:runtime"
import hm "core:container/handle_map"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:testing"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

Collision_Scene :: struct {
	spatial_hash_grid: Spatial_Hash_Grid,
}

init_collision_scene :: proc(col_scene: ^Collision_Scene, allocator: runtime.Allocator) {
	col_scene.spatial_hash_grid = make(Spatial_Hash_Grid, allocator)
	// add basic primitives
}

deinit_collision_scene :: proc(scene: ^Collision_Scene, allocator: runtime.Allocator) {
	// handeler by allocator
	delete_spatial_hash_grid(&scene.spatial_hash_grid)
	// cm.deinit(&scene.collision_meshes)

	// for item in scene.collision_object_map.items {
	// 	if hms.skip(item) do continue
	// 	delete(item.tris)
	// }

}


Hash_Cell :: struct {
	objects_ids: [dynamic]hent.Entity_Handle,
}

Hash_Int :: i32

HASH_CELL_SIZE_METERS :: 1 << 7 // 256
HASH_CELL_SIZE_METERS_FLOAT :: cast(f32)HASH_CELL_SIZE_METERS

HASH_CELL_SIZE :: spat.Vector {
	HASH_CELL_SIZE_METERS_FLOAT,
	HASH_CELL_SIZE_METERS_FLOAT,
	HASH_CELL_SIZE_METERS_FLOAT,
}

MAX_WORLD_LOCATION :: f32(max(Hash_Int)) * f32(HASH_CELL_SIZE_METERS)


/*
COLLISION_OBJECT_COUNTER: hent.Entity_Handle = 0

get_collision_id :: proc() -> hent.Entity_Handle {
	COLLISION_OBJECT_COUNTER += 1
	return COLLISION_OBJECT_COUNTER
}
*/
Hash_Key :: struct {
	x: Hash_Int,
	y: Hash_Int,
	z: Hash_Int,
}


Spatial_Hash_Grid ::  /*distinct*/map[Hash_Key]Hash_Cell


// @(test)
// test_spatial_hash_grid_and_map :: proc(t: ^testing.T) {
// 	shg: Spatial_Hash_Grid
// 	com: gent.Game_Entity_Handle_Map
//
// 	collision_object_data := shape_to_collision_object(
// 		spat.Collision_Shape{shape = spat.Box{{2, 2, 2}}},
// 	)
// 	defer delete(collision_object_data.tris)
// 	collision_object_id := add_to_object_map(&com, collision_object_data)
// 	add_to_spatial_hash_grid(&shg, collision_object_data, collision_object_id)
//
// 	delete_spatial_hash_grid(&shg)
// }
clear_spatial_hash_grid :: proc(shg: ^Spatial_Hash_Grid) {
	for key, &cell in shg {
		delete(cell.objects_ids)
	}
	clear(shg)
}

delete_spatial_hash_grid :: proc(shg: ^Spatial_Hash_Grid) {
	for key, &hash_cell in shg {
		delete_hash_cell(&hash_cell)
	}

	// free(shg, allocator)
	// delete_map()
	delete(shg^)
}

delete_hash_cell :: proc(shc: ^Hash_Cell) {
	delete(shc.objects_ids)
}

rand_vector :: proc() -> spat.Vector {
	return spat.Vector {
		rand.float32_range(-1, 1),
		rand.float32_range(-1, 1),
		rand.float32_range(-1, 1),
	}}

rand_rot :: proc() -> spat.Quaternion {return linalg.normalize(
		linalg.quaternion_from_forward_and_up(rand_vector(), rand_vector()),
	)}

key_to_corner_location :: proc(vec: ^Hash_Key) -> spat.Vector {
	x := cast(f32)(vec.x * HASH_CELL_SIZE_METERS)
	y := cast(f32)(vec.y * HASH_CELL_SIZE_METERS)
	z := cast(f32)(vec.z * HASH_CELL_SIZE_METERS)
	return {x, y, z}
}

calculate_hash_cell_width_location :: proc(hash_key: ^Hash_Key) -> (location: spat.Vector) {
	x := cast(f32)(hash_key.x * HASH_CELL_SIZE_METERS)
	y := cast(f32)(hash_key.y * HASH_CELL_SIZE_METERS)
	z := cast(f32)(hash_key.z * HASH_CELL_SIZE_METERS)

	offset := cast(f32)(HASH_CELL_SIZE_METERS) / 2.0
	t := cast(f32)HASH_CELL_SIZE_METERS

	location.x = x + offset
	location.y = y + offset
	location.z = z + offset

	return
}

Draw_Hash_Cell_Bounds :: proc(vec: Hash_Key, color: rl.Color = rl.GREEN) {
	x := cast(f32)(vec.x * HASH_CELL_SIZE_METERS)
	y := cast(f32)(vec.y * HASH_CELL_SIZE_METERS)
	z := cast(f32)(vec.z * HASH_CELL_SIZE_METERS)

	offset := cast(f32)(HASH_CELL_SIZE_METERS) / 2.0
	t := cast(f32)HASH_CELL_SIZE_METERS


	rl.DrawBoundingBox({{x, y, z}, {x + t, y + t, z + t}}, rl.GREEN)

	/*
	rl.DrawCubeWires(
		{x + offset, y + offset, x + offset},
		HASH_CELL_SIZE_METERS,
		HASH_CELL_SIZE_METERS,
		HASH_CELL_SIZE_METERS,
		rl.RED,
	)
	*/

}

Hash_Coordinate :: proc(v: f32) -> Hash_Int {
	return cast(Hash_Int)(math.floor(v / cast(f32)HASH_CELL_SIZE_METERS))
}

Unhash_Coordinate :: proc(hash: Hash_Int) -> f32 {
	return cast(f32)hash * HASH_CELL_SIZE_METERS
}

Hash_Location :: proc(vec: spat.Vector) -> (ret_val: Hash_Key) {
	ret_val.x = Hash_Coordinate(vec.x)
	ret_val.y = Hash_Coordinate(vec.y)
	ret_val.z = Hash_Coordinate(vec.z)
	/*
	ret_val.x = cast(Hash_Int)(math.floor(vec.x / cast(f32)HASH_CELL_SIZE_METERS))
	ret_val.y = cast(Hash_Int)(math.floor(vec.y / cast(f32)HASH_CELL_SIZE_METERS))
	ret_val.z = cast(Hash_Int)(math.floor(vec.z / cast(f32)HASH_CELL_SIZE_METERS))
	*/
	return
}

Unhash_Location :: proc(hash_key: Hash_Key) -> (location: spat.Vector) {
	location.x = Unhash_Coordinate(hash_key.x)
	location.y = Unhash_Coordinate(hash_key.y)
	location.z = Unhash_Coordinate(hash_key.z)
	return location
}


draw_collision_shape :: proc(collision_shape: spat.Collision_Shape, color: ^rl.Color) {

	bounds := spat.get_bounds(collision_shape)
	//fmt.println(bounds)
	rl.DrawBoundingBox(bounds, rl.YELLOW)

	rlgl.PushMatrix()
	defer rlgl.PopMatrix()

	mat := spat.get_matrix_from_transform((collision_shape.transform))
	matrix_data := rl.MatrixToFloatV(mat)
	rlgl.MultMatrixf(auto_cast &matrix_data)

	switch v in collision_shape.shape {
	case spat.Box:
		rl.DrawCube(rl.Vector3{0, 0, 0}, v.size.x, v.size.y, v.size.z, color^)
	case spat.Sphere:
		rl.DrawSphere(rl.Vector3{0, 0, 0}, v.radius, color^)
	case spat.Cylinder:
		rl.DrawCylinder(
			rl.Vector3{0, -v.height * 0.5, 0}, // raylib is weird with where the center of a 
			v.radius,
			v.radius,
			v.height,
			16,
			color^,
		)
	}
}


draw_hash_grid_bounds_populated_cells :: proc(
	hash_tree: map[Hash_Key]Hash_Cell,
	active_cell: ^Hash_Key,
) { 	// todo, pass by ptr?
	for Key in hash_tree {
		// Draw_Hash_Cell_Bounds(&Vector{cast(f32)Key.x, cast(f32)Key.y, cast(f32)Key.z})
		Draw_Hash_Cell_Bounds(Key)

	}
}


is_any_vertex_in_bound :: proc(
	hash_key: ^Hash_Key,
	tris: [dynamic]spat.Collision_Triangle,
) -> bool {
	for &collision_triangle in tris {
		for &p in collision_triangle.points {
			if Hash_Location(p) == hash_key^ do return true
		}
	}
	return false
}


calculate_overlapping_cells :: proc {
	calculate_overlapping_cells_by_bound,
	calculate_hashes_by_ray,
	calculate_hashes_by_sphere_trace,
	calculate_overlapping_cells_by_location,
}

calculate_overlapping_cells_by_location :: proc(loc: spat.Vector) -> map[Hash_Key]bool {

	return calculate_overlapping_cells_by_bound(spat.Bound{loc, loc})
}

calculate_overlapping_cells_by_bound :: proc(
	bound: spat.Bound,
	allocator := context.allocator,
) -> map[Hash_Key]bool {

	hash_keys := make(map[Hash_Key]bool, allocator)

	min_hash := Hash_Location(bound.min)
	hash_keys[min_hash] = true
	max_hash := Hash_Location(bound.max)
	hash_keys[max_hash] = true
	// Early bail if bound is contained within one cell
	// Todo is this actually more efficient? Have to test
	if min_hash == max_hash do return hash_keys

	// need to walk to the max cell, and go through every path

	minX, maxX: i32 = min_hash.x, max_hash.x
	minY, maxY: i32 = min_hash.y, max_hash.y
	minZ, maxZ: i32 = min_hash.z, max_hash.z


	// fmt.println("printing new cells for min: ", min_hash, " max: ", max_hash)
	for x := minX; x <= maxX; x += 1 {

		//new_hash := Hash_Key{x, y, z}
		//hash_keys[new_hash] = true
		for y := minY; y <= maxY; y += 1 {

			//new_hash := Hash_Key{x, y, z}
			//hash_keys[new_hash] = true
			for z := minZ; z <= maxZ; z += 1 {

				new_hash := Hash_Key{x, y, z}
				hash_keys[new_hash] = true
				// fmt.println("\t", new_hash)
			}
		}
	}

	return hash_keys
}


calculate_hashes_by_sphere :: proc(
	radius: f32,
	location: ^spat.Vector,
) -> (
	hash_keys: map[Hash_Key]bool,
) {
	assert(radius >= 0)
	rad := radius
	rad_bigger := rad * 1.3 // 30% percent bigger for now
	radius_vector := spat.Vector{rad, rad, rad}
	bound := spat.Bound {
		min = location^ - radius_vector,
		max = location^ + radius_vector,
	}

	return calculate_overlapping_cells(bound)

}
calculate_hashes_by_rays :: proc(rays: ^[dynamic]spat.Ray) -> (hashes: map[Hash_Key]bool) {
	for &ray in rays {
		new_hashes := calculate_hashes_by(ray)
		defer delete(new_hashes)

		for hash in &new_hashes {
			hashes[hash] = true
		}
	}

	return hashes
}

// TODO create testing
@(test)
test_calculate_hashes_by_sphere :: proc(t: ^testing.T) {
	zero_vec := spat.ZERO_VEC3

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
	sphere_trace: ^spat.Sphere_Trace,
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


calculate_rays_by_sphere_trace :: proc(
	sphere_trace: ^spat.Sphere_Trace,
) -> (
	rays: [dynamic]spat.Ray, // cells: map[Hash_Key]bool,
) {

	ray := &sphere_trace.ray
	ray_length := spat.ray_length(ray)
	forward := spat.ray_direction(ray^)

	up := linalg.normalize0(linalg.cross(forward, spat.UP_VEC3))

	if up == spat.ZERO_VEC3 {
		up = spat.FORWARD_VEC3
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

		newt_gun_ray := spat.Ray {
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

// TODO: Move in spatial has grid? Or just remake every frame / change?
add_to_spatial_hash_grid :: proc(
	spatial_hash_grid: ^Spatial_Hash_Grid,
	id: hent.Entity_Handle,
	bounds: spat.Bound,
	allocator: runtime.Allocator,
) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	potential_hash_keys := calculate_overlapping_cells_by_bound(bounds, context.temp_allocator)

	for hash_key in potential_hash_keys {
		cell := &spatial_hash_grid[hash_key]
		if cell == nil {
			spatial_hash_grid[hash_key] = Hash_Cell{make([dynamic]hent.Entity_Handle, allocator)}
			cell = &spatial_hash_grid[hash_key]
		}

		append_elem(&cell.objects_ids, id)
	}
}
