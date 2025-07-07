package main

import character "Character"
import p "Physics"
import spat "Spatial"

import "base:builtin"
import intrinsics "base:intrinsics"
import "core:fmt"
import "core:io"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"


main :: proc() {

	test: [dynamic]int = make([dynamic]int)
	append(&test, 4, 97, 7)

	test2: [dynamic]int = make([dynamic]int)
	append(&test2, 1, 2, 3)

	char_data: character.CharacternData
	char_data.current_state = character.Airborne{}


	// key := Hash_Location(&{100.4, 7.9, 8.0})
	// new_location := key_to_corner_location(&key)

	// fmt.println(HASH_CELL_SIZE_METERS)
	// fmt.println(new_location)

	spatial_hash_map := make(map[spat.Hash_Key]spat.Hash_Cell)
	objects: map[spat.Collision_Shape]bool = {}
	i: i32 = {}

	//q := linalg.quaternion_from_forward_and_up_f32({1, 1, 0}, {0, 1, 0.7})
	q := linalg.QUATERNIONF32_IDENTITY
	i += 1
	box := spat.Collision_Shape{i, {{16, 16, 16}, q, {1, 1, 1}}, spat.Box{{10.0, 10.0, 9.0}}}
	spat.add_shape_to_hash_map(&box, &spatial_hash_map)
	objects[box] = true

	i += 1
	box2 := spat.Collision_Shape{i, {{9, 17, 9}, {}, {1, 1, 1}}, spat.Box{{1.0, 1.0, 1.0}}}
	spat.add_shape_to_hash_map(&box2, &spatial_hash_map)
	objects[box2] = true


	i += 1
	sphere1 := spat.Collision_Shape{i, {{17, 6, 9}, {}, {1, 1, 1}}, spat.Sphere{5.0}}
	spat.add_shape_to_hash_map(&sphere1, &spatial_hash_map)
	objects[sphere1] = true

	i += 1
	cylinder1 := spat.Collision_Shape{i, {{-32, 0, 0}, q, {1, 1, 1}}, spat.Cylinder{9.0, 3.0}}
	spat.add_shape_to_hash_map(&cylinder1, &spatial_hash_map)
	objects[cylinder1] = true


	i += 1
	q2 := linalg.quaternion_from_forward_and_up_f32({1, 1, 1}, {1, -1, 1})
	box3 := spat.Collision_Shape{i, {{-32, 0, 0}, q2, {2, 2, 2}}, spat.Box{{9.0, 9.0, 9.0}}}
	//box3 := Collision_Shape{i, {{-32, 0, 0}, q, {2, 2, 2}}, Box{{9.0, 9.0, 9.0}}}
	spat.add_shape_to_hash_map(&box3, &spatial_hash_map)
	objects[box3] = true


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

	rl.SetTargetFPS(180)


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

	tris: [dynamic]spat.Collision_Triangle
	cubes: [dynamic]rl.BoundingBox

	append(&cubes, rl.BoundingBox{})

	append_quad :: proc(
		tris: ^[dynamic]spat.Collision_Triangle,
		a, b, c, d: rl.Vector3,
		offs: rl.Vector3 = {},
	) {
		points := []spat.Collision_Triangle {
			spat.Collision_Triangle{{b + offs, a + offs, c + offs}},
			spat.Collision_Triangle{{b + offs, c + offs, d + offs}},
		}
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

		xz_forward := forward
		xz_forward.y = 0
		xz_forward = linalg.vector_normalize(xz_forward)
		if rl.IsKeyDown(.W) do vel += xz_forward * dt * SPEED
		if rl.IsKeyDown(.S) do vel -= xz_forward * dt * SPEED
		if rl.IsKeyDown(.D) do vel -= right * dt * SPEED
		if rl.IsKeyDown(.A) do vel += right * dt * SPEED

		if rl.IsKeyDown(.E) do vel.y += dt * SPEED
		if rl.IsKeyDown(.Q) do vel.y -= dt * SPEED

		if rl.IsMouseButtonPressed(.LEFT) {

		}

		// gravity
		vel.y -= dt * 30 * (vel.y < 0.0 ? 2 : 1)

		if rl.IsKeyPressed(.SPACE) do vel.y = 15


		// damping
		// vel *= 1.0 / (1.0 + dt * 1.5)

		//get_overlapping_cells(cam.position)
		active_hash_key := spat.Hash_Location(cam.position)
		active_cell := spatial_hash_map[active_hash_key]
		// Collide with cubes / planes

		active_cell_objects := &active_cell.objects

		{
			ray := spat.make_ray_with_origin_end(
				cam.position, //spat.Vector{245, 354, 300},//spat.Vector{245 * 2, 354 * 2, 300 * 2},
				cam.position + linalg.vector_normalize0(cam.target - cam.position) * 100,
			)
			rl.DrawLine3D(ray.origin, ray.end, rl.RED)
			cells := spat.calculate_hashes_by_ray(ray)

			for cell in cells {
				spat.Draw_Hash_Cell_Bounds(cell, rl.RED)
			}


			object_in_ray_path: [dynamic]^spat.Collision_Object = {}
			for hash in cells {
				for &object in spatial_hash_map[hash].objects { 	// I hate this 
					append_elem(&object_in_ray_path, &object)
				}
			}

			for &object in object_in_ray_path {
				for &tri in object.tris {
					if spat.ray_triangle_intersect(&ray, &tri) {
					}
				}
			}
		}


		collide_with_tri :: proc(
			t: ^spat.Collision_Triangle,
			vel: ^spat.Vector,
			cam: ^rl.Camera3D,
		) {
			closest := spat.closest_point_on_triangle(
				cam.position,
				t.points[0],
				t.points[1],
				t.points[2],
			)
			diff := cam.position - closest
			dist := linalg.length(diff)
			normal := diff / dist

			rl.DrawCubeV(closest, 0.05, dist > RAD ? rl.ORANGE : rl.WHITE)

			if dist < RAD {
				cam.position += normal * (RAD - dist)
				// project velocity to the normal plane, if moving towards it
				vel_normal_dot: f32 = linalg.dot(vel^, normal)
				if vel_normal_dot < 0 {
					vel^ -= normal * vel_normal_dot
				}
			}

		}

		// Collide
		for &t in tris {
			collide_with_tri(&t, &vel, &cam)
		}

		for &collision_object in active_cell_objects {

			for &t in collision_object.tris {
				collide_with_tri(&t, &vel, &cam)

			}

		}


		cam.position += vel * dt
		cam.target = cam.position + forward

		draw_collision_tri :: proc(t: ^spat.Collision_Triangle, face_color, edge_color: rl.Color) {
			using t
			rl.DrawTriangle3D(points[0], points[1], points[2], face_color)
			rl.DrawLine3D(points[0], points[1], edge_color)
			rl.DrawLine3D(points[0], points[2], edge_color)
			rl.DrawLine3D(points[1], points[2], edge_color)

		}

		draw_collision_object :: proc(
			collision_object: ^spat.Collision_Object,
			face_color, edge_color: rl.Color,
		) {
			for &t in collision_object.tris {
				draw_collision_tri(&t, face_color, edge_color)
			}
		}

		rl.DrawCubeV(cam.position + forward * 10, 0.25, rl.BLACK)
		for &t in tris {

			draw_collision_tri(&t, rl.LIGHTGRAY, rl.GRAY)
		}

		drawn_collision_objects_ids: map[spat.Collision_Object_Id]bool

		for &collision_object in active_cell_objects {
			has_been_drawn := collision_object.id in drawn_collision_objects_ids
			if (!has_been_drawn) {
				draw_collision_object(&collision_object, rl.GREEN, rl.GRAY)
				drawn_collision_objects_ids[collision_object.id] = true
			}
		}

		// Draw all other geometry
		for hash_key in spatial_hash_map {
			if hash_key == active_hash_key do continue

			cell := &spatial_hash_map[hash_key]
			for &collision_object in cell.objects {
				has_been_drawn := collision_object.id in drawn_collision_objects_ids
				if (!has_been_drawn) {
					draw_collision_object(&collision_object, rl.LIGHTGRAY, rl.GRAY)
					drawn_collision_objects_ids[collision_object.id] = true
				}
			}
		}

		rl.DrawCube({0, 0, 0}, 0.1, 0.1, 0.1, rl.WHITE)
		rl.DrawCube({1, 0, 0}, 1, 0.1, 0.1, rl.RED)
		rl.DrawCube({0, 1, 0}, 0.1, 1, 0.1, rl.GREEN)
		rl.DrawCube({0, 0, 1}, 0.1, 0.1, 1, rl.BLUE)

		hash_key := spat.Hash_Location(
			(spat.Vector{cam.position.x, cam.position.y, cam.position.z}),
		)
		spat.Draw_Hash_Cell_Bounds(
			hash_key,
			// &Vector{cast(f32)hash_key.x, cast(f32)hash_key.y, cast(f32)hash_key.z},
		)

		spat.Draw_Hash_Tree(spatial_hash_map, &hash_key)


		/*
		active_cell_items := spatial_hash_map[hash_key].items

		for shape in objects {
			color := rl.RED
			for active_cell_item in active_cell_items {
				if active_cell_item.id == shape.id {
					color = rl.GREEN
					break
				}
			}

			// draw_collision_shape(shape, &color)
		}

		*/

		rl.EndMode3D()

		rl.DrawFPS(4, 4)

		rl.DrawText(fmt.ctprintf("pos: %v, vel: %v", cam.position, vel), 4, 30, 20, rl.WHITE)

		rl.EndDrawing()
	}
}
