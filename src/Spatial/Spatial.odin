package Spatial

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

Vector :: rl.Vector3

// Transform :: rl.Transform
Transform :: struct {
	translation: Vector,
	rotation:    quaternion128,
	scale:       Vector,
}

Box :: struct {
	size: Vector,
}

Sphere :: struct {
	radius: f32,
}

Cylinder :: struct {
	height: f32,
	radius: f32,
}

Collision_Shape :: struct {
	id:        i32,
	transform: Transform,
	shape:     union {
		Box,
		Sphere,
		Cylinder,
	},
}

Bound :: rl.BoundingBox


Collision_Triangle :: struct {
	points: [3]Vector,
}

Collision_Object :: struct {
	id:   u16,
	tris: [dynamic]Collision_Triangle,
}

Hash_Cell :: struct {
	objects: [dynamic]Collision_Object,
}

Hash_Int :: i32

HASH_CELL_SIZE_METERS :: 1 << 5 // 256
HASH_CELL_SIZE_METERS_FLOAT :: cast(f32)HASH_CELL_SIZE_METERS

MAX_WORLD_LOCATION :: f32(max(Hash_Int)) * f32(HASH_CELL_SIZE_METERS)

Collision_Object_Id :: u16

COLLISION_OBJECT_COUNTER: Collision_Object_Id = 0

get_collision_id :: proc() -> Collision_Object_Id {
	COLLISION_OBJECT_COUNTER += 1
	return COLLISION_OBJECT_COUNTER
}

Hash_Key :: struct {
	x: Hash_Int,
	y: Hash_Int,
	z: Hash_Int,
}
key_to_corner_location :: proc(vec: ^Hash_Key) -> Vector {
	x := cast(f32)(vec.x * HASH_CELL_SIZE_METERS)
	y := cast(f32)(vec.y * HASH_CELL_SIZE_METERS)
	z := cast(f32)(vec.z * HASH_CELL_SIZE_METERS)
	return {x, y, z}
}

Draw_Hash_Cell_Bounds :: proc(vec: Hash_Key, color: rl.Color = rl.GREEN) {
	x := cast(f32)(vec.x * HASH_CELL_SIZE_METERS)
	y := cast(f32)(vec.y * HASH_CELL_SIZE_METERS)
	z := cast(f32)(vec.z * HASH_CELL_SIZE_METERS)

	offset := cast(f32)(HASH_CELL_SIZE_METERS) / 2.0
	t := cast(f32)HASH_CELL_SIZE_METERS


	rl.DrawBoundingBox({{x, y, z}, {x + t, y + t, z + t}}, rl.GREEN)

	/*
	rl.DrawCubeWires(
		{x + offset, y + offset, x + offset},
		HASH_CELL_SIZE_METERS,
		HASH_CELL_SIZE_METERS,
		HASH_CELL_SIZE_METERS,
		rl.RED,
	)
	*/

}

Hash_Coordinate :: proc(v: f32) -> Hash_Int {
	return cast(Hash_Int)(math.floor(v / cast(f32)HASH_CELL_SIZE_METERS))
}

Unhash_Coordinate :: proc(hash: Hash_Int) -> f32 {
	return cast(f32)hash * HASH_CELL_SIZE_METERS
}

Hash_Location :: proc(vec: Vector) -> (ret_val: Hash_Key) {
	ret_val.x = Hash_Coordinate(vec.x)
	ret_val.y = Hash_Coordinate(vec.y)
	ret_val.z = Hash_Coordinate(vec.z)
	/*
	ret_val.x = cast(Hash_Int)(math.floor(vec.x / cast(f32)HASH_CELL_SIZE_METERS))
	ret_val.y = cast(Hash_Int)(math.floor(vec.y / cast(f32)HASH_CELL_SIZE_METERS))
	ret_val.z = cast(Hash_Int)(math.floor(vec.z / cast(f32)HASH_CELL_SIZE_METERS))
	*/
	return
}

Unhash_Location :: proc(hash_key: Hash_Key) -> (location: Vector) {
	location.x = Unhash_Coordinate(hash_key.x)
	location.y = Unhash_Coordinate(hash_key.y)
	location.z = Unhash_Coordinate(hash_key.z)
	return location
}

