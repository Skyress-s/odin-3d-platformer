package main

import col "color"
import ddu "debug_draw_utils"
import "core:testing"
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
import "lightray"
import gameui "micro-ui"
import mph_ui "mph_ui"
import "player_data"
import rlb "raylib_bridge"

import _players "players"
import "serialization"
import mu "vendor:microui"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"


// global_trace_ctx: trace.Context
//
// debug_trace_assertion_failure_proc :: proc(prefix, message: string, loc := #caller_location) -> ! {
// 	runtime.print_caller_location(loc)
// 	runtime.print_string(" ")
// 	runtime.print_string(prefix)
// 	if len(message) > 0 {
// 		runtime.print_string(": ")
// 		runtime.print_string(message)
// 	}
// 	runtime.print_byte('\n')
//
// 	ctx := &global_trace_ctx
// 	if !trace.in_resolve(ctx) {
// 		buf: [64]trace.Frame
// 		runtime.print_string("Debug Trace:\n")
// 		frames := trace.frames(ctx, 1, buf[:])
// 		for f, i in frames {
// 			fl := trace.resolve(ctx, f, context.temp_allocator)
// 			if fl.loc.file_path == "" && fl.loc.line == 0 {
// 				continue
// 			}
// 			runtime.print_caller_location(fl.loc)
// 			runtime.print_string(" - frame ")
// 			runtime.print_int(i)
// 			runtime.print_byte('\n')
// 		}
// 	}
//
// 	runtime.trap()
// }

// some_type :: distinct union #no_nil {i32, f32}

game_static_shaders :: struct {
	shader_editor_tool_depth: ^rl.Shader,
}

