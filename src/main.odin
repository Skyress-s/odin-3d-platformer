package main

import intrinsics "base:intrinsics"
import "core:fmt"
import "core:io"
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


Hash_Cell :: struct {
	items: [dynamic]^Collision_Shape,
}

Hash_Int :: i32

HASH_CELL_SIZE_METERS :: 1 << 4 // 128

MAX_WORLD_LOCATION :: f32(max(Hash_Int)) * f32(HASH_CELL_SIZE_METERS)

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

Draw_Hash_Cell_Bounds :: proc(vec: Hash_Key) {
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

Hash_Location :: proc(vec: Vector) -> (ret_val: Hash_Key) {
	ret_val.x = cast(Hash_Int)(math.floor(vec.x / cast(f32)HASH_CELL_SIZE_METERS))
	ret_val.y = cast(Hash_Int)(math.floor(vec.y / cast(f32)HASH_CELL_SIZE_METERS))
	ret_val.z = cast(Hash_Int)(math.floor(vec.z / cast(f32)HASH_CELL_SIZE_METERS))
	return
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

get_bounds :: proc(collision_shape: Collision_Shape) -> (bound: Bound) { 	// Todo reference

	using collision_shape.transform
	srtMatrix := get_matrix_from_transform(collision_shape.transform)

	switch shape in collision_shape.shape {
	case Box:
		// vec1trans := srtMatrix * {vec1.x, vec1.y, vec1.z, 1.0}
		using shape
		x := size.x / 2.0
		y := size.y / 2.0
		z := size.z / 2.0
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
		fmt.println("njahahaha")
	}
	return
}

add_shape_to_hash_map :: proc(shape: ^Collision_Shape, hash_map: ^map[Hash_Key]Hash_Cell) {
	bounds := get_bounds(shape^)
	hash_keys := get_overlapping_cells(bounds)
	fmt.println("overlapping cells: ", len(hash_keys), "hash keys: ", hash_keys)

	for hash_key in hash_keys {
		cell := &hash_map[hash_key]
		if cell == nil {
			// fmt.println("Emty cell, creating new one...")
			hash_map[hash_key] = {}
			cell = &hash_map[hash_key]
		}
		fmt.println("adding element to hash cell: ", hash_key, " | ", cell)
		append_elem(&cell.items, shape)
	}
}

main :: proc() {


	// key := Hash_Location(&{100.4, 7.9, 8.0})
	// new_location := key_to_corner_location(&key)

	// fmt.println(HASH_CELL_SIZE_METERS)
	// fmt.println(new_location)

	spatial_hash_map := make(map[Hash_Key]Hash_Cell)
	objects: map[Collision_Shape]bool = {}
	i: i32 = {}

	q := linalg.quaternion_from_forward_and_up_f32({1, 1, 0}, {0, 1, 0.7})
	// q := linalg.QUATERNIONF32_IDENTITY
	i += 1
	box := Collision_Shape{i, {{16, 16, 16}, q, {1, 1, 1}}, Box{{10.0, 10.0, 9.0}}}
	add_shape_to_hash_map(&box, &spatial_hash_map)
	objects[box] = true

	i += 1
	box2 := Collision_Shape{i, {{9, 17, 9}, {}, {1, 1, 1}}, Box{{1.0, 1.0, 1.0}}}
	add_shape_to_hash_map(&box2, &spatial_hash_map)
	objects[box2] = true


	i += 1
	sphere1 := Collision_Shape{i, {{17, 6, 9}, {}, {1, 1, 1}}, Sphere{5.0}}
	add_shape_to_hash_map(&sphere1, &spatial_hash_map)
	objects[sphere1] = true

	i += 1
	cylinder1 := Collision_Shape{i, {{-32, 0, 0}, q, {1, 1, 1}}, Cylinder{9.0, 3.0}}
	add_shape_to_hash_map(&cylinder1, &spatial_hash_map)
	objects[cylinder1] = true

	/*
	i += 1
	box2 := Collision_Shape{i, {{9, 17, 9}, {}, {1, 1, 1}}, Box{{1.0, 1.0, 1.0}}}
	add_shape_to_hash_map(&box2, &spatial_hash_map)
	objects[box2] = true

	i += 1
	sphere1 := Collision_Shape{i, {{17, 6, 9}, {}, {1, 1, 1}}, Sphere{5.0}}
	add_shape_to_hash_map(&sphere1, &spatial_hash_map)
	objects[sphere1] = true

	i += 1
	cylinder1 := Collision_Shape{i, {{0, 0, 0}, {}, {1, 1, 1}}, Cylinder{5.0, 3.0}}
	add_shape_to_hash_map(&cylinder1, &spatial_hash_map)
	objects[cylinder1] = true
	*/


	/*
	spatial_hash_tree[Hash_Location(&box.transform.translation)] = {}

	mapp := &spatial_hash_tree[Hash_Location(&box.transform.translation)]
	append_elem(&mapp.items, &box)
	*/
	// fmt.println("test", cell)


	// spatial_hash_tree[Hash_Location(&{0, 0, 0})] = {}
	//spatial_hash_tree[Hash_Location(&{0, 2, 4})] = {}
	// spatial_hash_tree[Hash_Location_For_Cell(&{1,1,9})] = }

	fmt.println(spatial_hash_map)


	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(800, 600, "mph*0.5mv^2")
	defer rl.CloseWindow()


	rl.SetWindowSize(rl.GetScreenWidth(), rl.GetScreenHeight())
	rl.DisableCursor()

	look_angles: rl.Vector2 = 0
	cam: rl.Camera3D = {
		position   = {5, 1, 5},
		target     = {0, 0, 3},
		up         = {0, 3, 0},
		fovy       = 90,
		projection = .PERSPECTIVE,
	}
	vela: linalg.Vector3f16 = {1, 2, 3}

	vel: rl.Vector3

	tris: [dynamic][3]rl.Vector3
	cubes: [dynamic]rl.BoundingBox

	append(&cubes, rl.BoundingBox{})

	append_quad :: proc(
		tris: ^[dynamic][3]rl.Vector3,
		a, b, c, d: rl.Vector3,
		offs: rl.Vector3 = {},
	) {
		points := [][3]rl.Vector3{{b + offs, a + offs, c + offs}, {b + offs, c + offs, d + offs}}
		append(tris, ..points)
	}

	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 0})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 10})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 0, 10})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 10, 10}, {10, 10, 10}, {10, 0, 20})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 10, 30})

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({40, 30, 50, 255})
		rl.BeginMode3D(cam)

		dt := rl.GetFrameTime()

		rot :=
			linalg.quaternion_from_euler_angle_y_f32(look_angles.y) *
			linalg.quaternion_from_euler_angle_x_f32(look_angles.x)

		forward := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
		right := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})

		look_angles.y -= rl.GetMouseDelta().x * 0.0015
		look_angles.x += rl.GetMouseDelta().y * 0.0015

		SPEED :: 20
		RAD :: 1

		if rl.IsKeyDown(.W) do vel += forward * dt * SPEED
		if rl.IsKeyDown(.S) do vel -= forward * dt * SPEED
		if rl.IsKeyDown(.D) do vel -= right * dt * SPEED
		if rl.IsKeyDown(.A) do vel += right * dt * SPEED

		if rl.IsKeyDown(.E) do vel.y += dt * SPEED
		if rl.IsKeyDown(.Q) do vel.y -= dt * SPEED

		// gravity
		vel.y -= dt * 30 * (vel.y < 0.0 ? 2 : 1)

		if rl.IsKeyPressed(.SPACE) do vel.y = 15

		// damping
		// vel *= 1.0 / (1.0 + dt * 1.5)

		// Collide
		for t in tris {
			closest := closest_point_on_triangle(cam.position, t[0], t[1], t[2])
			diff := cam.position - closest
			dist := linalg.length(diff)
			normal := diff / dist

			rl.DrawCubeV(closest, 0.05, dist > RAD ? rl.ORANGE : rl.WHITE)

			if dist < RAD {
				cam.position += normal * (RAD - dist)
				// project velocity to the normal plane, if moving towards it
				vel_normal_dot := linalg.dot(vel, normal)
				if vel_normal_dot < 0 {
					vel -= normal * vel_normal_dot
				}
			}
		}

		// Collide with cubes / planes


		cam.position += vel * dt
		cam.target = cam.position + forward

		rl.DrawCubeV(cam.position + forward * 10, 0.25, rl.BLACK)
		for t in tris {
			rl.DrawTriangle3D(t[0], t[1], t[2], rl.GRAY)
			rl.DrawLine3D(t[0], t[1], rl.LIGHTGRAY)
			rl.DrawLine3D(t[0], t[2], rl.LIGHTGRAY)
			rl.DrawLine3D(t[1], t[2], rl.LIGHTGRAY)
		}

		rl.DrawCube({0, 0, 0}, 0.1, 0.1, 0.1, rl.WHITE)
		rl.DrawCube({1, 0, 0}, 1, 0.1, 0.1, rl.RED)
		rl.DrawCube({0, 1, 0}, 0.1, 1, 0.1, rl.GREEN)
		rl.DrawCube({0, 0, 1}, 0.1, 0.1, 1, rl.BLUE)

		hash_key := Hash_Location((Vector{cam.position.x, cam.position.y, cam.position.z}))
		Draw_Hash_Cell_Bounds(
			hash_key,
			// &Vector{cast(f32)hash_key.x, cast(f32)hash_key.y, cast(f32)hash_key.z},
		)

		Draw_Hash_Tree(spatial_hash_map, &hash_key)

		active_cell_items := spatial_hash_map[hash_key].items

		for shape in objects {
			color := rl.RED
			for active_cell_item in active_cell_items {
				if active_cell_item.id == shape.id {
					color = rl.GREEN
					break
				}
			}

			draw_collision_shape(shape, &color)
		}


		rl.EndMode3D()

		rl.DrawFPS(4, 4)

		rl.DrawText(fmt.ctprintf("pos: %v, vel: %v", cam.position, vel), 4, 30, 20, rl.WHITE)

		rl.EndDrawing()
	}
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
