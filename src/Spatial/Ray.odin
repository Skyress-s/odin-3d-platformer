package Spatial

import hms "../handle_map/handle_map_static"
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
			for &tri in hms.get(collision_object_map, object_id).tris {
				ok, intersect_location := ray_triangle_intersect(ray, &tri)
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
