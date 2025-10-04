package Spatial

import "core:math"
import "core:math/linalg"


Plane :: distinct struct {
	point_on_plane, normal: Vector,
}

Plane_Bounded :: distinct struct {
	// using plane: Plane,
	center, normal, forward: Vector,
	lenghts:     Vector2,
}


distance_point_to_plane :: proc(plane: ^Plane, point: ^Vector){
	assert(linalg.length(plane.normal) > 0)
	return linalg.dot(plane.normal, point) / linalg.length(plane.normal)
}
