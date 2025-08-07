package Spatial

import hms "../handle_map/handle_map_static"
import "core:fmt"
import "core:math"
import "core:math/linalg"

Ray :: struct {
	origin: Vector,
	end:    Vector,
}

ray_direction :: proc(ray: Ray) -> Vector {
	return linalg.vector_normalize(ray.end - ray.origin)
}

make_ray_with_origin_end :: proc(origin, end: Vector) -> Ray {
	return Ray{origin, end}
}

make_ray_with_origin_direction_distance :: proc(origin, direction: Vector, distance: f32) -> Ray {
	return Ray{origin, origin + direction * distance}
}

ray_intersect_spatial_hash_grid :: proc(
	hash_grid: ^Spatial_Hash_Grid,
	collision_object_map: ^Collision_Object_Handle_Map,
	ray: ^Ray,
) -> (
	hit: bool,
	id: Collision_Object_Id,
	location: Vector,
) {

	dist: f32 = max(f32)
	hashes := calculate_hashes_by_ray(ray^)
	ray_length := linalg.distance(ray.origin, ray.end)
	ray_direction := linalg.vector_normalize(ray.end - ray.origin)


	for hash in hashes {
		hash_cell, ok := &hash_grid[hash]
		if !ok do continue
		for &object_id in hash_cell.objects_ids {

			found_object := hms.get(collision_object_map, object_id)
			mat := get_matrix_from_transform(found_object.transform)
			for tri in found_object.tris {
				new_tri := tri
				for &t in &new_tri.points {
					trans_point := (mat * Vector4{t.x, t.y, t.z, 1})
					t.x = trans_point.x
					t.y = trans_point.y
					t.z = trans_point.z
				}

				ok, intersect_location := ray_triangle_intersect(ray, &new_tri)
				if ok {
					is_in_front := linalg.vector_dot(
						ray_direction,
						intersect_location - ray.origin,
					)

					new_distance := linalg.distance(intersect_location, ray.origin)

					if ((new_distance < dist) &&
						   (is_in_front > 0) &&
						   (linalg.distance(ray.origin, intersect_location) < ray_length)) {
						hit = true
						dist = new_distance
						id = object_id
						location = intersect_location
					}
				}
			}

		}
	}

	return hit, id, location
}


// Watch "One Lone Coder"s tutorial for how to improve this. 
// https://github.com/OneLoneCoder/Javidx9/blob/master/PixelGameEngine/SmallerProjects/OneLoneCoder_PGE_RayCastDDA.cpp
// todo this can probably return a array of hashes. So we can searsh through the closest cells first.
calculate_hashes_by_ray :: proc(ray: Ray) -> (cells: map[Hash_Key]bool) {
	direction := ray_direction(ray)

	ray_length_per_axis_unit := Vector {
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.x),
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.y),
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.z),
	}

	get_sign :: proc(value: f32) -> int {
		if value > 0 do return 1
		if value < 0 do return -1
		return 0
	}

	signs: [3]int = {get_sign(direction.x), get_sign(direction.y), get_sign(direction.z)}
	// fmt.println("signs ", signs)
	// fmt.println("ray lenght per unit ", ray_length_per_axis_unit)

	start_hash, end_hash := Hash_Location(ray.origin), Hash_Location(ray.end)
	current_hash := start_hash
	current_position := ray.origin

	cells[current_hash] = true

	iterations := 1000
	for current_hash != end_hash {
		// fmt.println("----------------------------------")
		iterations = iterations - 1
		if iterations == 0 do break
		// fmt.println("current_position ", current_position)
		// fmt.println("current_hash ", current_hash)

		cells[current_hash] = true

		current_percents: Vector = {}

		current_percents.x =
			(current_position.x - Unhash_Coordinate(current_hash.x)) / HASH_CELL_SIZE_METERS_FLOAT
		current_percents.y =
			(current_position.y - Unhash_Coordinate(current_hash.y)) / HASH_CELL_SIZE_METERS_FLOAT
		current_percents.z =
			(current_position.z - Unhash_Coordinate(current_hash.z)) / HASH_CELL_SIZE_METERS_FLOAT

		if signs.x > 0 do current_percents.x = 1 - current_percents.x
		if signs.y > 0 do current_percents.y = 1 - current_percents.y
		if signs.z > 0 do current_percents.z = 1 - current_percents.z

		current_lengths := current_percents * ray_length_per_axis_unit

		// fmt.println("current_percents_left ", current_percents)
		// fmt.println("current_lengths ", current_lengths)

		if ((current_lengths.x <= current_lengths.y || math.is_nan(current_lengths.y)) &&
			   (current_lengths.x <= current_lengths.z || math.is_nan(current_lengths.z))) {
			current_position =
				current_position + direction * current_percents.x * HASH_CELL_SIZE_METERS_FLOAT
			current_hash.x += 1 * i32(signs.x)

		} else if ((current_lengths.y <= current_lengths.x || math.is_nan(current_lengths.x)) &&
			   (current_lengths.y <= current_lengths.z || math.is_nan(current_lengths.z))) {
			current_position =
				current_position + direction * current_percents.y * HASH_CELL_SIZE_METERS_FLOAT
			current_hash.y += 1 * i32(signs.y)
		} else if ((current_lengths.z <= current_lengths.y || math.is_nan(current_lengths.y)) &&
			   (current_lengths.z <= current_lengths.x || math.is_nan(current_lengths.x))) {
			current_position =
				current_position + direction * current_percents.z * HASH_CELL_SIZE_METERS_FLOAT
			current_hash.z += 1 * i32(signs.z)
		} else {panic("damn it! calculate_hashes_by_ray() is not working again.")}
	}

	return cells
}


