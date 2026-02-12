package Spatial

import cc "../../Physics/collision_channel"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:testing"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

Vector :: rl.Vector3
Vector2 :: rl.Vector2
Vector4 :: rl.Vector4
Quaternion :: quaternion128

ZERO_VEC3 :: Vector{0, 0, 0}
ZERO_VEC2 :: Vector2{0, 0}
ZERO_VEC4 :: Vector4{0, 0, 0, 0}
ONE_VEC3 :: Vector{1, 1, 1}

FORWARD_VEC3 :: Vector{1, 0, 0}
RIGHT_VEC3 :: Vector{0, 0, 1}
UP_VEC3 :: Vector{0, 1, 0}

// Transform :: rl.Transform

QUATERNION_IDENTITY :: linalg.QUATERNIONF32_IDENTITY

TRANSFORM_IDENTITY :: Transform {
	position = ZERO_VEC3,
	rotation = QUATERNION_IDENTITY,
	scale    = ONE_VEC3,
}


Box :: struct {
	size: Vector,
}

Box_Better :: struct {
	size, position: Vector,
	rotation:       Quaternion,
}


Sphere :: struct {
	radius: f32,
	center: Vector,
}

QuaternionData :: distinct struct {
	x, y, z, w: f32,
}

Cylinder :: struct {
	height: f32,
	radius: f32,
}

Collision_Shape :: struct {
	transform: Transform,
	shape:     union {
		Box,
		Sphere,
		Cylinder,
	},
}

Bound :: rl.BoundingBox


ray_plane_intersect :: proc(
	ray: ^Ray,
	plane_normal, point_on_plane: Vector,
) -> (
	hit: bool,
	location: Vector,
) {
	ray_dir := linalg.vector_normalize(ray.end - ray.origin)
	ray_pos := ray.origin

	ray_tri_normal_dot := linalg.vector_dot(ray_dir, plane_normal)
	if abs(ray_tri_normal_dot) < 0.0001 do return false, Vector{}

	t :=
		(linalg.vector_dot(point_on_plane - ray_pos, plane_normal)) /
		linalg.vector_dot(ray_dir, plane_normal)

	intersection_point := ray_pos + ray_dir * t
	return true, intersection_point
}

ray_triangle_intersect :: proc(
	ray: ^Ray,
	tri: ^Collision_Triangle,
) -> (
	valid: bool,
	location: Vector,
) {
	ray_dir := linalg.vector_normalize(ray.end - ray.origin)
	ray_pos := ray.origin

	ab := tri.points.y - tri.points.x
	ac := tri.points.z - tri.points.x
	cb := tri.points.y - tri.points.z
	some_point_on_triangle := tri.points.x

	tri_normal := linalg.vector_cross3(ab, ac)

	success, p := ray_plane_intersect(ray, tri_normal, some_point_on_triangle)
	if !success do return false, Vector{}

	A_to_point := p - tri.points.x
	B_to_point := p - tri.points.y
	C_to_point := p - tri.points.z

	// Barycentic coordinates

	t1 := linalg.vector_cross3(A_to_point, ac)
	t2 := linalg.vector_cross3(B_to_point, -ab)
	t3 := linalg.vector_cross3(C_to_point, cb)

	hit :=
		linalg.vector_dot(tri_normal, t1) > 0 &&
		linalg.vector_dot(tri_normal, t2) > 0 &&
		linalg.vector_dot(tri_normal, t3) > 0

	// if hit do rl.DrawSphere(p, 2.0, rl.RED) // TODO REMOVE!!!		
	valid = hit
	location = p
	return valid, location
}