get_matrix_from_transform :: proc(trans: Transform) -> rlgl.Matrix { 	// TODO how to pass by ptr here?
	matScale := rl.MatrixScale(trans.scale.x, trans.scale.y, trans.scale.z)

	// Create 1rotation matrix from quaternion
	matRotation := rl.QuaternionToMatrix(trans.rotation)

	// Create translation matrix
	matTranslation := rl.MatrixTranslate(
		trans.translation.x,
		trans.translation.y,
		trans.translation.z,
	)

	// Combine them: Scale -> Rotate -> Translate
	// Order matters: S * R * T
	// transform := matScale * matRotation
	// transform = transform * matTranslation
	transform := matTranslation * matRotation
	transform = transform * matScale
	// transform := matScale * matRotation * matTranslation
	// transform := matTranslation * matRotation * matScale
	return transform
}


draw_collision_shape :: proc(collision_shape: Collision_Shape, color: ^rl.Color) {

	bounds := get_bounds(collision_shape)
	fmt.println(bounds)
	rl.DrawBoundingBox(bounds, rl.YELLOW)

	rlgl.PushMatrix()
	defer rlgl.PopMatrix()

	mat := get_matrix_from_transform((collision_shape.transform))
	matrix_data := rl.MatrixToFloatV(mat)
	rlgl.MultMatrixf(auto_cast &matrix_data)

	switch v in collision_shape.shape {
	case Box:
		rl.DrawCube(rl.Vector3{0, 0, 0}, v.size.x, v.size.y, v.size.z, color^)
	case Sphere:
		rl.DrawSphere(rl.Vector3{0, 0, 0}, v.radius, color^)
	case Cylinder:
		rl.DrawCylinder(
			rl.Vector3{0, -v.height * 0.5, 0}, // raylib is weird with where the center of a 
			v.radius,
			v.radius,
			v.height,
			16,
			color^,
		)
	}
}


Draw_Hash_Tree :: proc(hash_tree: map[Hash_Key]Hash_Cell, active_cell: ^Hash_Key) { 	// todo, pass by ptr?
	for Key in hash_tree {
		// Draw_Hash_Cell_Bounds(&Vector{cast(f32)Key.x, cast(f32)Key.y, cast(f32)Key.z})
		Draw_Hash_Cell_Bounds(Key)

	}
}


