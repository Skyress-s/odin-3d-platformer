package Spatial

import "base:runtime"
import "core:math/linalg"
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

Shape :: enum {
	Box,
	Sphere,
	Cylinder,
}

get_box_enum :: proc(box: Box) -> Shape {
	return .Box
}
get_sphere_enum :: proc(sphere: Sphere) -> Shape {
	return .Sphere
}
get_cylinder_enum :: proc(cylinder: Cylinder) -> Shape {
	return .Cylinder
}


get_shape_enum :: proc {
	get_box_enum,
	get_sphere_enum,
	get_cylinder_enum,
}

Shape_Union :: union {
	Box,
	Sphere,
	Cylinder,
}

Collision_Shape :: struct {
	transform: Transform, // TODO: Remove?
	shape:     Shape_Union,
}

Bound :: rl.BoundingBox
make_bound_by_position :: proc(pos: Vector) -> Bound {
	return Bound{pos, pos}
}

make_bound_by_position_radius :: proc(pos: Vector, rad: f32) -> Bound {
	return Bound{pos - Vector{rad, rad, rad}, pos + Vector{rad, rad, rad}}
}

ray_plane_intersect :: proc(
	ray: Ray,
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
	ray: Ray,
	tri: Collision_Triangle,
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

distance_to_tri :: proc(t: ^Collision_Triangle, position: Vector) -> (dist: f32, normal: Vector) {
	closest := closest_point_on_triangle(position, t.points[0], t.points[1], t.points[2])
	diff := position - closest

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
	dist, normal := distance_to_tri(t, position^)

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
	dist, normal := distance_to_tri(t, position^)

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

matrix_from_transform_tr :: proc(trans: Transform) -> linalg.Matrix4f32 {
	return linalg.matrix4_from_trs(trans.position, trans.rotation, ONE_VEC3)
}

matrix_from_transform :: proc(trans: Transform) -> linalg.Matrix4f32 {
	return linalg.matrix4_from_trs(trans.position, trans.rotation, trans.scale)

	// translation := linalg.matrix4_translate(trans.position)
	// rotation := linalg.matrix4_from_quaternion(trans.rotation)
	// scale := linalg.matrix4_scale(trans.scale)
	// return linalg.mul(translation, linalg.mul(rotation, scale))
	// return linalg.mul(scale, linalg.mul(rotation, translation))
}

get_matrix_from_transform :: proc(trans: Transform) -> rl.Matrix { 	// TODO how to pass by ptr here?
	// return linalg.matrix4_from_trs(trans.position, trans.rotation, trans.scale)
	matScale := rl.MatrixScale(trans.scale.x, trans.scale.y, trans.scale.z)
	matRotation := rl.QuaternionToMatrix(trans.rotation)
	matTranslation := rl.MatrixTranslate(trans.position.x, trans.position.y, trans.position.z)

	return matTranslation * matRotation * matScale
	// return  matTranslation * matScale
}

// Typical usecase of the return value:  rlgl.MultMatrixf(auto_cast &matrix_data)
calculate_matrix_from_loc_rot :: proc(loc: ^Vector, rot: ^Quaternion) -> rlgl.Matrix {
	matRotation := rl.QuaternionToMatrix(rot^)

	matTranslation := rl.MatrixTranslate(loc.x, loc.y, loc.z)

	// Combine them: Scale -> Rotate -> Translate
	// Order matters: S * R * T
	transform := matTranslation * matRotation
	// transform :=  matRotation * matTranslation
	return transform
}

get_bounds :: proc(collision_shape: Collision_Shape) -> (bound: Bound) { 	// Todo reference

	// using collision_shape.transform
	srtMatrix := get_matrix_from_transform(collision_shape.transform)

	switch shape in collision_shape.shape {
	case Box:
		// vec1trans := srtMatrix * {vec1.x, vec1.y, vec1.z, 1.0}
		// using shape
		x := shape.size.x
		y := shape.size.y
		z := shape.size.z
		points := [8]Vector {
			Vector{x, y, z} / 2,
			Vector{-x, y, z} / 2,
			Vector{-x, -y, z} / 2,
			Vector{-x, -y, -z} / 2,
			Vector{x, -y, -z} / 2,
			Vector{x, y, -z} / 2,
			Vector{x, -y, z} / 2,
			Vector{-x, y, -z} / 2,
		}

		maxX, maxY, maxZ, minX, minY, minZ: f32 =
			min(f32), min(f32), min(f32), max(f32), max(f32), max(f32)
		for p in points {
			transformed_p := srtMatrix * linalg.Vector4f32{p.x, p.y, p.z, 1}

			maxX = max(maxX, transformed_p.x)
			minX = min(minX, transformed_p.x)

			maxY = max(maxY, transformed_p.y)
			minY = min(minY, transformed_p.y)

			maxZ = max(maxZ, transformed_p.z)
			minZ = min(minZ, transformed_p.z)
		}

		bound.min = Vector{minX, minY, minZ}
		bound.max = Vector{maxX, maxY, maxZ}
	// bound.min = translation - (shape.size.xyz * scale.xyz / 2.0)
	// bound.max = translation + (shape.size.xyz * scale.xyz / 2.0)
	case Sphere:
		r := shape.radius
		scale := collision_shape.transform.scale
		bound.min =
			collision_shape.transform.position - Vector{r * scale.x, r * scale.y, r * scale.z}
		bound.max =
			collision_shape.transform.position + Vector{r * scale.x, r * scale.y, r * scale.z}
	case Cylinder:
		x := shape.radius
		y := shape.height / 2.0
		z := shape.radius
		points := [8]Vector {
			Vector{x, y, z},
			Vector{-x, y, z},
			Vector{-x, -y, z},
			Vector{-x, -y, -z},
			Vector{x, -y, -z},
			Vector{x, y, -z},
			Vector{x, -y, z},
			Vector{-x, y, -z},
		}

		maxX, maxY, maxZ, minX, minY, minZ: f32 =
			min(f32), min(f32), min(f32), max(f32), max(f32), max(f32)
		for p in points {
			transformed_p := srtMatrix * linalg.Vector4f32{p.x, p.y, p.z, 1}

			maxX = max(maxX, transformed_p.x)
			minX = min(minX, transformed_p.x)

			maxY = max(maxY, transformed_p.y)
			minY = min(minY, transformed_p.y)

			maxZ = max(maxZ, transformed_p.z)
			minZ = min(minZ, transformed_p.z)
		}
		bound.min = Vector{minX, minY, minZ}
		bound.max = Vector{maxX, maxY, maxZ}

	/*

		bound.min = spat.Vector{minX, minY, minZ}
		bound.max = spat.Vector{maxX, maxY, maxZ}
		bound.min =
			translation -
			Vector{shape.radius * scale.x, shape.height * 0.5 * scale.x, shape.radius * scale.z}
		bound.max =
			translation +
			Vector{shape.radius * scale.x, shape.height * 0.5 * scale.x, shape.radius * scale.z}

		*/
	}

	return

}

transform_triangle_by_matrix :: proc(
	tri: Collision_Triangle,
	mat: rl.Matrix,
) -> (
	ret_tri: Collision_Triangle,
) {
	for &p in ret_tri.points {
		p = (mat * rl.Vector4{p.x, p.y, p.z, 1}).xyz
	}
	return ret_tri
}

transform_triangle_by_transform :: proc(
	tri: Collision_Triangle,
	transform: Transform,
) -> Collision_Triangle {
	mat := get_matrix_from_transform(transform)
	return transform_triangle_by_matrix(tri, mat)
}

transform_triangles :: proc(tris: ^[dynamic]Collision_Triangle, transform: Transform) {
	mat := get_matrix_from_transform(transform)
	for &tri in tris {
		tri = transform_triangle_by_matrix(tri, mat)
	}
}

calculate_bounds_from_tris_transform :: proc(
	tris: [dynamic]Collision_Triangle,
	transform: Transform,
) -> Bound {
	// TODO REMOVE

	bound: Bound = {}

	bound.min = Vector{max(f32), max(f32), max(f32)}
	bound.max = Vector{min(f32), min(f32), min(f32)}

	mat := get_matrix_from_transform(transform)
	for &tri in tris {
		/*#unroll*/for p in tri.points { 	// todo how to unroll
			p2 := mat * rl.Vector4{p.x, p.y, p.z, 1}
			// p2 :=  rl.Vector4{p.x, p.y, p.z, 1} * mat
			if p2.x > bound.max.x do bound.max.x = p2.x
			if p2.x < bound.min.x do bound.min.x = p2.x

			if p2.y > bound.max.y do bound.max.y = p2.y
			if p2.y < bound.min.y do bound.min.y = p2.y

			if p2.z > bound.max.z do bound.max.z = p2.z
			if p2.z < bound.min.z do bound.min.z = p2.z
		}
	}

	return bound
}

calculate_bounds_from_tris :: proc(tris: [dynamic]Collision_Triangle) -> Bound {

	bound: Bound = {}

	bound.min = Vector{max(f32), max(f32), max(f32)}
	bound.max = Vector{min(f32), min(f32), min(f32)}

	for &tri in tris {
		/*#unroll*/for p in tri.points { 	// todo how to unroll
			if p.x > bound.max.x do bound.max.x = p.x
			if p.x < bound.min.x do bound.min.x = p.x

			if p.y > bound.max.y do bound.max.y = p.y
			if p.y < bound.min.y do bound.min.y = p.y

			if p.z > bound.max.z do bound.max.z = p.z
			if p.z < bound.min.z do bound.min.z = p.z
		}
	}

	return bound
}
shape_to_collision_triangles :: proc(
	shape: Collision_Shape,
) -> (
	tris: [dynamic]Collision_Triangle,
	transform: Transform,
) {
	switch &s in shape.shape {
	case Box:
		tris = box_get_tris_DEPRICATED(&s, shape)
	case Sphere:
		panic("Not implemented shape_get_collision_tris for Sphere")
	case Cylinder:
		panic("Not implemented shape_get_collision_tris for Cylinder")
	}

	transform = shape.transform

	return tris, transform
}


get_box_tris :: proc(allocator: runtime.Allocator) -> [dynamic]Collision_Triangle {
	box := Box {
		size = ONE_VEC3,
	}
	x := box.size.x / 2.0
	y := box.size.y / 2.0
	z := box.size.z / 2.0

	points := [8]Vector {
		Vector{x, y, z}, // 0
		Vector{-x, y, z}, // 1
		Vector{-x, -y, z}, // 2
		Vector{-x, -y, -z}, // 3
		Vector{x, -y, -z}, // 4
		Vector{x, y, -z}, // 5
		Vector{x, -y, z}, // 6
		Vector{-x, y, -z}, // 7
	}

	// mat := get_matrix_from_transform(shape.transform)

	transformed_points: [8]Vector = {}

	// for p, i in points {
	// 	transformed_p := mat * linalg.Vector4f32{p.x, p.y, p.z, 1}
	// 	pp: spat.Vector = transformed_p.xyz
	// 	transformed_points[i] = pp
	// }

	tris: [dynamic]Collision_Triangle = make([dynamic]Collision_Triangle, allocator)

	// ps := &transformed_points
	ps := points

	// Top
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[5], ps[1]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[1], ps[5], ps[7]}})
	// Bottom
	append(&tris, Collision_Triangle{[3]Vector{ps[2], ps[3], ps[4]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[2], ps[4], ps[6]}})
	// Left
	append(&tris, Collision_Triangle{[3]Vector{ps[3], ps[5], ps[4]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[3], ps[7], ps[5]}})
	// Right
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[1], ps[2]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[6], ps[0], ps[2]}})
	// Forward
	append(&tris, Collision_Triangle{[3]Vector{ps[1], ps[3], ps[2]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[3], ps[1], ps[7]}})
	// Backward
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[4], ps[5]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[6], ps[4]}})

	return tris

}

