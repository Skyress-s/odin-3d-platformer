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
intersect_plane_bounded :: proc(
	ray: Ray,
	plane: ^Plane_Bounded,
) -> (
	hit_plane: bool,
	hit_loc, hit_norm: Vector,
) {
	coll_tris := make_collision_tris_from_plane_bounded(plane)
	hit, loc := ray_triangle_intersect(ray, coll_tris.x)
	if hit do return true, loc, plane.normal

	hit, loc = ray_triangle_intersect(ray, coll_tris.y)
	if hit do return true, loc, plane.normal
	return false, ZERO_VEC3, ZERO_VEC3
}

make_collision_tris_from_plane_bounded :: proc(
	plane: ^Plane_Bounded,
) -> (
	tris: [2]Collision_Triangle,
) {
	x := linalg.normalize(plane.forward)
	y := linalg.normalize(linalg.cross(plane.forward, plane.normal))

	tri1: Collision_Triangle
	tri1.points.x = +x * plane.lenghts.x / 2 + y * plane.lenghts.y / 2
	tri1.points.y = +x * plane.lenghts.x / 2 - y * plane.lenghts.y / 2
	tri1.points.z = -x * plane.lenghts.x / 2 + y * plane.lenghts.y / 2

	tri2: Collision_Triangle
	tri2.points.z = -x * plane.lenghts.x / 2 - y * plane.lenghts.y / 2
	tri2.points.y = +x * plane.lenghts.x / 2 - y * plane.lenghts.y / 2
	tri2.points.x = -x * plane.lenghts.x / 2 + y * plane.lenghts.y / 2

	for &p in &tri1.points {
		// p = p + x * plane.lenghts.x / 2
		// p = p + y * plane.lenghts.y / 2
		//p *= plane.lenghts.x / 2
		p += plane.center
	}

	for &p in &tri2.points {
		// p = p + x * plane.lenghts.x / 2
		// p = p + y * plane.lenghts.y / 2
		//p *= plane.lenghts.x / 2
		p += plane.center
	}

	tris.x = tri1
	tris.y = tri2
	return tris
}

make_collision_tris_from_planes_bounded :: proc(
	planes: ^[6]Plane_Bounded,
) -> (
	tris: [12]Collision_Triangle,
) {
	i := 0
	for &plane in planes {
		new_tris := make_collision_tris_from_plane_bounded(&plane)
		tris[i] = new_tris[0]
		i += 1
		tris[i] = new_tris[1]
		i += 1
	}

	return tris

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