box_get_tris :: proc(box: ^Box, shape: ^Collision_Shape) -> [dynamic]Collision_Triangle {

	using shape.transform
	x := scale.x * box.size.x / 2.0
	y := scale.y * box.size.y / 2.0
	z := scale.z * box.size.z / 2.0

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

	mat := get_matrix_from_transform(shape.transform)

	transformed_points: [8]Vector = {}

	for p, i in points {
		transformed_p := mat * linalg.Vector4f32{p.x, p.y, p.z, 1}
		pp: Vector = transformed_p.xyz
		transformed_points[i] = pp
	}

	tris: [dynamic]Collision_Triangle = {}

	// todo man this is funky, there must be a better way

	ps := &transformed_points

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

get_bounds :: proc(collision_shape: Collision_Shape) -> (bound: Bound) { 	// Todo reference

	using collision_shape.transform
	srtMatrix := get_matrix_from_transform(collision_shape.transform)

	switch shape in collision_shape.shape {
	case Box:
		// vec1trans := srtMatrix * {vec1.x, vec1.y, vec1.z, 1.0}
		using shape
		x := size.x
		y := size.y
		z := size.z
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
	// bound.min = translation - (shape.size.xyz * scale.xyz / 2.0)
	// bound.max = translation + (shape.size.xyz * scale.xyz / 2.0)
	case Sphere:
		r := shape.radius
		bound.min = translation - Vector{r * scale.x, r * scale.y, r * scale.z}
		bound.max = translation + Vector{r * scale.x, r * scale.y, r * scale.z}
	case Cylinder:
		using shape
		x := radius
		y := height / 2.0
		z := radius
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

		bound.min = Vector{minX, minY, minZ}
		bound.max = Vector{maxX, maxY, maxZ}
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
is_any_vertex_in_bound :: proc(hash_key: ^Hash_Key, tris: [dynamic]Collision_Triangle) -> bool {
	for &collision_triangle in tris {
		for &p in collision_triangle.points {
			if Hash_Location(p) == hash_key^ do return true
		}
	}
	return false
}

get_overlapping_cells2 :: proc(bound: Bound) -> (hash_keys: map[Hash_Key]bool) {

	min_hash := Hash_Location(bound.min)
	hash_keys[min_hash] = true
	max_hash := Hash_Location(bound.max)
	hash_keys[max_hash] = true

	// Early bail if bound is contained within one cell
	// Todo is this actually more efficient? Have to test
	if min_hash == max_hash do return hash_keys

	// need to walk to the max cell, and go through every path

	minX, maxX: i32 = min_hash.x, max_hash.x
	minY, maxY: i32 = min_hash.y, max_hash.y
	minZ, maxZ: i32 = min_hash.z, max_hash.z


	// fmt.println("printing new cells for min: ", min_hash, " max: ", max_hash)
	for x := minX; x <= maxX; x += 1 {

		//new_hash := Hash_Key{x, y, z}
		//hash_keys[new_hash] = true
		for y := minY; y <= maxY; y += 1 {

			//new_hash := Hash_Key{x, y, z}
			//hash_keys[new_hash] = true
			for z := minZ; z <= maxZ; z += 1 {

				new_hash := Hash_Key{x, y, z}
				hash_keys[new_hash] = true
				// fmt.println("\t", new_hash)
			}
		}
	}

	return hash_keys
}

get_overlapping_cells :: proc(bound: Bound) -> (cells: map[Hash_Key]bool) {

	using bound
	points := [8]Vector {
		Vector{min.x, min.y, min.z},
		Vector{max.x, min.y, min.z},
		Vector{max.x, max.y, min.z},
		Vector{max.x, max.y, max.z},
		Vector{min.x, max.y, max.z},
		Vector{min.x, min.y, max.z},
		Vector{max.x, min.y, max.z},
		Vector{min.x, max.y, min.z},
	}


	for v in points {
		cells[Hash_Location(v)] = true
	}
	return
}

add_shape_to_hash_map :: proc(shape: ^Collision_Shape, hash_map: ^map[Hash_Key]Hash_Cell) {
	bounds := get_bounds(shape^)
	potential_hash_keys := get_overlapping_cells2(bounds)

	/*
	for potential_hash_key in potential_hash_keys {

	}
	*/

	collision_object_id := get_collision_id()

	for hash_key in potential_hash_keys {
		cell := &hash_map[hash_key]
		if cell == nil {
			// fmt.println("Emty cell, creating new one...")
			hash_map[hash_key] = {}
			cell = &hash_map[hash_key]
		}
		tris := shape_get_collision_tris(shape)

		col_obs := Collision_Object{collision_object_id, {}}


		for &t in tris {
			append_elem(&col_obs.tris, t) // todo huah tuah
		}

		append_elem(&cell.objects, col_obs)
	}
}

shape_get_collision_tris :: proc(shape: ^Collision_Shape) -> [dynamic](Collision_Triangle) {
	switch &s in shape.shape {
	case Box:
		return box_get_tris(&s, shape)
	case Sphere:
	case Cylinder:
	}

	return {}

}


ray_triangle_intersect :: proc(
	ray_pos: ^Vector,
	ray_dir: ^Vector,
	tri: ^Collision_Triangle,
) -> bool {
	ab := tri.points.y - tri.points.x
	ac := tri.points.z - tri.points.x
	cb := tri.points.y - tri.points.z
	some_point_on_triangle := tri.points.x

	tri_normal := linalg.vector_cross3(ab, ac)

	ray_tri_normal_dot := linalg.vector_dot(ray_dir^, tri_normal)
	if abs(ray_tri_normal_dot) < 0.0001 do return false

	t :=
		(linalg.vector_dot(some_point_on_triangle - ray_pos^, tri_normal)) /
		linalg.vector_dot(ray_dir^, tri_normal)

	p := ray_pos^ + ray_dir^ * t

	A_to_point := p - tri.points.x
	B_to_point := p - tri.points.y
	C_to_point := p - tri.points.z


	t1 := linalg.vector_cross3(A_to_point, ac)
	t2 := linalg.vector_cross3(B_to_point, -ab)
	t3 := linalg.vector_cross3(C_to_point, cb)


	hit :=
		linalg.vector_dot(tri_normal, t1) > 0 &&
		linalg.vector_dot(tri_normal, t2) > 0 &&
		linalg.vector_dot(tri_normal, t3) > 0

	color: rl.Color = rl.RED
	if hit do color = rl.GREEN
	rl.DrawSphere(p, 2.0, color) // TODO REMOVE!!! 
	return hit
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

calculate_hashes_by_ray :: proc(ray: Ray) -> (cells: map[Hash_Key]bool) {
	hash_start := Hash_Location(ray.origin)
	hash_end := Hash_Location(ray.end)
	cells[hash_start] = true

	if hash_start == hash_end {
		return cells
	}

	start_to_end := ray.end - ray.origin
	assert(
		linalg.vector_length(start_to_end) > 0,
		"Not expected, consider adding early bail here if this is happening",
	)

	direction := linalg.vector_normalize(start_to_end)
	dirs: [3]Hash_Int = {
		direction.x > 0.0 ? 1 : -1, // todo
		direction.y > 0.0 ? 1 : -1,
		direction.z > 0.0 ? 1 : -1,
	}

	vector_length_one_hash_cell_walked := Vector {
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.x),
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.y),
		linalg.vector_length(direction * HASH_CELL_SIZE_METERS_FLOAT / direction.z),
	}


	current_point := ray.origin


	for current_hash := Hash_Location(current_point); current_hash != hash_end; {
		min, max: f32 =
			Unhash_Coordinate(current_hash.x),
			Unhash_Coordinate(current_hash.x) +
			HASH_CELL_SIZE_METERS_FLOAT


		next_X_hash := current_hash.x + 1
		next_Y_hash := current_hash.y + 1
		next_Z_hash := current_hash.z + 1

		percent_X := linalg.unlerp(
			Unhash_Coordinate(next_X_hash),
			Unhash_Coordinate(current_hash.x),
			current_point.x,
		)
		if dirs.x == -1 do percent_X = 1 - percent_X
		length_X := vector_length_one_hash_cell_walked.x * percent_X

		percent_Y := linalg.unlerp(
			Unhash_Coordinate(next_Y_hash),
			Unhash_Coordinate(current_hash.y),
			current_point.y,
		)
		if dirs.y == -1 do percent_Y = 1 - percent_Y
		length_Y := vector_length_one_hash_cell_walked.y * percent_Y

		percent_Z := linalg.unlerp(
			Unhash_Coordinate(next_Z_hash),
			Unhash_Coordinate(current_hash.z),
			current_point.z,
		)
		if dirs.z == -1 do percent_Z = 1 - percent_Z
		length_Z := vector_length_one_hash_cell_walked.z * percent_Z

		fmt.printfln("{} {} {}", percent_X, percent_Y, percent_Z)

		// TODO this is way more comparisons than we need, this is just to get it working 
		if (length_X <= length_Y && length_X <= length_Z) {
			// current_point = current_point + (gradient * (length_X / gradient.x))
			current_point =
				current_point + direction * (percent_X * HASH_CELL_SIZE_METERS_FLOAT / direction.x)
			current_hash.x += dirs.x

		} else if (length_Y <= length_X && length_Y <= length_Z) {
			// current_point = current_point + (gradient * (length_Y / gradient.y))
			current_point =
				current_point + direction * (percent_Y * HASH_CELL_SIZE_METERS_FLOAT / direction.y)
			current_hash.y += dirs.y

		} else if (length_Z <= length_X && length_Z <= length_Y) {
			// current_point = current_point + (gradient * (length_Z / gradient.z))
			current_point =
				current_point + direction * (percent_Z * HASH_CELL_SIZE_METERS_FLOAT / direction.z)
			current_hash.z += dirs.z
		} else {unreachable()}

		cells[current_hash] = true
	}

	// hmmmm

	// delta := (ray.end - ray.origin)
	// delta_x, delta_y := delta.x, delta.y


	return cells
}
