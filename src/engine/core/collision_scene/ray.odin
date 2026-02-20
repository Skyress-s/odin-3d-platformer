package collision_scene

import gent "../../../game/game_entities/"
import col_mesh "../collision_mesh/"
import hent "../entity_handle/"
import spat "../spatial/"


import hm "core:container/handle_map"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

// Watch "One Lone Coder"s tutorial for how to improve this.
// https://github.com/OneLoneCoder/Javidx9/blob/master/PixelGameEngine/SmallerProjects/OneLoneCoder_PGE_RayCastDDA.cpp
// todo this can probably return a array of hashes. So we can searsh through the closest cells first.
calculate_hashes_by_ray :: proc(ray: spat.Ray) -> (cells: map[Hash_Key]bool) {
	direction := spat.ray_direction(ray)

	ray_length_per_axis_unit := spat.Vector {
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

		current_percents: spat.Vector = {}

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
calculate_hashes_by :: proc(ray: spat.Ray) -> (cells: map[Hash_Key]bool) {
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

	vector_length_one_hash_cell_walked := spat.Vector {
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

ray_intersect_spatial_hash_grid :: proc(
	hash_grid: ^Spatial_Hash_Grid,
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	col_ctx: ^col_mesh.Collider_Mesh_Context,
	ray: spat.Ray,
) -> (
	hit: bool,
	id: hent.Entity_Handle,
	location: spat.Vector,
) {

	hashes := calculate_hashes_by_ray(ray)
	defer delete(hashes)

	ray_length := linalg.distance(ray.origin, ray.end)
	ray_direction := linalg.vector_normalize(ray.end - ray.origin)


	dist: f32 = max(f32)
	for hash in hashes {
		hash_cell, ok := &hash_grid[hash]
		if !ok do continue
		for &object_id in hash_cell.objects_ids {

			found_object: ^gent.Entity = hm.get(collision_object_map, object_id)
			assert(found_object != nil)
			if gent.Trait.Collision not_in found_object.traits do continue
			if gent.Trait.Transform not_in found_object.traits do continue
			coliision_component := found_object.collision_component
			transform_component := found_object.transform_component

			collision_mesh: ^col_mesh.Mesh = hm.get(&col_ctx.mesh_map, coliision_component.mesh_id)
			assert(collision_mesh != nil)


			mat := spat.get_matrix_from_transform(transform_component.transform)
			for tri in collision_mesh.tris {
				new_tri := tri
				for &t in &new_tri.points {
					trans_point := (mat * spat.Vector4{t.x, t.y, t.z, 1})
					t.x = trans_point.x
					t.y = trans_point.y
					t.z = trans_point.z
				}

				ok, intersect_location := spat.ray_triangle_intersect(ray, new_tri)
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
