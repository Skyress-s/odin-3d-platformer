package Spatial

import "core:math"
import "core:math/linalg"
distance_point_to_line_sqr :: proc(p, lp0, lp1: Vector, line_point: ^Vector) -> f32 {
	v := p - lp0
	s := lp1 - lp0

	len_sq := linalg.length2(s)
	dot := linalg.dot(v, s) / len_sq
	disp := s * dot
	if line_point != nil {
		line_point^ = lp0 + disp
	}

	v -= disp
	return linalg.length2(v)
}

distance_point_to_line_v2 :: proc(p, lp0, lp1: Vector, line_point: ^Vector) -> f32 {
	return math.sqrt(distance_point_to_line_sqr(p, lp0, lp1, line_point))
}

intersection_line_line :: proc(p1, p2, p3, p4: Vector2, t: ^f32) -> bool {
	d1 := p2 - p1
	d2 := p3 - p4

	denom := d2.y * d1.x - d2.x * d1.y
	if denom == 0 do return false

	if t != nil {
		dist := d2.x*(p1.y-p3.y) - d2.y*(p1.x - p3.x)
		dist /= denom
		t^ = dist
	}
	
	return true

}

@(private)
square:: proc(a:f32) -> f32{
	return a*a
}

intersection_sphere_line :: proc(
	sphere: Sphere,
	pt0: Vector,
	pt1: Vector,
	nb_inter: ^i32,
	inter1: ^f32,
	inter2: ^f32
) -> bool {
	a := square(pt1.x - pt0.x) + square(pt1.y - pt0.y) + square(pt1.z - pt0.z)
	b := 2 * (
		(pt1.x - pt0.x) * (pt0.x - sphere.center.x) +
		(pt1.y - pt0.y) * (pt0.y - sphere.center.y) +
		(pt1.z - pt0.z) * (pt0.z - sphere.center.z)
	)
	c := square(sphere.center.x) + square(sphere.center.y) + square(sphere.center.z) +
		square(pt0.x) + square(pt0.y) + square(pt0.z) -
		2 * (sphere.center.x * pt0.x + sphere.center.y * pt0.y + sphere.center.z * pt0.z) -
		square(sphere.radius)

	i := square(b) - 4 * a * c

	if i < 0 {
		return false
	}

	if i == 0 {
		if nb_inter != nil do nb_inter^ = 1
		if inter1   != nil do inter1^   = -b / (2 * a)
	} else {
		if nb_inter != nil do nb_inter^ = 2
		if inter1   != nil do inter1^   = (-b + math.sqrt(i)) / (2 * a)
		if inter2   != nil do inter2^   = (-b - math.sqrt(i)) / (2 * a)
	}

	return true
}
