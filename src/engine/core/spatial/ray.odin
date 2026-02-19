package Spatial

import "core:fmt"
import "core:math"
import "core:math/linalg"

// TODO this is a line, a ray is boundless
Ray :: struct {
	origin: Vector,
	end:    Vector,
}

ray_direction :: proc(ray: Ray) -> Vector {
	return linalg.vector_normalize(ray.end - ray.origin)
}

ray_length :: proc(ray: ^Ray) -> f32 {
	return linalg.distance(ray.origin, ray.end)
}

make_ray_with_origin_end :: proc(origin, end: Vector) -> Ray {
	return Ray{origin, end}
}

make_ray_with_origin_direction_distance :: proc(origin, direction: Vector, distance: f32) -> Ray {
	return Ray{origin, origin + direction * distance}
}