main :: proc() {
	// context.assertion_failure_proc = debug_trace_assertion_failure_proc

	game_state := gs.make_default_game_state()

	players := _players.Players{}

	players.mode = _players.Player_Mode.Game
	players.game = character.CharacternData {
		radius = 1,
		current_state = character.Airborne{},
		verlet_component = verlet.Velocity_Verlet_Component{position = spat.Vector{0, 0, 0}},
	}

	players.editor = editor_player.Editor_Player_Data {
		movement_speed = 30,
	}


	current_level := serialization.load_from_file_level("content/levels/2.I.map")

	character.reset_run(
		&players.game,
		&current_level.start_position,
		&current_level.start_look_direction,
	)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "mph*0.5mv^2")
	//rl.ToggleBorderlessWindowed()
	defer rl.CloseWindow()

	// rl.SetTargetFPS(180)
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

	// position_transform_tool
	players.editor.transform_tool = e_tools.init_transform_tool(
		e_tools.State.Position,
		spat.Plane{spat.Vector{0, 10, 0}, spat.Vector{0, 1, 0}},
		rl.GetMousePosition(),
		&cam,
	)

	position_transform_tool := &players.editor.transform_tool

	character.start_speedrun(&players.game)

	// Shader stuff


	lightray.init_lighting()
	defer lightray.destroy_lighting()

	lightray.create_light(.DIRECTIONAL, {10, 10, 10}, spat.ZERO_VEC3, rl.RAYWHITE)
	{
		// backlight_color := rl.SKYBLUE
		backlight_color := rl.SKYBLUE
		// Color{ 102, 191, 255, 255 }

		lightray.create_light(.DIRECTIONAL, {-10, -10, 10}, spat.ZERO_VEC3, backlight_color)
	}

	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)


		dt := rl.GetFrameTime()

		if ((rl.GetScreenWidth() != gameui.state.screen_width) ||
			   (rl.GetScreenHeight() != gameui.state.screen_height)) {
			gameui.resize_ui()
		}

		gameui.handle_input_micro_ui(&gameui.state.mu_ctx)

		mu.begin(&gameui.state.mu_ctx)
		mph_ui.all_windows(
			&gameui.state.mu_ctx,
			&players,
			&game_state,
			{rl.GetScreenWidth(), rl.GetScreenHeight()},
			&current_level,
		)
		//gameui.all_windows(&gameui.state.mu_ctx, &players, &game_state)
		mu.end(&gameui.state.mu_ctx)
		gameui.render(&gameui.state.mu_ctx)


		// Is our mouse overlapping any widget? (naive implementation)
		mouse_over_ui := false
		for &container in gameui.state.mu_ctx.containers {
			if mu.rect_overlaps_vec2(container.rect, gameui.state.mu_ctx.mouse_pos) &&
			   container.zindex >= 0 { 	// container.zindex >= 0 feels abit hacky
				mouse_over_ui = true
				break
			}
		}
		// time.stopwatch_stop(&timer)
		// fmt.printfln("micro-ui layout time {}", time.duration_microseconds(time.stopwatch_duration(timer)))

		if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) &&
		   position_transform_tool.target_object_id.idx != 0 {
			fmt.printfln("Trying to select an object, mouse_over_ui: {}", mouse_over_ui)

			if !mouse_over_ui {
				if position_transform_tool.dragging == true {
					position_transform_tool.dragging = false
					position_transform_tool.target_object_id =
						spat.notify_object_transform_changed(
							&current_level.collision_object_map,
							&current_level.spatial_hash_grid,
							position_transform_tool.target_object_id,
						)
					//position_transform_tool.target_object_id.idx = 0
				}
			}


		}

		// should we change to another state
		if rl.IsKeyPressed(.F10) || rl.IsKeyPressed(.K) || rl.IsKeyPressed(.Q) {
			switch players.mode {
			case _players.Player_Mode.Game:
				rl.EnableCursor()
				players.editor.position = players.game.verlet_component.position
				players.editor.look_radians = players.game.look_angles

				players.mode = _players.Player_Mode.Editor
				character.pause_speedrun(&players.game)
			case _players.Player_Mode.Editor:
				rl.DisableCursor()

				players.mode = _players.Player_Mode.Game
				character.start_speedrun(&players.game)
			}
		}

		switch players.mode {
		case _players.Player_Mode.Game:
			character.update_character(&players.game, &current_level, &game_state, dt)
		case _players.Player_Mode.Editor:
			if rl.IsKeyPressed(.ONE) {
				position_transform_tool.active_tool = e_tools.Position_Tool{}
			} else if rl.IsKeyPressed(.TWO) {
				position_transform_tool.active_tool = e_tools.Rotation_Tool{}
			} else if rl.IsKeyPressed(.THREE) {
				position_transform_tool.active_tool = e_tools.Scale_Tool{}
			}

			if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) && !mouse_over_ui {
				e_tools.on_click(position_transform_tool, &cam, &current_level)

			}
			if position_transform_tool.target_object_id.idx != 0 {
				if position_transform_tool.dragging {
					e_tools.update_transform_tool(
						position_transform_tool,
						&cam,
						rl.IsMouseButtonPressed(rl.MouseButton.LEFT),
						rl.IsMouseButtonDown(rl.MouseButton.LEFT),
						&current_level.collision_object_map,
						rl.GetMousePosition(),
					)
				}
			}
			editor_player.update(&players.editor, dt)
		}

		overlapping_finish_volume := spat.does_location_overlap_finish_volume(
			&current_level.finish_volumes,
			&current_level.collision_object_map,
			&players.game.verlet_component.position,
		)
		if overlapping_finish_volume != spat.INVALID_OBJECT_ID {
			game_state.finished_level = true
			character.pause_speedrun(&players.game)
			run_time := character.get_current_speedrun_time(&players.game)

			if players.game.best_time > run_time || players.game.best_time == 0 {
				players.game.best_time = run_time
			}
		}

		// Kill volumes
		overlapping_kill_volumes := spat.does_location_overlap_finish_volume(
			&current_level.kill_volumes,
			&current_level.collision_object_map,
			&players.game.verlet_component.position,
		)
		if overlapping_kill_volumes != spat.INVALID_OBJECT_ID {
			character.reset_run(
				&players.game,
				&current_level.start_position,
				&current_level.start_look_direction,
			)
		}

		// TODO we should not hash the location, but the entire shape. So we can overlap two (or 8) cells simultainiusly
		player_bounds := spat.Bound {
			players.game.verlet_component.position - spat.ONE_VEC3 * players.game.radius,
			players.game.verlet_component.position + spat.ONE_VEC3 * players.game.radius,
		}
		player_overlapping_cells := spat.calculate_overlapping_cells2(player_bounds)

		active_hash_key := spat.Hash_Location(players.game.verlet_component.position)
		active_cell := current_level.spatial_hash_grid[active_hash_key]

		// Collide with cubes / planes
		active_cell_objects_ids := &active_cell.objects_ids


		switch players.mode {
		case _players.Player_Mode.Game:
			if !game_state.finished_level {
				verlet.velocity_verlet_leap(&players.game.verlet_component, dt)
				character.update_character_physics(
					&players.game,
					&current_level,
					&player_overlapping_cells,
					dt,
				)
				verlet.velocity_verlet_frog(&players.game.verlet_component, dt)
			}
		case _players.Player_Mode.Editor:
		}

		// assert(
		// 	linalg.length(cam.target - cam.position) > 0,
		// 	"camera target and position should never be equal",
		// )

		// game ui START TODO: If we get some rendering issues, this might be causing some of them?
		// game ui END

		// Update Camera
		switch players.mode {
		case _players.Player_Mode.Game:
			_, forward, right := player_data.calculate_direction_from_look(
				&players.game.look_angles,
			)
			cam.position = players.game.verlet_component.position
			cam.target = cam.position + forward
			cam.up = linalg.cross(forward, right)

		case _players.Player_Mode.Editor:
			_, forward, right := player_data.calculate_direction_from_look(
				&players.editor.look_data,
			)
			cam.position = players.editor.position
			cam.target = cam.position + forward
			cam.up = linalg.cross(forward, right)
		}

		player_loction := players.game.verlet_component.position
		_,player_look_direction,_ := player_data.calculate_direction_from_look(&players.game.look_angles)
		sphere_trace := spat.Sphere_Trace{spat.Ray{origin = player_loction, end = player_loction + player_look_direction * 1000}, 7}
		cells := spat.calculate_hashes_by_sphere_trace(&sphere_trace)

		for key, &cell in &cells {
			key := key
 			locaiton := spat.calculate_hash_cell_width_location(&key)
			ins :ddu.Debug_Draw_Instruction= ddu.Debug_Draw_Wire_Cube_Instruction{location = locaiton, size = spat.HASH_CELL_SIZE, color = col.DARKPURPLE}
			ddu.enqueue_draw_instruction(&ins)

		}


		test : ddu.Debug_Draw_Instruction = ddu.Debug_Draw_Cube_Instruction{location = spat.Vector{5, 0, 0}, rot = spat.QUATERNION_IDENTITY, size = spat.ONE_VEC3 * 5, color = col.DARKBROWN}
		ddu.enqueue_draw_instruction(&test)

		render(
			&current_level,
			&players,
			&cam,
			&player_overlapping_cells,
			active_hash_key,
			&game_state,
		)
	}
}

