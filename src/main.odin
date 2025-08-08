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
import e_tools "editor/tools"
import "editor_player"
import gs "game_state"
import hms "handle_map/handle_map_static"
import l "level"
import gameui "micro-ui"
import "player_data"
import rlb "raylib_bridge"

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

Player_Mode :: enum {
	Game,
	Editor,
}

//fmt.printfln("{:6.3f} ", some_var) // [0.5, 3.0, 6.5]

main :: proc() {
	game_state := gs.make_default_game_state()

	player_mode := Player_Mode.Game
	player_game := character.CharacternData {
		radius = 1,
	}
	player_editor := editor_player.Editor_Player_Data {
		movement_speed = 30,
	}

	player_game.current_state = character.Airborne{}
	player_game.verlet_component.position = spat.Vector{0, 0, 0}

	current_level: l.Level
	current_level.name = "test_level"


	add_debug_level_objects(&current_level.collision_object_map, &current_level.spatial_hash_grid)

	current_level.start_position = {0, 0, 0}
	current_level.start_look_direction = {1, 0, 1}

	serialization.save_to_file_level(&current_level, "test.map")
	loaded_level := serialization.load_from_file_level("test.map")

	current_level = loaded_level
	current_level.start_position = loaded_level.start_position
	current_level.start_look_direction = linalg.normalize0(loaded_level.start_look_direction)

	// Set look angles
	player_game.look_angles.x = -math.asin(current_level.start_look_direction.y)
	player_game.look_angles.y = linalg.vector_angle_between(
		spat.Vector{0, 0, 1},
		current_level.start_look_direction,
	)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
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

	position_transform_tool := e_tools.init_transform_tool(
		e_tools.State.Position,
		spat.Plane{spat.Vector{0, 10, 0}, spat.Vector{0, 1, 0}},
		rl.GetMousePosition(),
		&cam,
	)

	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)
		dt := rl.GetFrameTime()


		if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) &&
		   position_transform_tool.target_object_id.idx != 0 { 	// TODO: Is there a null id?

			if position_transform_tool.dragging == true {
				position_transform_tool.dragging = false
				position_transform_tool.target_object_id = spat.notify_object_transform_changed(
					&current_level.collision_object_map,
					&current_level.spatial_hash_grid,
					position_transform_tool.target_object_id,
				)
				//position_transform_tool.target_object_id.idx = 0
			}

		}

		// should we change to another state
		if rl.IsKeyPressed(.F10) {
			switch player_mode {
			case Player_Mode.Game:
				rl.EnableCursor()
				player_editor.position = player_game.verlet_component.position
				player_editor.look_radians = player_game.look_angles

				player_mode = Player_Mode.Editor
			case Player_Mode.Editor:
				rl.DisableCursor()

				player_mode = Player_Mode.Game
			}
		}

		switch player_mode {
		case Player_Mode.Game:
			character.update_character(&player_game, &current_level, dt)
		case Player_Mode.Editor:
			if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {

				ray := rlb.convert_ray(rl.GetScreenToWorldRay(rl.GetMousePosition(), cam))
				ray.end = ray.origin + (ray.end - ray.origin) * 1000 // augh


				found_object := hms.get(
					&current_level.collision_object_map,
					position_transform_tool.target_object_id,
				)
				if found_object != nil {
					planes := e_tools.calculate_drag_planes(
						found_object.transform.position,
						cam.position,
					)
					plane_hit, plane_intersect_location, plane_normal :=
						e_tools.ray_transform_tool_planes_intersect(&ray, &planes)
					if plane_hit != e_tools.Interacted_Plane.None {
						fmt.printfln("{:5.f} {}", rl.GetTime(), plane_hit)

						rl.DrawCube(plane_intersect_location, 5, 5, 5, rl.WHITE)

					}
					if plane_hit != .None {
						position_transform_tool.dragging = true
						position_transform_tool.plane.point_on_plane = plane_intersect_location
						position_transform_tool.plane.normal = plane_normal
						position_transform_tool.start_transform = found_object.transform

						//continue
					} else do position_transform_tool.target_object_id = spat.Collision_Object_Id{}

				} else {
					ok, id, position := spat.ray_intersect_spatial_hash_grid(
						&current_level.spatial_hash_grid,
						&current_level.collision_object_map,
						&ray,
					)


					if ok {
						position_transform_tool.target_object_id = id
						position_transform_tool.start_transform =
							hms.get(&current_level.collision_object_map, id).data.transform

						hit_plane, hit_location := spat.ray_plane_intersect(
							&ray,
							{0, 1, 0},
							{0, 10, 0},
						)

						position_transform_tool.start_ray_plane_intersect = hit_location
					}

				}

			}


			if position_transform_tool.target_object_id.idx != 0 {
				// found_object := hms.get(&current_level.collision_object_map, position_transform_tool.target_object_id)
				// ray := rlb.convert_ray(rl.GetScreenToWorldRay(rl.GetMousePosition(), cam))
				// ray.end = ray.origin + (ray.end - ray.origin) * 1000 // augh

				// planes:=e_tools.calculate_drag_planes(found_object.transform.position, cam.position)
				// plane_hit, plane_intersect_location:= e_tools.ray_transform_tool_planes_intersect(&ray, &planes)
				// if plane_hit != e_tools.Interacted_Plane.None {
				// 	fmt.printfln("{:5.f} {}", rl.GetTime(), plane_hit)
				//
				//
				// }

				if position_transform_tool.dragging {
					e_tools.update_transform_tool(
						&position_transform_tool,
						&cam,
						rl.IsMouseButtonPressed(rl.MouseButton.LEFT),
						rl.IsMouseButtonDown(rl.MouseButton.LEFT),
						&current_level.collision_object_map,
						rl.GetMousePosition(),
					)
				}

			}
			editor_player.update(&player_editor, dt)
		}

		active_hash_key := spat.Hash_Location(player_game.verlet_component.position)
		active_cell := current_level.spatial_hash_grid[active_hash_key]

		// Collide with cubes / planes
		active_cell_objects_ids := &active_cell.objects_ids


		switch player_mode {
		case Player_Mode.Game:
			verlet.velocity_verlet_leap(&player_game.verlet_component, dt)
			character.update_character_physics(
				&player_game,
				&current_level,
				active_cell_objects_ids,
				dt,
			)
			verlet.velocity_verlet_frog(&player_game.verlet_component, dt)
		case Player_Mode.Editor:
		}

		// assert(
		// 	linalg.length(cam.target - cam.position) > 0,
		// 	"camera target and position should never be equal",
		// )

		// game ui START TODO: If we get some rendering issues, this might be causing some of them?
		if ((rl.GetScreenWidth() != gameui.state.screen_width) ||
			   (rl.GetScreenHeight() != gameui.state.screen_height)) {
			gameui.resize_ui()
		}

		gameui.handle_input_micro_ui(&gameui.state.mu_ctx)

		mu.begin(&gameui.state.mu_ctx)
		gameui.all_windows(&gameui.state.mu_ctx, &player_game, &game_state)
		mu.end(&gameui.state.mu_ctx)
		gameui.render(&gameui.state.mu_ctx)
		// game ui END

		// Update Camera
		switch player_mode {
		case Player_Mode.Game:
			_, forward, right := player_data.calculate_stuff_from_look(&player_game.look_angles)
			cam.position = player_game.verlet_component.position
			cam.target = cam.position + forward
			cam.up = linalg.cross(forward, right)

		case Player_Mode.Editor:
			_, forward, right := player_data.calculate_stuff_from_look(&player_editor.look_data)
			cam.position = player_editor.position
			cam.target = cam.position + forward
			cam.up = linalg.cross(forward, right)
		}
		render(
			&current_level,
			player_mode,
			&player_game,
			&player_editor,
			&cam,
			&active_cell,
			active_hash_key,
			&position_transform_tool,
			&game_state,
		)

	}
}

