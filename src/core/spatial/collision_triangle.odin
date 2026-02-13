package Spatial


import "core:math/linalg"

Collision_Triangle :: struct {
	points: [3]Vector,
}


collision_triangle_normal :: proc(coll_tri: ^Collision_Triangle) -> Vector {
	return linalg.normalize(
		linalg.cross(coll_tri.points.z - coll_tri.points.y, coll_tri.points.x - coll_tri.points.y),
	)
}

collision_triangle_center :: proc(coll_tri: ^Collision_Triangle) -> Vector {
	return (coll_tri.points.x + coll_tri.points.y + coll_tri.points.z) / 3
}

// This function uses the Dan Sunday's algorithm.
collision_triangle_point_inside :: proc(coll_tri: ^Collision_Triangle, point: ^Vector) -> bool {
	u: Vector = coll_tri.points.y - coll_tri.points.x
	v: Vector = coll_tri.points.z - coll_tri.points.x
	w: Vector = point^ - coll_tri.points.x

	uu: f32 = linalg.dot(u, u)
	uv: f32 = linalg.dot(u, v)
	vv: f32 = linalg.dot(v, v)
	wu: f32 = linalg.dot(w, u)
	wv: f32 = linalg.dot(w, v)
	d: f32 = uv * uv - uu * vv

	invD: f32 = 1 / d
	s: f32 = (uv * wv - vv * wu) * invD
	if s < 0 || s > 1 do return false

	t: f32 = (uv * wu - uu * wv) * invD
	if t < 0 || (s + t) > 1 do return false

	return true
}
