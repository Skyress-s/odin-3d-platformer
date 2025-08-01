package main

import character "Character"
import p "Physics"
import cc "Physics/collision_channel"
import verlet "Physics/verlet"
import spat "Spatial"
import "base:builtin"
import intrinsics "base:intrinsics"
import "base:runtime"
import "core:debug/trace"
import "core:fmt"
import "core:io"
import "core:math"
import "core:math/linalg"
import hms "handle_map/handle_map_static"
import l "level"
import gameui "micro-ui"
import "serialization"
import mu "vendor:microui"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
/*
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
			}data
			runtime.print_caller_location(fl.loc)
			runtime.print_string(" - frame ")
			runtime.print_int(i)
			runtime.print_byte('\n')
		}
	}
	runtime.trap()
}
*/


main :: proc() {
	// trace.init(&global_trace_ctx)
	// defer trace.destroy(&global_trace_ctx)

	// context.assertion_failure_proc = debug_trace_assertion_failure_proc

	char_data: character.CharacternData = {
		radius = 1,
	}
	char_data.current_state = character.Airborne{}
	char_data.verlet_component.position = spat.Vector{0, 0, 0}

	current_level: l.Level
	current_level.name = "test_level"


	add_debug_level_objects(&current_level.collision_object_map, &current_level.spatial_hash_grid)

	current_level.start_position = {0, 0, 0}
	current_level.start_look_direction = {1, 0, 0}

	serialization.save_to_file_level(&current_level, "test.map")
	loaded_level := serialization.load_from_file_level("test.map")

	current_level = loaded_level
	current_level.start_look_direction = linalg.normalize0(current_level.start_look_direction)

	char_data.look_angles.x = rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "mph*0.5mv^2")
	//rl.ToggleBorderlessWindowed()
	defer rl.CloseWindow()

	rl.SetTargetFPS(180)

	rl.SetWindowSize(rl.GetScreenWidth(), rl.GetScreenHeight())
	rl.DisableCursor()

	gameui.init_game_ui(&gameui.state.mu_ctx)
	defer gameui.deinit_game_ui()

	cam: rl.Camera3D = {
		position   = {5, 1, 5},
		target     = {0, 0, 3},
		up         = {0, 3, 0},
		fovy       = 110,
		projection = .PERSPECTIVE,
	}


	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)
		dt := rl.GetFrameTime()


		character.update_character(&char_data, &current_level, &cam, dt)

		//get_overlapping_cells(cam.position)
		active_hash_key := spat.Hash_Location(cam.position)
		active_cell := current_level.spatial_hash_grid[active_hash_key]

		// Collide with cubes / planes
		active_cell_objects_ids := &active_cell.objects_ids


		verlet.velocity_verlet_leap(&char_data.verlet_component, dt)
		//verlet.velocity_verlet(&char_data.verlet_component, spat.Vector{0, -30, 0}, dt)

		character.update_character_physics(
			&char_data,
			&current_level,
			&cam,
			active_cell_objects_ids,
			dt,
		)

		verlet.velocity_verlet_frog(&char_data.verlet_component, dt)
		assert(
			linalg.length(cam.target - cam.position) > 0,
			"camera target and position should never be equal",
		)

		// game ui START TODO: If we get some rendering issues, this might be causing some of them?
		if ((rl.GetScreenWidth() != gameui.state.screen_width) ||
			   (rl.GetScreenHeight() != gameui.state.screen_height)) {
			gameui.resize_ui()
		}

		gameui.handle_input_micro_ui(&gameui.state.mu_ctx)

		mu.begin(&gameui.state.mu_ctx)
		gameui.all_windows(&gameui.state.mu_ctx, &char_data)
		mu.end(&gameui.state.mu_ctx)
		gameui.render(&gameui.state.mu_ctx)
		// game ui END

		render(&current_level, &char_data, &cam, &active_cell, active_hash_key)

	}
}

