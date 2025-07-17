package main

import character "Character"
import p "Physics"
import spat "Spatial"
import "base:runtime"

import verlet "Physics/verlet"
import "base:builtin"
import intrinsics "base:intrinsics"
import "core:debug/trace"
import "core:fmt"
import "core:io"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

global_trace_ctx: trace.Context

debug_trace_assertion_failure_proc :: proc(prefix, message: string, loc := #caller_location) -> ! {
	runtime.print_caller_location(loc)
	runtime.print_string(" ")
	runtime.print_string(prefix)
	if len(message) > 0 {
		runtime.print_string(": ")
		runtime.print_string(message)
	}
	runtime.print_byte('\n')

	ctx := &global_trace_ctx
	if !trace.in_resolve(ctx) {
		buf: [64]trace.Frame
		runtime.print_string("Debug Trace:\n")
		frames := trace.frames(ctx, 1, buf[:])
		for f, i in frames {
			fl := trace.resolve(ctx, f, context.temp_allocator)
			if fl.loc.file_path == "" && fl.loc.line == 0 {
				continue
			}
			runtime.print_caller_location(fl.loc)
			runtime.print_string(" - frame ")
			runtime.print_int(i)
			runtime.print_byte('\n')
		}
	}
	runtime.trap()
}

main :: proc() {
	trace.init(&global_trace_ctx)
	defer trace.destroy(&global_trace_ctx)

	context.assertion_failure_proc = debug_trace_assertion_failure_proc

	test: [dynamic]int = make([dynamic]int)
	append(&test, 4, 97, 7)

	test2: [dynamic]int = make([dynamic]int)
	append(&test2, 1, 2, 3)

	char_data: character.CharacternData
	char_data.current_state = character.Airborne{}
	char_data.verlet_component.position = spat.Vector{0, 0, 0}

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

	for box_num in 0 ..= 5 {
		i += 1
		grapple_bar_box := spat.Collision_Shape {
			i,
			{{cast(f32)(box_num * 90 + 100), 0, 0}, {}, {1, 1, 1}},
			spat.Box{{3, 3, 40}},
		}
		spat.add_shape_to_hash_map(&grapple_bar_box, &spatial_hash_map)

	}


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


	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "mph*0.5mv^2")
	//rl.ToggleBorderlessWindowed()
	defer rl.CloseWindow()

	rl.SetTargetFPS(180)


	rl.SetWindowSize(rl.GetScreenWidth(), rl.GetScreenHeight())
	rl.DisableCursor()

	cam: rl.Camera3D = {
		position   = {5, 1, 5},
		target     = {0, 0, 3},
		up         = {0, 3, 0},
		fovy       = 110,
		projection = .PERSPECTIVE,
	}

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

	spat.add_collision_object_to_spatial_hash_grid(tris, &spatial_hash_map)

	// spat.add_collision_object_to_spatial_hash_grid()


	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({40, 30, 50, 255})
		rl.BeginMode3D(cam)

		dt := rl.GetFrameTime()


		char_data.look_angles.y -= rl.GetMouseDelta().x * 0.0015 // left and right
		char_data.look_angles.x += rl.GetMouseDelta().y * 0.0015 // up and down
		char_data.look_angles.x = linalg.clamp(
			char_data.look_angles.x,
			-math.PI * 0.499,
			math.PI * 0.499,
		)
		rot, forward, right := character.calculate_stuff_from_look(&char_data)
		cam.position = char_data.verlet_component.position
		cam.target = cam.position + forward
		cam.up = linalg.cross(forward, right)

		SPEED :: 20
		RAD :: 1
		/*
		if rl.IsKeyDown(.W) do player_vel_verlet_comp.velocity += xz_forward * dt * SPEED
		if rl.IsKeyDown(.S) do player_vel_verlet_comp.velocity -= xz_forward * dt * SPEED
		if rl.IsKeyDown(.D) do player_vel_verlet_comp.velocity -= right * dt * SPEED
		if rl.IsKeyDown(.A) do player_vel_verlet_comp.velocity += right * dt * SPEED

		if rl.IsKeyDown(.E) do player_vel_verlet_comp.velocity += dt * SPEED
		if rl.IsKeyDown(.Q) do player_vel_verlet_comp.velocity -= dt * SPEED
		*/

		if rl.IsKeyDown(.R) {
			char_data.verlet_component.position = {1, 5, 1}
			char_data.verlet_component.velocity = {}
			cam.position = char_data.verlet_component.position

		}

		character.handle_input(&char_data, dt)

		if rl.IsMouseButtonPressed(.LEFT) {
			if char_data.is_hooked {
				char_data.is_hooked = false
			} else {
				ray := spat.make_ray_with_origin_direction_distance(
					cam.position,
					linalg.vector_normalize(cam.target - cam.position),
					100.0,
				)
				ok, id, hook_hit_location := spat.ray_intersect_spatial_hash_grid(
					&spatial_hash_map,
					&ray,
				)
				if ok {

					char_data.hooked_position = hook_hit_location
					char_data.is_hooked = true
					char_data.start_distance_to_hook = linalg.distance(
						char_data.hooked_position,
						cam.position,
					)
				}
			}

		}


		// Update character specific stuff
		{
			ray := spat.make_ray_with_origin_direction_distance(
				char_data.verlet_component.position,
				spat.Vector{0, -1, 0},
				RAD + 0.5,
			)

			ok, id, location := spat.ray_intersect_spatial_hash_grid(&spatial_hash_map, &ray)

			if ok {
				char_data.current_state = character.Grounded{10, 50}
			} else {
				char_data.current_state = character.Airborne{10, 30}
			}

		}

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

			ok, id, location := spat.ray_intersect_spatial_hash_grid(&spatial_hash_map, &ray)
			if ok {
				rl.DrawSphere(location, 2.0, rl.YELLOW)
			}

			for cell in cells {
				spat.Draw_Hash_Cell_Bounds(cell, rl.RED)
			}

		}


		collide_with_tri :: proc(
			t: ^spat.Collision_Triangle,
			vel: ^spat.Vector,
			char_data: ^character.CharacternData,
			dt: f32,
		) {
			using char_data

			closest := spat.closest_point_on_triangle(
				verlet_component.position,
				t.points[0],
				t.points[1],
				t.points[2],
			)
			diff := verlet_component.position - closest
			dist := linalg.length(diff)
			normal := diff / dist

			rl.DrawCubeV(closest, 0.05, dist > RAD ? rl.ORANGE : rl.WHITE)

			if dist < RAD {
				verlet_component.position += normal * (RAD - dist)
				// project velocity to the normal plane, if moving towards it
				vel_normal_dot: f32 = linalg.dot(vel^, normal)
				if vel_normal_dot < 0 {
					diff := (vel^ - normal * vel_normal_dot) - verlet_component.velocity
					acceleration := diff / dt
					verlet_component.acceleration += acceleration
					//vel^ -= normal * vel_normal_dot
				}
			}

		}

		// Collide
		/*
		for &t in tris {
			collide_with_tri(&t, &vel, &cam)
		}
		*/
		if char_data.is_hooked {

			rl.DrawSphere(char_data.hooked_position, 3, rl.RAYWHITE)
		}

		verlet.velocity_verlet_leap(&char_data.verlet_component, dt)
		//verlet.velocity_verlet(&char_data.verlet_component, spat.Vector{0, -30, 0}, dt)

		for &collision_object in active_cell_objects {

			for &t in collision_object.tris {
				collide_with_tri(&t, &char_data.verlet_component.velocity, &char_data, dt)
			}

		}

		// Jumping
		_, ok := char_data.current_state.(character.Grounded) // awwwww yes!
		if rl.IsKeyPressed(.SPACE) && ok {

			// char_data.verlet_component.velocity.y = 15
			char_data.verlet_component.acceleration.y += 15 / dt

		}

		// Grappling Hook
		if char_data.is_hooked {
			to_hook := (char_data.hooked_position - char_data.verlet_component.position)
			direction_to_hook := linalg.vector_normalize(to_hook)
			distance := linalg.distance(char_data.hooked_position, cam.position)
			if distance > char_data.start_distance_to_hook {
				distance_over_max := (distance - char_data.start_distance_to_hook)
				distance_over_max = max(distance_over_max, 0.0)


				// huh, this is shit
				right := linalg.vector_cross3(
					char_data.verlet_component.velocity,
					direction_to_hook,
				)
				hook_forward := linalg.vector_cross3(direction_to_hook, right)
				hook_forward = linalg.vector_normalize(hook_forward)


				new_vel_length := linalg.vector_dot(
					char_data.verlet_component.velocity,
					hook_forward,
				)

				// Should we lose momentum or not? Kinda hacky atm.
				target_velocity: spat.Vector
				if new_vel_length < linalg.length(char_data.verlet_component.velocity) * 0.8 {
					//char_data.verlet_component.velocity = hook_forward * new_vel_length
					target_velocity = hook_forward * new_vel_length
				} else {
					//char_data.verlet_component.velocity =
					//hook_forward * linalg.length(char_data.verlet_component.velocity)
					target_velocity =
						hook_forward * linalg.length(char_data.verlet_component.velocity)
				}
				acc := (target_velocity - char_data.verlet_component.velocity) / dt
				char_data.verlet_component.acceleration += acc
				// Enegry is now conserved, but its quite hard coded
				// verlet intergration is supposed to conserve energy, will try to use that for this project perhaps?
				// what i want in a ideal world:
				// - [C]ontinous [C]ollision [D]etection
				// - Energy is conserverd
			} else if distance * 0.995 < char_data.start_distance_to_hook {
				char_data.start_distance_to_hook = distance
			}

		}

		// Add gravity
		char_data.verlet_component.acceleration += {0, -30, 0}

		verlet.velocity_verlet_frog(&char_data.verlet_component, dt)
		assert(
			linalg.length(cam.target - cam.position) > 0,
			"camera target and position should never be equal",
		)

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

		/*
		for &t in tris {

			draw_collision_tri(&t, rl.LIGHTGRAY, rl.GRAY)
		}
		*/
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

		debug_text_row_spacing: i32 = 30
		rl.DrawText(
			fmt.ctprintf("pos: %v, vel: %v", cam.position, char_data.verlet_component.velocity),
			4,
			debug_text_row_spacing,
			20,
			rl.WHITE,
		)
		rl.DrawText(
			fmt.ctprintf("velocity: %f", linalg.length(char_data.verlet_component.velocity)),
			4,
			debug_text_row_spacing * 2,
			20,
			rl.WHITE,
		)
		{
			vel_xz := char_data.verlet_component.velocity
			vel_xz.y = 0
			rl.DrawText(
				fmt.ctprintf("velocity_xz: %f", linalg.length(vel_xz)),
				4,
				debug_text_row_spacing * 3,
				20,
				rl.WHITE,
			)
		}

		rl.DrawText(
			fmt.ctprintf("%v", char_data.current_state),
			4,
			debug_text_row_spacing * 4,
			20,
			rl.WHITE,
		)

		{
			// Total energy of the player
			m: f32 = 0.01
			potential_energy := m * 30.0 * (char_data.verlet_component.position.y + 50.0)
			kinetic_energy :=
				0.5 *
				m *
				linalg.length(char_data.verlet_component.velocity) *
				linalg.length(char_data.verlet_component.velocity)
			total_energy := potential_energy + kinetic_energy
			rl.DrawText(
				fmt.ctprintf("Potential: {}", potential_energy),
				4,
				debug_text_row_spacing * 5,
				20,
				rl.WHITE,
			)
			rl.DrawText(
				fmt.ctprintf("Kinetic: {}", kinetic_energy),
				4,
				debug_text_row_spacing * 6,
				20,
				rl.WHITE,
			)
			rl.DrawText(
				fmt.ctprintf("Total: {}", total_energy),
				4,
				debug_text_row_spacing * 7,
				20,
				rl.WHITE,
			)
		}

		rl.EndDrawing()
	}
}