// there is something funky happening here. Assert is triggering 
calculate_hashes_by :: proc(ray: Ray) -> (cells: map[Hash_Key]bool) {
	hash_start := Hash_Location(ray.origin)
	hash_end := Hash_Location(ray.end)
	cells[hash_start] = true

	if hash_start == hash_end {
		return cells
	}

	start_to_end := ray.end - ray.origin
	assert(
		linalg.vector_length(start_to_end) > 0,
		"Not expected, consider adding early bail here if this is happening",
	)

	direction := linalg.vector_normalize(start_to_end)
	dirs: [3]Hash_Int = {
		direction.x > 0.0 ? 1 : -1, // todo
		direction.y > 0.0 ? 1 : -1,
		direction.z > 0.0 ? 1 : -1,
	}

	vector_length_one_hash_cell_walked := Vector {
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.x),
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.y),
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.z),
	}

	// Todo, this is very much *not optimal, but works for now*
	//if math.is_nan_f32(vector_length_one_hash_cell_walked.x) do vector_length_one_hash_cell_walked.x = max(f32)
	//if math.is_nan_f32(vector_length_one_hash_cell_walked.y) do vector_length_one_hash_cell_walked.y = max(f32)
	//if math.is_nan_f32(vector_length_one_hash_cell_walked.z) do vector_length_one_hash_cell_walked.z = max(f32)
	/*
	fmt.printfln("vector_length_one_hash_cell_walked {}", vector_length_one_hash_cell_walked)
	fmt.printfln(
		"{} {} {}",
		1 < vector_length_one_hash_cell_walked.x,
		1 < vector_length_one_hash_cell_walked.y,
		1 < vector_length_one_hash_cell_walked.z,
	)
	*/

	current_point := ray.origin

	i: int = 1000

	for hash_current := Hash_Location(current_point); hash_current != hash_end; {
		i = i - 1

		if i == 0 do panic(fmt.aprintf("we did some opsie in the calculation current_hash {}, start_hash {}, end_hash {}", hash_current, hash_start, hash_end))

		next_X_hash := hash_current.x + 1
		next_Y_hash := hash_current.y + 1
		next_Z_hash := hash_current.z + 1

		percent_X := linalg.unlerp(
			Unhash_Coordinate(next_X_hash),
			Unhash_Coordinate(hash_current.x),
			current_point.x,
		)
		if dirs.x == -1 do percent_X = 1 - percent_X
		length_X := vector_length_one_hash_cell_walked.x * percent_X

		percent_Y := linalg.unlerp(
			Unhash_Coordinate(next_Y_hash),
			Unhash_Coordinate(hash_current.y),
			current_point.y,
		)
		if dirs.y == -1 do percent_Y = 1 - percent_Y
		length_Y := vector_length_one_hash_cell_walked.y * percent_Y

		percent_Z := linalg.unlerp(
			Unhash_Coordinate(next_Z_hash),
			Unhash_Coordinate(hash_current.z),
			current_point.z,
		)
		if dirs.z == -1 do percent_Z = 1 - percent_Z
		length_Z := vector_length_one_hash_cell_walked.z * percent_Z


		/*
		fmt.printfln("current hash {}", current_hash)
		fmt.printfln("current point {}", current_point)
		fmt.printfln("current prosent {} {} {}", percent_X, percent_Y, percent_Z)
		fmt.printfln("current length {} {} {}", length_X, length_Y, length_Z)
		*/

		// TODO this is way more comparisons than we need, this is just to get it working 
		if (!math.is_nan(vector_length_one_hash_cell_walked.x) &&
			   !(length_X > length_Y || length_X > length_Z)) {
			// current_point = current_point + (gradient * (length_X / gradient.x))
			current_point =
				current_point + direction * (percent_X * HASH_CELL_SIZE_METERS_FLOAT / direction.x)
			hash_current.x += dirs.x

		} else if ((!math.is_nan(vector_length_one_hash_cell_walked.y)) &&
			   !(length_Y > length_X || length_Y > length_Z)) {
			// current_point = current_point + (gradient * (length_Y / gradient.y))
			current_point =
				current_point + direction * (percent_Y * HASH_CELL_SIZE_METERS_FLOAT / direction.y)
			hash_current.y += dirs.y

		} else if (!math.is_nan(vector_length_one_hash_cell_walked.z) &&
			   !(length_Z > length_X || length_Z > length_Y)) {
			// current_point = current_point + (gradient * (length_Z / gradient.z))
			current_point =
				current_point + direction * (percent_Z * HASH_CELL_SIZE_METERS_FLOAT / direction.z)
			hash_current.z += dirs.z
		} else {
			assert(
				1 == 0,
				fmt.aprintf(
					"lengths: {} {} {}, percents {} {} {}, hash cells {} {} {} {}, current_point: {}",
					length_X,
					length_Y,
					length_Z,
					percent_X,
					percent_Y,
					percent_Z,
					hash_current,
					next_X_hash,
					next_Y_hash,
					next_Z_hash,
					current_point,
				),
			)
		}
		cells[hash_current] = true
	}

	// hmmmm

	// delta := (ray.end - ray.origin)
	// delta_x, delta_y := delta.x, delta.y


	return cells
}