box_get_tris_DEPRICATED :: proc(box: ^Box, shape: Collision_Shape) -> [dynamic]Collision_Triangle {

	x := shape.transform.scale.x * box.size.x / 2.0
	y := shape.transform.scale.y * box.size.y / 2.0
	z := shape.transform.scale.z * box.size.z / 2.0

	points := [8]Vector {
		Vector{x, y, z}, // 0
		Vector{-x, y, z}, // 1
		Vector{-x, -y, z}, // 2
		Vector{-x, -y, -z}, // 3
		Vector{x, -y, -z}, // 4
		Vector{x, y, -z}, // 5
		Vector{x, -y, z}, // 6
		Vector{-x, y, -z}, // 7
	}

	// mat := get_matrix_from_transform(shape.transform)

	transformed_points: [8]Vector = {}

	// for p, i in points {
	// 	transformed_p := mat * linalg.Vector4f32{p.x, p.y, p.z, 1}
	// 	pp: spat.Vector = transformed_p.xyz
	// 	transformed_points[i] = pp
	// }

	tris: [dynamic]Collision_Triangle = {}

	// ps := &transformed_points
	ps := points

	// Top
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[5], ps[1]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[1], ps[5], ps[7]}})
	// Bottom
	append(&tris, Collision_Triangle{[3]Vector{ps[2], ps[3], ps[4]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[2], ps[4], ps[6]}})
	// Left
	append(&tris, Collision_Triangle{[3]Vector{ps[3], ps[5], ps[4]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[3], ps[7], ps[5]}})
	// Right
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[1], ps[2]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[6], ps[0], ps[2]}})
	// Forward
	append(&tris, Collision_Triangle{[3]Vector{ps[1], ps[3], ps[2]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[3], ps[1], ps[7]}})
	// Backward
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[4], ps[5]}})
	append(&tris, Collision_Triangle{[3]Vector{ps[0], ps[6], ps[4]}})

	return tris
}