// Real Time collision detection 5.1.5
closest_point_on_triangle :: proc(p, a, b, c: rl.Vector3) -> rl.Vector3 {
	// Check if P in vertex region outside A
	ab := b - a
	ac := c - a
	ap := p - a
	d1 := linalg.dot(ab, ap)
	d2 := linalg.dot(ac, ap)
	if d1 <= 0.0 && d2 <= 0.0 do return a // barycentric coordinates (1,0,0)
	// Check if P in vertex region outside B
	bp := p - b
	d3 := linalg.dot(ab, bp)
	d4 := linalg.dot(ac, bp)
	if d3 >= 0.0 && d4 <= d3 do return b // barycentric coordinates (0,1,0)
	// Check if P in edge region of AB, if so return projection of P onto AB
	vc := d1 * d4 - d3 * d2
	if vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0 {
		v := d1 / (d1 - d3)
		return a + v * ab // barycentric coordinates (1-v,v,0)
	}
	// Check if P in vertex region outside C
	cp := p - c
	d5 := linalg.dot(ab, cp)
	d6 := linalg.dot(ac, cp)
	if d6 >= 0.0 && d5 <= d6 do return c // barycentric coordinates (0,0,1)
	// Check if P in edge region of AC, if so return projection of P onto AC
	vb := d5 * d2 - d1 * d6
	if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 {
		w := d2 / (d2 - d6)
		return a + w * ac // barycentric coordinates (1-w,0,w)
	}
	// Check if P in edge region of BC, if so return projection of P onto BC
	va := d3 * d6 - d5 * d4
	if va <= 0.0 && (d4 - d3) >= 0.0 && (d5 - d6) >= 0.0 {
		w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return b + w * (c - b) // barycentric coordinates (0,1-w,w)
	}
	// P inside face region. Compute Q through its barycentric coordinates (u,v,w)
	denom := 1.0 / (va + vb + vc)
	v := vb * denom
	w := vc * denom
	return a + ab * v + ac * w // = u*a + v*b + w*c, u = va * denom = 1.0-v-w
}

distance_to_tri :: proc(t: ^Collision_Triangle, position: ^Vector) -> (dist: f32, normal: Vector) {
	closest := closest_point_on_triangle(position^, t.points[0], t.points[1], t.points[2])
	diff := position^ - closest

	dist = linalg.length(diff)
	normal = diff / dist
	return
}

reflect_dampen :: proc(vector, normal: Vector, dampen: f32) -> Vector {
	assert(dampen >= 0 && dampen <= 1)
	b := normal * (2 * linalg.dot(normal, vector) * (dampen * 0.5 + 0.5))
	return vector - b
}


// NOTE this has keep the momentum if you collide at a certain angle.
collide_with_tri :: proc(t: ^Collision_Triangle, vel, position: ^Vector, radius, dt: f32) {
	dist, normal := distance_to_tri(t, position)

	//rl.DrawCubeV(closest, 0.05, dist > char_data.radius ? rl.ORANGE : rl.WHITE)

	if dist < radius {
		position^ += normal * (radius - dist)
		// project velocity to the normal plane, if moving towards it
		vel_normal_dot: f32 = linalg.dot(vel^, normal)

		angles_euler := linalg.to_degrees(
			linalg.angle_between(linalg.cross(linalg.cross(normal, vel^), normal), vel^),
		)
		should_keep_momentum := angles_euler < 20
		velocity_length := linalg.length(vel^)

		if vel_normal_dot < 0 {
			diff := (vel^ - normal * vel_normal_dot) - vel^
			acceleration := diff / dt
			//verlet_component.acceleration += acceleration
			vel^ -= normal * vel_normal_dot

			if should_keep_momentum {
				vel^ = linalg.normalize(vel^) * velocity_length
			}
		}
	}
}

// NOTE this has keep the momentum if you collide at a certain angle.
clamp_to_tri :: proc(t: ^Collision_Triangle, vel, position: ^Vector, radius, dt: f32) {
	dist, normal := distance_to_tri(t, position)

	//rl.DrawCubeV(closest, 0.05, dist > char_data.radius ? rl.ORANGE : rl.WHITE)

	if dist < radius {
		position^ += normal * (radius - dist)
		// project velocity to the normal plane, if moving towards it

		vel_normal_dot: f32 = linalg.dot(vel^, normal)

		velocity_length := linalg.length(vel^)

		if vel_normal_dot < 0 {
			diff := (vel^ - normal * vel_normal_dot) - vel^
			acceleration := diff / dt
			vel^ -= normal * vel_normal_dot

		}
	}
}

collide_with_tri_continous :: proc(
	t: ^Collision_Triangle,
	velocity, position, position_last_update: ^Vector,
	radius, dt: f32,
) {
	trace := Sphere_Trace {
		ray = Ray{origin = position_last_update^, end = position^},
		radius = radius,
	}

	// calculate_hashes_by_sphere_trace(trace, )

}