render :: proc(
	level: ^l.Level,
	char_data: ^character.CharacternData,
	cam: ^rl.Camera3D,
	active_cell: ^spat.Hash_Cell,
	active_cell_hash: spat.Hash_Key,
) {
	// RENDERING START

	rl.BeginDrawing()
	rl.ClearBackground({40, 30, 50, 255})
	rl.BeginMode3D(cam^)

	// Collide
	if char_data.is_hooked {

		rl.DrawSphere(char_data.hooked_position, 3, rl.RAYWHITE)
	}


	draw_collision_tri :: proc(t: ^spat.Collision_Triangle, face_color, edge_color: rl.Color) {
		using t
		rl.DrawTriangle3D(points[0], points[1], points[2], face_color)
		rl.DrawLine3D(points[0], points[1], edge_color)
		rl.DrawLine3D(points[0], points[2], edge_color)
		rl.DrawLine3D(points[1], points[2], edge_color)
	}


	draw_collision_object :: proc(
		collision_object: ^spat.Collision_Object_Data,
		face_color, edge_color: rl.Color,
	) {
		for &t in collision_object.tris {
			draw_collision_tri(&t, face_color, edge_color)
		}
	}

	drawn_collision_objects_ids: map[spat.Collision_Object_Id]bool


	for &collision_object_id in active_cell.objects_ids {
		has_been_drawn := collision_object_id in drawn_collision_objects_ids
		if (!has_been_drawn) {
			obj: ^spat.Collision_Object_Data = hms.get(
				&level.collision_object_map,
				collision_object_id,
			)
			draw_collision_object(obj, rl.GREEN, rl.GRAY)
			drawn_collision_objects_ids[collision_object_id] = true
		}
	}

	// Draw all other geometry
	for hash_key in level.spatial_hash_grid {
		if hash_key == active_cell_hash do continue

		cell := &level.spatial_hash_grid[hash_key]
		for &collision_object_id in cell.objects_ids {
			has_been_drawn := collision_object_id in drawn_collision_objects_ids
			if (!has_been_drawn) {
				draw_collision_object(
					hms.get(&level.collision_object_map, collision_object_id),
					rl.LIGHTGRAY,
					rl.GRAY,
				)
				drawn_collision_objects_ids[collision_object_id] = true
			}
		}
	}


	// Draw coorinate axis
	rl.DrawCube({0, 0, 0}, 0.1, 0.1, 0.1, rl.WHITE)
	rl.DrawCube({1, 0, 0}, 1, 0.1, 0.1, rl.RED)
	rl.DrawCube({0, 1, 0}, 0.1, 1, 0.1, rl.GREEN)
	rl.DrawCube({0, 0, 1}, 0.1, 0.1, 1, rl.BLUE)

	hash_key := spat.Hash_Location((spat.Vector{cam.position.x, cam.position.y, cam.position.z}))
	spat.Draw_Hash_Cell_Bounds(
		hash_key,
		// &Vector{cast(f32)hash_key.x, cast(f32)hash_key.y, cast(f32)hash_key.z},
	)

	spat.Draw_Hash_Tree(level.spatial_hash_grid, &hash_key)


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

	// Draw UI babiiiiiii

	gameui.draw_ui()

	rl.EndDrawing()

}

get_default_start_location_look_direction :: proc() -> (location, look_direction: spat.Vector) {

	location = {0, 0, 0}
	look_direction = {1, 0, 0}
	return location, look_direction
}

add_debug_level_objects :: proc(
	collision_objects: ^spat.Collision_Object_Handle_Map,
	spaital_hash_grid: ^map[spat.Hash_Key]spat.Hash_Cell,
) {

	q := linalg.QUATERNIONF32_IDENTITY
	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{16, 16, 16}, q, {1, 1, 1}}, spat.Box{{10.0, 10.0, 9.0}}},
	)

	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{9, 17, 9}, {}, {1, 1, 1}}, spat.Box{{1.0, 1.0, 1.0}}},
	)

	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{0, -20, 0}, {}, {1, 1, 1}}, spat.Box{{150.0, 10.0, 150}}},
	)

	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{17, 6, 9}, {}, {1, 1, 1}}, spat.Sphere{5.0}},
	)


	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{-32, 0, 0}, q, {1, 1, 1}}, spat.Cylinder{9.0, 3.0}},
	)

	q2 := linalg.quaternion_from_forward_and_up_f32({1, 1, 1}, {1, -1, 1})
	//box3 := Collision_Shape{i, {{-32, 0, 0}, q, {2, 2, 2}}, Box{{9.0, 9.0, 9.0}}}
	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{-32, 0, 0}, q2, {2, 2, 2}}, spat.Box{{9.0, 9.0, 9.0}}},
	)

	for box_num in 0 ..= 5 {
		spat.add_shape_to_hash_map(
			collision_objects,
			spaital_hash_grid,
			&spat.Collision_Shape {
				{{cast(f32)(box_num * 90 + 100), 0, 0}, {}, {1, 1, 1}},
				spat.Box{{3, 3, 40}},
			},
		)

	}

	tris: [dynamic]spat.Collision_Triangle

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

	spat.create_and_add_collision_object_from_tris(
		collision_objects,
		spaital_hash_grid,
		tris,
		true,
	)
}