render :: proc(
	level: ^l.Level,
	players: ^_players.Players,
	cam: ^rl.Camera3D,
	active_cell: ^map[spat.Hash_Key]bool,
	active_cell_hash: spat.Hash_Key,
	game_state: ^gs.Game_State,
) {

	rl.BeginDrawing()
	rl.ClearBackground({40, 30, 50, 255})
	rl.BeginMode3D(cam^)

	@(static) shader_editor_tool_depth: rl.Shader
	if shader_editor_tool_depth.id == 0 do shader_editor_tool_depth = rl.LoadShader("", "content/shaders/editor_tool_depth/depth.frag")
	assert(shader_editor_tool_depth.id != 0)
	view_loc := rl.GetShaderLocation(lightray.lighting.shader, "viewPos")
	rl.SetShaderValue(
		lightray.lighting.shader,
		view_loc,
		&cam.position,
		rlgl.ShaderUniformDataType.VEC3,
	)

	lightray.begin_lighting()
	lightray.set_ambient_light(rl.Color{255, 255, 255, 255}, 0.3)


	tool := &players.editor.transform_tool

	// Draw debug tooltips
	ddu.draw_all_instructions_and_reset()

	switch players.mode {
	case _players.Player_Mode.Game:
		if players.game.is_hooked {
			rl.DrawSphere(players.game.hooked_position, 3, rl.RAYWHITE)
			points: [2]spat.Vector2
		}

	case _players.Player_Mode.Editor:
		_, forward, _ := player_data.calculate_direction_from_look(&players.game.look_angles)
		player_verlet := &players.game.verlet_component

		rl.DrawCylinder(
			player_verlet.position - spat.Vector{0, players.game.radius, 0},
			players.game.radius,
			players.game.radius,
			players.game.radius * 2,
			8,
			rl.GREEN,
		)
		rl.DrawLine3D(player_verlet.position, player_verlet.position + forward * 8, rl.RED)

	}

	// rl.DrawCube(tool.transform.position, 50, 50, 50, rl.MAGENTA)

	player_verlet := &players.game.verlet_component
	player_root_pos_for_drawing := player_verlet.position - spat.Vector{0, 0.1, 0}
	rl.DrawLine3D(
		player_root_pos_for_drawing,
		player_verlet.position + player_verlet.velocity * 0.4,
		rl.ORANGE,
	)

	// Draw rope
	if players.game.is_hooked {
		rl.DrawLine3D(player_root_pos_for_drawing, players.game.hooked_position, rl.VIOLET)
	}


	draw_collision_tri :: proc(
		transform: ^spat.Transform,
		t: ^spat.Collision_Triangle,
		face_color, edge_color: rl.Color,
	) {
		using t
		using transform

		rlgl.PushMatrix()
		// rlgl.Scalef(transform.scale.x,transform.scale.y, transform.scale.z)
		// euler_x, euler_y, euler_z:= linalg.euler_angles_from_quaternion_f32(transform.rotation, linalg.Euler_Angle_Order.XYZ)
		// rlgl.Rotatef(euler_x, 1, 0, 0)
		// rlgl.Rotatef(euler_y, 0, 1, 0)
		// rlgl.Rotatef(euler_z, 0, 0, 1)

		mat := spat.get_matrix_from_transform(transform^)

		transformed_tri := t^

		for &p in transformed_tri.points {
			p4 := mat * spat.Vector4{p.x, p.y, p.z, 1}
			p = p4.xyz
		}

		// rlgl.Translatef(transform.position.x, transform.position.y, transform.position.z)

		// matrix_data := rl.MatrixToFloatV(mat)
		// rlgl.MultMatrixf(auto_cast &matrix_data)

		// normal := linalg.cross(points[0] - points[1], points[2] - points[1])
		// normal_loc := rl.GetShaderLocation(lightray.lighting.shader, "normal")

		// uniform mat4 mvp;
		// uniform mat4 matModel;
		// uniform mat4 matNormal;
		// mat_model_loc := rl.GetShaderLocation(lightray.lighting.shader, "matModel")
		// rl.SetShaderValueMatrix(lightray.lighting.shader, mat_model_loc, rl.Matrix(1))
		//
		// mvp_loc := rl.GetShaderLocation(lightray.lighting.shader, "mvp")
		// rl.SetShaderValueMatrix(lightray.lighting.shader, mvp_loc, rl.Matrix(1))
		//
		// mat_normal_loc := rl.GetShaderLocation(lightray.lighting.shader, "matNormal")
		// rl.SetShaderValueMatrix(lightray.lighting.shader, mat_normal_loc, rl.Matrix(1))


		// TODO Currently we are transforming each point induvidually, indeally we should just have a few meshes, send them 
		// once to the gpu and instance it. But Something goes wrong in the shader with normals if we do that. Needs investigation 

		draw_triangle(
			transformed_tri.points.x,
			transformed_tri.points.y,
			transformed_tri.points.z,
			face_color,
		)

		rl.DrawLine3D(transformed_tri.points.x, transformed_tri.points.y, edge_color)
		rl.DrawLine3D(transformed_tri.points.x, transformed_tri.points.z, edge_color)
		rl.DrawLine3D(transformed_tri.points.y, transformed_tri.points.z, edge_color)
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

	for kill_id in level.kill_volumes {
		drawn_collision_objects_ids[kill_id] = true

		volume_obj := hms.get(&level.collision_object_map, kill_id)
		assert(volume_obj != nil)
		draw_collision_object(volume_obj, rl.RED, rl.GRAY)

	}

	for grappable_obj_id in level.grappable {
		drawn_collision_objects_ids[grappable_obj_id] = true

		volume_obj := hms.get(&level.collision_object_map, grappable_obj_id)
		assert(volume_obj != nil)
		draw_collision_object(volume_obj, rl.SKYBLUE, rl.GRAY)

	}

	for volume_id in level.finish_volumes {
		drawn_collision_objects_ids[volume_id] = true

		volume_obj := hms.get(&level.collision_object_map, volume_id)
		assert(volume_obj != nil)
		draw_collision_object(volume_obj, rl.YELLOW, rl.GRAY)
	}


	if game_state.cheat_state.change_color_when_player_in_cell {
		for cell_key in active_cell {
			for &collision_object_id in level.spatial_hash_grid[cell_key].objects_ids {
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
	lightray.end_lighting()
	rl.BeginShaderMode(shader_editor_tool_depth)

	if players.mode == _players.Player_Mode.Editor {
		found_object := hms.get(&level.collision_object_map, tool.target_object_id)
		if found_object != nil {

			switch &active_tool in tool.active_tool {
			case e_tools.Position_Tool:
				e_tools.draw_position_tooltip_new(
					e_tools.calculate_drag_planes(
						found_object.transform.position,
						players.editor.position,
					),
				)

			case e_tools.Rotation_Tool:
				e_tools.draw_position_tooltip_new(
					e_tools.calculate_drag_planes(
						found_object.transform.position,
						players.editor.position,
					),
				)
			case e_tools.Scale_Tool:
				scale_bars := e_tools.calculate_scale_bars(
					found_object.transform,
					players.editor.position,
				)
				//e_tools.draw_scale_boxes(scale_bars)
				tris := e_tools.scale_bars_to_tris(&scale_bars)

				for &scale_bars_triangles, i in tris {
					color: rl.Color = rl.MAGENTA
					switch i {
					case 0:
						color = rl.RED
					case 1:
						color = rl.GREEN
					case 2:
						color = rl.BLUE
					}

					for &tri in scale_bars_triangles {
						rl.DrawTriangle3D(tri.points.x, tri.points.y, tri.points.z, color)
					}
				}

			// e_tools.draw_scale_boxes(
			// 	e_tools.calculate_scale_bars(found_object.transform, players.editor.position),
			// )

			}
		}

	}
	rl.EndShaderMode()

	rl.EndMode3D()

	// Draw UI babiiiiiii

	gameui.draw_ui()

	rl.EndDrawing()

}

draw_triangle :: proc(a, b, c: spat.Vector, color: rl.Color) {
	rlgl.PushMatrix()
	defer rlgl.PopMatrix()

	normal := linalg.normalize(linalg.cross(b - a, c - a))

	rlgl.Begin(rlgl.TRIANGLES)
	defer rlgl.End()

	rlgl.Color4ub(color.r, color.g, color.b, color.a)

	rlgl.Normal3f(normal.x, normal.y, normal.z)

	rlgl.Vertex3f(a.x, a.y, a.z)
	rlgl.Vertex3f(b.x, b.y, b.z)
	rlgl.Vertex3f(c.x, c.y, c.z)
}

get_default_start_location_look_direction :: proc() -> (location, look_direction: spat.Vector) {

	location = {0, 0, 0}
	look_direction = {1, 0, 0}
	return location, look_direction
}

add_debug_level_objects :: proc(
	level: ^l.Level,
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
		&spat.Collision_Shape {
			{{9, 17, 9}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
			spat.Box{{1.0, 1.0, 1.0}},
		},
	)

	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape {
			{{0, -20, 0}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
			spat.Box{{150.0, 10.0, 150}},
		},
	)

	// spat.add_shape_to_hash_map(
	// 	collision_objects,
	// 	spaital_hash_grid,
	// 	&spat.Collision_Shape{{{17, 6, 9}, {}, {1, 1, 1}}, spat.Sphere{5.0}},
	// )
	//
	// spat.add_shape_to_hash_map(
	// 	collision_objects,
	// 	spaital_hash_grid,
	// 	&spat.Collision_Shape{{{-32, 0, 0}, q, {1, 1, 1}}, spat.Cylinder{9.0, 3.0}},
	// )

	q2 := linalg.quaternion_from_forward_and_up_f32({1, 1, 1}, {1, -1, 1})
	//box3 := Collision_Shape{i, {{-32, 0, 0}, q, {2, 2, 2}}, Box{{9.0, 9.0, 9.0}}}
	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{-32, 0, 0}, q2, {2, 2, 2}}, spat.Box{{9.0, 9.0, 9.0}}},
	)

	for box_num in 0 ..= 5 {
		id := spat.add_shape_to_hash_map(
			collision_objects,
			spaital_hash_grid,
			&spat.Collision_Shape {
				{{cast(f32)(box_num * 90 + 100), 0, 0}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
				spat.Box{{3, 3, 40}},
			},
		)

		level.grappable[id] = true

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

	// Add finish volume
	finish_object_shape := spat.Collision_Shape {
		spat.Transform{spat.Vector{0, -10, 0}, spat.QUATERNION_IDENTITY, spat.ONE_VEC3},
		spat.Box{{4, 4, 4}},
	}
	bounds := spat.get_bounds(finish_object_shape)
	collision_object_data := spat.shape_to_collision_object(&finish_object_shape)
	collision_object_data.collision_channels = cc.get_non_blocking()

	id := spat.add_to_object_map(collision_objects, collision_object_data)
	spat.add_to_spatial_hash_grid(spaital_hash_grid, collision_object_data, id)
	spat.add_to_finish_volumes(&level.finish_volumes, id)
}

@(test)
first_test ::proc(t: ^testing.T){
	testing.expect(t, true)

}

