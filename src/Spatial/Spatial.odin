package Spatial

import "core:math/rand"
import cc "../Physics/collision_channel"
import hms "../handle_map/handle_map_static"
import "core:fmt"
import "core:math"
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
RIGHT_VEC3 :: Vector{0,0,1}
UP_VEC3 :: Vector{0, 1, 0}

// Transform :: rl.Transform
Transform :: distinct struct {
	position: Vector,
	rotation: Quaternion,
	scale:    Vector,
}

QUATERNION_IDENTITY :: linalg.QUATERNIONF32_IDENTITY

TRANSFORM_IDENTITY :: Transform {
	position = ZERO_VEC3,
	rotation = QUATERNION_IDENTITY,
	scale    = ONE_VEC3,
}

INVALID_OBJECT_ID :: Collision_Object_Id{}

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


Collision_Object_Id :: distinct hms.Handle


Collision_Object_Data :: distinct struct {
	collision_channels: u16,
	transform:          Transform,
	tris:               [dynamic]Collision_Triangle,
}

Collision_Object_Data_Runtime :: distinct struct {
	using data: Collision_Object_Data,
	handle:     Collision_Object_Id,
}

Hash_Cell :: struct {
	objects_ids: [dynamic]Collision_Object_Id,
}

Hash_Int :: i32

HASH_CELL_SIZE_METERS :: 1 << 7 // 256
HASH_CELL_SIZE_METERS_FLOAT :: cast(f32)HASH_CELL_SIZE_METERS

HASH_CELL_SIZE :: Vector {
	HASH_CELL_SIZE_METERS_FLOAT,
	HASH_CELL_SIZE_METERS_FLOAT,
	HASH_CELL_SIZE_METERS_FLOAT,
}

MAX_WORLD_LOCATION :: f32(max(Hash_Int)) * f32(HASH_CELL_SIZE_METERS)


/*
COLLISION_OBJECT_COUNTER: Collision_Object_Id = 0

get_collision_id :: proc() -> Collision_Object_Id {
	COLLISION_OBJECT_COUNTER += 1
	return COLLISION_OBJECT_COUNTER
}
*/
Hash_Key :: struct {
	x: Hash_Int,
	y: Hash_Int,
	z: Hash_Int,
}


Spatial_Hash_Grid ::  /*distinct*/map[Hash_Key]Hash_Cell

rand_vector :: proc() -> Vector{ return Vector{rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1)}}

rand_rot :: proc() -> Quaternion {return linalg.normalize(linalg.quaternion_from_forward_and_up(rand_vector(), rand_vector()))}

key_to_corner_location :: proc(vec: ^Hash_Key) -> Vector {
	x := cast(f32)(vec.x * HASH_CELL_SIZE_METERS)
	y := cast(f32)(vec.y * HASH_CELL_SIZE_METERS)
	z := cast(f32)(vec.z * HASH_CELL_SIZE_METERS)
	return {x, y, z}
}

