package Spatial

import "core:math/linalg"

Ray :: struct {
	origin: Vector,
	end:    Vector,
}

make_ray_with_origin_end :: proc(origin, end: Vector) -> Ray {
	return Ray{origin, end}
}

make_ray_with_origin_direction_distance :: proc(origin, direction: Vector, distance: f32) -> Ray {
	return Ray{origin, origin + direction * distance}
}

ray_intersect_spatial_hash_grid :: proc(
	hash_grid: ^Spatial_Hash_Grid,
	ray: ^Ray,
) -> (
	hit: bool,
	id: Collision_Object_Id,
	location: Vector,
) {

	dist: f32 = max(f32)
	hashes := calculate_hashes_by_ray(ray^)

	for hash in hashes {
		hash_cell, ok := &hash_grid[hash]
		if !ok do continue
		for &object in hash_cell.objects {
			for &tri in object.tris {
				ok, intersect_location := ray_triangle_intersect(ray, &tri)
				if ok {
					new_distance := linalg.distance(intersect_location, ray.origin)
					if new_distance < dist {
						hit = true
						dist = new_distance
						id = object.id
						location = intersect_location
					}
				}
			}

		}
	}

	return hit, id, location
}