render :: proc(
	level: ^l.Level,
	player_mode: Player_Mode,
	char_data: ^character.CharacternData,
	player_editor: ^editor_player.Editor_Player_Data,
	cam: ^rl.Camera3D,
	active_cell: ^spat.Hash_Cell,
	active_cell_hash: spat.Hash_Key,
	tool: ^e_tools.Transform_Tool_Data,
	game_state: ^gs.Game_State,
) {
	rl.BeginDrawing()
	rl.ClearBackground({40, 30, 50, 255})
	rl.BeginMode3D(cam^)


	switch player_mode {
	case Player_Mode.Game:
		if char_data.is_hooked {
			rl.DrawSphere(char_data.hooked_position, 3, rl.RAYWHITE)
			points: [2]spat.Vector2
		}

	case Player_Mode.Editor:
		_, forward, _ := player_data.calculate_stuff_from_look(&char_data.look_angles)
		player_verlet := &char_data.verlet_component

		rl.DrawCylinder(
			player_verlet.position - spat.Vector{0, char_data.radius, 0},
			char_data.radius,
			char_data.radius,
			char_data.radius * 2,
			8,
			rl.GREEN,
		)
		rl.DrawLine3D(player_verlet.position, player_verlet.position + forward * 8, rl.RED)

		found_object := hms.get(&level.collision_object_map, tool.target_object_id)
		if found_object != nil {
			//
			// ray := rlb.convert_ray(rl.GetScreenToWorldRay(rl.GetMousePosition(), cam^))
			// ray.end = ray.origin + (ray.end - ray.origin) * 1000 // augh
			//
			// planes:=e_tools.calculate_drag_planes(found_object.transform.position, cam.position)
			// plane_hit, plane_intersect_location:= e_tools.ray_transform_tool_planes_intersect(&ray, &planes)
			// if plane_hit != e_tools.Interacted_Plane.None {
			// 	fmt.printfln("{:5.f} {}", rl.GetTime(), plane_hit)
			//
			// 	rl.DrawCube(plane_intersect_location, 5,5,5, rl.WHITE)
			//
			// }
			e_tools.draw_position_tooltip_new(
				e_tools.calculate_drag_planes(
					found_object.transform.position,
					player_editor.position,
				),
			)
		}
	}

	// rl.DrawCube(tool.transform.position, 50, 50, 50, rl.MAGENTA)

	player_verlet := &char_data.verlet_component
	player_root_pos_for_drawing := player_verlet.position - spat.Vector{0, 0.1, 0}
	rl.DrawLine3D(
		player_root_pos_for_drawing,
		player_verlet.position + player_verlet.velocity * 0.4,
		rl.ORANGE,
	)

	// Draw rope
	if char_data.is_hooked {
		rl.DrawLine3D(player_root_pos_for_drawing, char_data.hooked_position, rl.VIOLET)
	}


	draw_collision_tri :: proc(
		transform: ^spat.Transform,
		t: ^spat.Collision_Triangle,
		face_color, edge_color: rl.Color,
	) {
		using t
		using transform

		rlgl.PushMatrix()
		mat := spat.get_matrix_from_transform(transform^)
		matrix_data := rl.MatrixToFloatV(mat)
		rlgl.MultMatrixf(auto_cast &matrix_data)

		rl.DrawTriangle3D(points[0], points[1], points[2], face_color)
		rl.DrawLine3D(points[0], points[1], edge_color)
		rl.DrawLine3D(points[0], points[2], edge_color)
		rl.DrawLine3D(points[1], points[2], edge_color)
		rlgl.PopMatrix()
	}


	draw_collision_object :: proc(
		collision_object: ^spat.Collision_Object_Data,
		face_color, edge_color: rl.Color,
	) {
		for &t in collision_object.tris {
			draw_collision_tri(&collision_object.transform, &t, face_color, edge_color)
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


	if game_state.cheat_state.draw_bounds {
		hash_key := spat.Hash_Location(player_verlet.position)
		spat.Draw_Hash_Cell_Bounds(hash_key)
		spat.draw_hash_grid_bounds_populated_cells(level.spatial_hash_grid, &hash_key)}


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

	q_raw := linalg.QUATERNIONF32_IDENTITY
	q := spat.QuaternionData{q_raw.x, q_raw.y, q_raw.z, q_raw.w}


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
		&spat.Collision_Shape {
			{{-32, 0, 0}, spat.QuaternionData{q2.x, q2.y, q2.z, q2.w}, {2, 2, 2}},
			spat.Box{{9.0, 9.0, 9.0}},
		},
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