calculate_hash_cell_width_location :: proc(hash_key: ^Hash_Key) -> (location: Vector) {
	x := cast(f32)(hash_key.x * HASH_CELL_SIZE_METERS)
	y := cast(f32)(hash_key.y * HASH_CELL_SIZE_METERS)
	z := cast(f32)(hash_key.z * HASH_CELL_SIZE_METERS)

	offset := cast(f32)(HASH_CELL_SIZE_METERS) / 2.0
	t := cast(f32)HASH_CELL_SIZE_METERS

	location.x = x + offset
	location.y = y + offset
	location.z = z + offset

	return
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

matrix_from_transform :: proc(trans: Transform) -> linalg.Matrix4f32{
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

	return  matTranslation* matRotation * matScale 
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


draw_collision_shape :: proc(collision_shape: Collision_Shape, color: ^rl.Color) {

	bounds := get_bounds(collision_shape)
	//fmt.println(bounds)
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


draw_hash_grid_bounds_populated_cells :: proc(
	hash_tree: map[Hash_Key]Hash_Cell,
	active_cell: ^Hash_Key,
) { 	// todo, pass by ptr?
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

	// mat := get_matrix_from_transform(shape.transform)

	transformed_points: [8]Vector = {}

	// for p, i in points {
	// 	transformed_p := mat * linalg.Vector4f32{p.x, p.y, p.z, 1}
	// 	pp: Vector = transformed_p.xyz
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
		bound.min = position - Vector{r * scale.x, r * scale.y, r * scale.z}
		bound.max = position + Vector{r * scale.x, r * scale.y, r * scale.z}
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

transform_triangles :: proc(tris: ^[dynamic]Collision_Triangle, transform: ^Transform) {
	mat := get_matrix_from_transform(transform^)
	for &tri in tris {
		/*#unroll*/for &p in tri.points { 	// todo how to unroll
			p = (mat * rl.Vector4{p.x, p.y, p.z, 1}).xyz
		}
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

calculate_overlapping_cells :: proc {
	calculate_overlapping_cells2,
	calculate_hashes_by_ray,
	calculate_hashes_by_sphere_trace,
}

calculate_overlapping_cells3 :: proc(bound: Bound, hash_keys: ^map[Hash_Key]bool) {
	min_hash := Hash_Location(bound.min)
	hash_keys[min_hash] = true
	max_hash := Hash_Location(bound.max)
	hash_keys[max_hash] = true

	// Early bail if bound is contained within one cell
	// Todo is this actually more efficient? Have to test
	// if min_hash == max_hash do return
	//
	// // need to walk to the max cell, and go through every path
	//
	// minX, maxX: i32 = min_hash.x, max_hash.x
	// minY, maxY: i32 = min_hash.y, max_hash.y
	// minZ, maxZ: i32 = min_hash.z, max_hash.z
	//
	//
	// // fmt.println("printing new cells for min: ", min_hash, " max: ", max_hash)
	// for x := minX; x <= maxX; x += 1 {
	//
	// 	//new_hash := Hash_Key{x, y, z}
	// 	//hash_keys[new_hash] = true
	// 	for y := minY; y <= maxY; y += 1 {
	//
	// 		//new_hash := Hash_Key{x, y, z}
	// 		//hash_keys[new_hash] = true
	// 		for z := minZ; z <= maxZ; z += 1 {
	//
	// 			new_hash := Hash_Key{x, y, z}
	// 			hash_keys[new_hash] = true
	// 			// fmt.println("\t", new_hash)
	// 		}
	// 	}
	// }
}

calculate_overlapping_cells2 :: proc(bound: Bound) -> (hash_keys: map[Hash_Key]bool) {
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

Collision_Object_Handle_Map :: distinct
hms.Handle_Map(Collision_Object_Data_Runtime, Collision_Object_Id, 1024)


notify_object_transform_changed :: proc(
	collision_object_map: ^Collision_Object_Handle_Map,
	spatial_hash_grid: ^map[Hash_Key]Hash_Cell,
	collision_object_id: Collision_Object_Id,
) -> Collision_Object_Id {

	found_object := hms.get(collision_object_map, collision_object_id)
	data := found_object
	bounds := calculate_bounds_from_tris_transform(found_object.tris, found_object.transform)

	test :: struct {
		id:  int,
		key: Hash_Key,
	}
	cells_to_remove: [dynamic]Hash_Key = {}
	object_to_remove: [dynamic]test = {}
	// Remove from spatial_hash_grid TODO: This is slow very inefficient
	for id, &cell in spatial_hash_grid {
		for &object_id, index in cell.objects_ids {
			if object_id == collision_object_id {
				append_elem(&object_to_remove, test{index, id})
			}
		}

	}


	for t in object_to_remove {
		object := &spatial_hash_grid[t.key]
		unordered_remove(&object.objects_ids, t.id) // wondering if this will work

		// hms.remove(collision_object_map, collision_object_id)

		if len(object.objects_ids) == 0 {
			append(&cells_to_remove, t.key)

		}
	}


	for &id in &cells_to_remove {
		delete_key(spatial_hash_grid, id)
	}

	add_to_spatial_hash_grid(spatial_hash_grid, found_object.data, found_object.handle)
	// Insert again
	// id := create_and_add_collision_object_from_tris_transform(
	// 	collision_object_map,
	// 	spatial_hash_grid,
	// 	data.data.tris,
	// 	found_object.transform,
	// 	cc.is_blocking(data.data.collision_channels),
	// )

	return found_object.handle
}

add_shape_to_hash_map :: proc(
	collision_object_map: ^Collision_Object_Handle_Map,
	spatial_hash_grid: ^map[Hash_Key]Hash_Cell,
	shape: ^Collision_Shape,
	blocking_geo: bool = true,
) -> Collision_Object_Id {
	bounds := get_bounds(shape^)

	collision_object_data := shape_to_collision_object(shape)

	id := add_to_object_map(collision_object_map, collision_object_data)
	add_to_spatial_hash_grid(spatial_hash_grid, collision_object_data, id)

	return id
}
create_and_add_collision_object_from_tris_transform :: proc(
	collision_object_map: ^Collision_Object_Handle_Map,
	spatial_hash_grid: ^Spatial_Hash_Grid,
	tris: [dynamic]Collision_Triangle, // todo this is by ref right???
	transform: Transform,
	blocking: bool = true,
) -> Collision_Object_Id {

	collision_channel: cc.CHANNEL_SIZE =
		blocking ? cc.set_is_blocking({}) : cc.set_is_not_blocking({})
	data := Collision_Object_Data {
		collision_channels = collision_channel,
		transform          = transform,
		tris               = tris,
	}

	collision_object_id := add_to_object_map(collision_object_map, data)
	runtime_data := Collision_Object_Data_Runtime {
		data   = data,
		handle = collision_object_id,
	}

	add_to_spatial_hash_grid(spatial_hash_grid, runtime_data, collision_object_id)

	return collision_object_id
}

add_to_spatial_hash_grid :: proc(
	spatial_hash_grid: ^Spatial_Hash_Grid,
	data: Collision_Object_Data,
	id: Collision_Object_Id,
) {

	bounds := calculate_bounds_from_tris_transform(data.tris, data.transform) // todo defaults to  ref right hehe??
	potential_hash_keys := calculate_overlapping_cells2(bounds)
	for hash_key in potential_hash_keys {
		cell := &spatial_hash_grid[hash_key]
		if cell == nil {
			// fmt.println("Emty cell, creating new one...")
			spatial_hash_grid[hash_key] = {}
			cell = &spatial_hash_grid[hash_key]
		}

		append_elem(&cell.objects_ids, id)
	}
}


add_to_object_map :: proc(
	collision_object_map: ^Collision_Object_Handle_Map,
	data: Collision_Object_Data,
) -> Collision_Object_Id {
	return hms.add(
		collision_object_map,
		Collision_Object_Data_Runtime {
			collision_channels = data.collision_channels,
			tris = data.tris,
			transform = data.transform,
		},
	)
}

add_to_finish_volumes :: proc(
	finish_volumes: ^map[Collision_Object_Id]bool,
	id: Collision_Object_Id,
) {
	finish_volumes[id] = true
}

// TODO: maybe only iteratie thorugh volumes in the active cells
does_location_overlap_finish_volume :: proc(
	finish_volumes: ^map[Collision_Object_Id]bool,
	collision_object_map: ^Collision_Object_Handle_Map,
	location: ^Vector,
) -> Collision_Object_Id {
	for finish_volume_object_id in finish_volumes {
		found_object := hms.get(collision_object_map, finish_volume_object_id)
		assert(found_object != nil)

		if is_inside_object(found_object, location) {
			return finish_volume_object_id
		}
	}

	return INVALID_OBJECT_ID
}

add_to_level :: proc(
	collision_object_map: ^Collision_Object_Handle_Map,
	spatial_hash_grid: ^map[Hash_Key]Hash_Cell,
	collision_object_data: Collision_Object_Data,
) -> Collision_Object_Id {
	id := add_to_object_map(collision_object_map, collision_object_data)
	add_to_spatial_hash_grid(spatial_hash_grid, collision_object_data, id)

	return id
}

create_and_add_collision_object_from_tris :: proc(
	collision_object_map: ^Collision_Object_Handle_Map,
	spatial_hash_grid: ^Spatial_Hash_Grid,
	tris: [dynamic]Collision_Triangle, // todo this is by ref right???
	blocking: bool = true,
) {
	bounds := calculate_bounds_from_tris(tris) // todo defaults to  ref right hehe??

	potential_hash_keys := calculate_overlapping_cells2(bounds)
	collision_channel: cc.CHANNEL_SIZE =
		blocking ? cc.set_is_blocking({}) : cc.set_is_not_blocking({})
	// Adding to handle map
	collision_object_id := hms.add(
		collision_object_map,
		Collision_Object_Data_Runtime {
			collision_channels = collision_channel,
			tris = tris,
			transform = TRANSFORM_IDENTITY,
		},
	)

	for hash_key in potential_hash_keys {
		cell := &spatial_hash_grid[hash_key]
		if cell == nil {
			// fmt.println("Emty cell, creating new one...")
			spatial_hash_grid[hash_key] = {}
			cell = &spatial_hash_grid[hash_key]
		}

		append_elem(&cell.objects_ids, collision_object_id)
	}
}
shape_to_collision_object :: proc(
	shape: ^Collision_Shape,
) -> (
	collision_object_data: Collision_Object_Data,
) {
	tris: [dynamic]Collision_Triangle
	switch &s in shape.shape {
	case Box:
		collision_object_data.tris = box_get_tris(&s, shape)
	case Sphere:
		panic("Not implemented shape_get_collision_tris for Sphere")
	case Cylinder:
		panic("Not implemented shape_get_collision_tris for Cylinder")
	}

	collision_object_data.transform = shape.transform
	collision_object_data.collision_channels = cc.set_is_blocking(1)

	return collision_object_data

}

is_inside_object :: proc(
	collision_object: ^Collision_Object_Data_Runtime,
	location: ^Vector,
) -> bool {
	// If we shoot a ray straight up, that is longer than the longest size of the Bounds. If we hit a odd number of tris, we are inside it.

	bounds: Bound = calculate_bounds_from_tris(collision_object.tris)
	longest_size := linalg.length(bounds.max - bounds.min)
	ray: Ray = make_ray_with_origin_direction_distance(location^, Vector{0, 1, 0}, longest_size)
	hits := ray_trace_object_multi(&ray, collision_object)

	// fmt.printfln("num tris {}", len(collision_object.tris))
	// fmt.printfln("nun hits {}, length of ray {}, bounds {}", len(hits), longest_size, bounds)
	return (len(hits) % 2) == 1
}

ray_trace_object_single :: proc(
	ray: ^Ray,
	collision_object: ^Collision_Object_Data_Runtime,
) -> (
	hit: bool,
	location: Vector,
) {

	for &tri in collision_object.tris {
		if hit, location = ray_triangle_intersect(ray, &tri); hit == true {
			return hit, location
		}
	}

	return hit, location
}

// TODO: Can make more efficient vairants, that preallocates the array.
ray_trace_object_multi :: proc(
	ray: ^Ray,
	collision_object: ^Collision_Object_Data_Runtime,
) -> (
	hits: [dynamic]Vector,
) {
	mat := get_matrix_from_transform(collision_object.transform)
	for tri in collision_object.tris {
		tri := tri

		tri.points.x = (mat * rl.Vector4{tri.points.x.x, tri.points.x.y, tri.points.x.z, 1}).xyz
		tri.points.y = (mat * rl.Vector4{tri.points.y.x, tri.points.y.y, tri.points.y.z, 1}).xyz
		tri.points.z = (mat * rl.Vector4{tri.points.z.x, tri.points.z.y, tri.points.z.z, 1}).xyz
		// TODO: Transform the tri
		if ok, location := ray_triangle_intersect(ray, &tri); ok == true {
			// make sure collision is in front of ray.
			if linalg.dot((location - ray.origin), ray_direction(ray^)) > 0 {
				append_elem(&hits, location)
			}
		}
	}

	return hits
}


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
