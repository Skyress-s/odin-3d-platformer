package Spatial

import "core:math"
import "core:math/linalg"


Plane :: distinct struct {
	point_on_plane, normal: Vector,
}

Plane_Compressed :: distinct struct {
	x, y, z, w: f32,
}

plane_comp_from_tri :: proc(tri: [3]Vector) -> Plane_Compressed {
	v0 := tri.x - tri.y
	v1 := tri.z - tri.y
	n := linalg.cross(v1, v0)
	n = linalg.normalize(n)

	a := n.x
	b := n.y
	c := n.z
	d := -(tri.x.x * a + tri.x.y * b + tri.x.z * c)

	return Plane_Compressed{a, b, c, d}
}

plane_comp_from_point_and_normal :: proc(p, n: Vector) -> Plane_Compressed {
	assert(linalg.length(n) != 0)
	n := linalg.normalize(n)

	return Plane_Compressed{x = n.x, y = n.y, z = n.z, w = -(p.x * n.x + p.y * n.y + p.z * n.z)}
}


Plane_Bounded :: distinct struct {
	// using plane: Plane,
	center, normal, forward: Vector,
	lenghts:                 Vector2,
}


distance_point_to_plane :: proc(plane: ^Plane, point: ^Vector) -> f32 {
	assert(linalg.length(plane.normal) > 0)
	return linalg.dot(plane.normal, point^) / linalg.length(plane.normal)
}

distance_to_plane_comp :: proc(plane: ^Plane_Compressed, p: ^Vector) -> f32 {
	return plane.x * p.x + plane.y * p.y + plane.z * p.z + plane.w
}

plane_comp_project :: proc(plane: ^Plane_Compressed, p: ^Vector) -> Vector {
	h: f32 = distance_to_plane_comp(plane, p)
	return Vector{p.x - plane.x * h, p.y - plane.y * h, p.z - plane.z * h}
}

plane_comp_reflect :: proc(plane: ^Plane_Compressed, vector: Vector) -> Vector {
	d := linalg.length(vector)
	return vector + 2 * Vector{-plane.x, -plane.y, -plane.z} * d

}
