package game

import "core:time"
import character "../Character"
import col "../color"
import hms "../handle_map/handle_map_static"
import "../render"

import verlet "../Physics/verlet"
import spat "../Spatial"
import ddu "../debug_draw_utils/"
import "../editor_player"
import gs "../game_state"
import l "../level"
import gameui "../micro-ui/"
import "../mph_ui/"
import "../player_data"
import plrs "../players"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import mu "vendor:microui"
import rl "vendor:raylib"

import e_tools "../editor/tools"

update :: proc(gc: ^Global_Context) -> (debug_draw_data: render.Debug_Draw_Data) {
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
		gc.players,
		gc.game_state,
		{rl.GetScreenWidth(), rl.GetScreenHeight()},
		gc.current_level,
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

	position_transform_tool := &gc.players.editor.transform_tool

	if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) &&
	   position_transform_tool.target_object_id.idx != 0 {
		fmt.printfln("Trying to select an object, mouse_over_ui: {}", mouse_over_ui)

		if !mouse_over_ui {
			if position_transform_tool.dragging == true {
				position_transform_tool.dragging = false
				position_transform_tool.target_object_id = spat.notify_object_transform_changed(
					&gc.current_level.collision_object_map,
					&gc.current_level.spatial_hash_grid,
					position_transform_tool.target_object_id,
				)
				//position_transform_tool.target_object_id.idx = 0
			}
		}


	}

	// should we change to another state
	if rl.IsKeyPressed(.F10) || rl.IsKeyPressed(.K) || rl.IsKeyPressed(.Q) {
		switch gc.players.mode {
		case plrs.Player_Mode.Game:
			rl.EnableCursor()
			gc.players.editor.position = gc.players.game.verlet_component.position
			gc.players.editor.look_radians = gc.players.game.look_angles

			gc.players.mode = plrs.Player_Mode.Editor
			character.pause_speedrun(&gc.players.game)
		case plrs.Player_Mode.Editor:
			rl.DisableCursor()

			gc.players.mode = plrs.Player_Mode.Game
			character.start_speedrun(&gc.players.game)
		}
	}

	switch gc.players.mode {
	case plrs.Player_Mode.Game:
		character.update_character(&gc.players.game, gc.current_level, gc.game_state, dt)
	case plrs.Player_Mode.Editor:
		if rl.IsKeyPressed(.ONE) {
			position_transform_tool.active_tool = e_tools.Position_Tool{}
		} else if rl.IsKeyPressed(.TWO) {
			position_transform_tool.active_tool = e_tools.Rotation_Tool{}
		} else if rl.IsKeyPressed(.THREE) {
			position_transform_tool.active_tool = e_tools.Scale_Tool{}
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) && !mouse_over_ui {
			e_tools.on_click(position_transform_tool, gc.cam, gc.current_level)

		}
		if position_transform_tool.target_object_id.idx != 0 {
			if position_transform_tool.dragging {
				e_tools.update_transform_tool(
					position_transform_tool,
					gc.cam,
					rl.IsMouseButtonPressed(rl.MouseButton.LEFT),
					rl.IsMouseButtonDown(rl.MouseButton.LEFT),
					&gc.current_level.collision_object_map,
					rl.GetMousePosition(),
				)
			}
		}
		editor_player.update(&gc.players.editor, dt)
	}

	overlapping_finish_volume := spat.does_location_overlap_finish_volume(
		&gc.current_level.finish_volumes,
		&gc.current_level.collision_object_map,
		&gc.players.game.verlet_component.position,
	)
	if overlapping_finish_volume != spat.INVALID_OBJECT_ID {
		gc.game_state.finished_level = true
		character.pause_speedrun(&gc.players.game)
		run_time := character.get_current_speedrun_time(&gc.players.game)

		if gc.players.game.best_time > run_time || gc.players.game.best_time == 0 {
			gc.players.game.best_time = run_time
		}
	}

	// Kill volumes
	overlapping_kill_volumes := spat.does_location_overlap_finish_volume(
		&gc.current_level.kill_volumes,
		&gc.current_level.collision_object_map,
		&gc.players.game.verlet_component.position,
	)
	if overlapping_kill_volumes != spat.INVALID_OBJECT_ID {
		character.reset_run(
			&gc.players.game,
			&gc.current_level.start_position,
			&gc.current_level.start_look_direction,
		)
	}

	// TODO we should not hash the location, but the entire shape. So we can overlap two (or 8) cells simultainiusly
	player_bounds := spat.Bound {
		gc.players.game.verlet_component.position - spat.ONE_VEC3 * gc.players.game.radius,
		gc.players.game.verlet_component.position + spat.ONE_VEC3 * gc.players.game.radius,
	}
	player_overlapping_cells := spat.calculate_overlapping_cells2(player_bounds)

	active_hash_key := spat.Hash_Location(gc.players.game.verlet_component.position)
	active_cell := gc.current_level.spatial_hash_grid[active_hash_key]

	// Collide with cubes / planes
	active_cell_objects_ids := &active_cell.objects_ids


	switch gc.players.mode {
	case plrs.Player_Mode.Game:
		if !gc.game_state.finished_level {
			verlet.velocity_verlet_leap(&gc.players.game.verlet_component, dt)
			character.update_character_physics(
				&gc.players.game,
				gc.current_level,
				&player_overlapping_cells,
				dt,
			)

			gc.players.game.verlet_component.position_last_update =
				gc.players.game.verlet_component.position
			verlet.velocity_verlet_frog(&gc.players.game.verlet_component, dt)
		}
	case plrs.Player_Mode.Editor:
	}

	// assert(
	// 	linalg.length(cam.target - cam.position) > 0,
	// 	"camera target and position should never be equal",
	// )

	// game ui START TODO: If we get some rendering issues, this might be causing some of them?
	// game ui END

	// Update Camera
	switch gc.players.mode {
	case plrs.Player_Mode.Game:
		_, forward, right := player_data.calculate_direction_from_look(
			&gc.players.game.look_angles,
		)
		gc.cam.position = gc.players.game.verlet_component.position
		gc.cam.target = gc.cam.position + forward
		gc.cam.up = linalg.cross(forward, right)

	case plrs.Player_Mode.Editor:
		_, forward, right := player_data.calculate_direction_from_look(
			&gc.players.editor.look_data,
		)
		gc.cam.position = gc.players.editor.position
		gc.cam.target = gc.cam.position + forward
		gc.cam.up = linalg.cross(forward, right)
	}

	player_loction := gc.players.game.verlet_component.position
	_, player_look_direction, _ := player_data.calculate_direction_from_look(
		&gc.players.game.look_angles,
	)

	sphere_trace := spat.Sphere_Trace {
		ray = spat.Ray {
			origin = player_loction,
			end = player_loction + player_look_direction * 30,
		},
		radius = 0.3,
	}

	{
		cyl_ins: ddu.Debug_Draw_Instruction = ddu.Debug_Draw_Wire_Cyllinder_Instruction {
			sphere_trace = sphere_trace,
			color        = col.RED,
		}
		ddu.enqueue_draw_instruction(&cyl_ins)
	}


	ins: ddu.Debug_Draw_Instruction = ddu.Debug_Draw_Line_Instruction {
		ray   = sphere_trace.ray,
		color = col.ORANGE,
	}
	ddu.enqueue_draw_instruction(&ins)

	rays := spat.calculate_rays_by_sphere_trace(&sphere_trace)
	for &ray in &rays {

		ins: ddu.Debug_Draw_Instruction = ddu.Debug_Draw_Line_Instruction {
			ray   = ray,
			color = col.DARKBLUE,
		}
		ddu.enqueue_draw_instruction(&ins)
		// ins2 := ddu.Debug_Draw_Instruction{ddu.Debug_Draw_Line_Instruction {
		// 	ray   = ray,
		// 	color = col.DARKBLUE,
		// }}
		// ddu.enqueue_draw_instruction(&ins2)
	}

	hashes := spat.calculate_hashes_by_rays(&rays)
	for hash in &hashes {
		hash := hash
		loc := spat.calculate_hash_cell_width_location(&hash)
		ins: ddu.Debug_Draw_Instruction = ddu.Debug_Draw_Wire_Cube_Instruction {
			location = loc,
			size     = spat.HASH_CELL_SIZE,
			color    = col.DARKPURPLE,
		}
		ddu.enqueue_draw_instruction(&ins)
	}

	// Test agains all objects in hashes

	{
		// cube_ins :ddu.Debug_Draw_Instruction= ddu.Debug_Draw_Cube_Instruction{location = spat.Vector{0,0,-10}, size = spat.Vector{1,1,1}, rot = spat.QUATERNION_IDENTITY, color = rl.RED}

		

		tri := spat.Collision_Triangle{{spat.Vector{0,0,-10}, spat.Vector{5,0,-10}, spat.Vector{0,-5,-10}}}
		reaction : spat.Vector
		hit, reason:=spat.sphere_trace_triangle_intersect(&sphere_trace, &tri, &reaction)

		tri_col := col.BLACK

		if hit == 0 do tri_col = col.RED
		if hit == 1 do tri_col = col.GREEN
		if hit == 2 do tri_col = col.BLUE

		cube_ins := ddu.Debug_Draw_Triangle_Instruction{tri.points.x, tri.points.y, tri.points.z, tri_col}
		ddu.enqueue_draw_instruction2(&cube_ins)

		fmt.println(hit, reason)

		// for hash in &hashes {
		// 	object_ids := gc.current_level.spatial_hash_grid[hash]
		// 	for &object_id in object_ids.objects_ids {
		// 		object := hms.get(&gc.current_level.collision_object_map, object_id)
		// 		transform_matrix := spat.get_matrix_from_transform(object.transform)
		//
		// 		for &t in object.tris {
		// 			// TODO: also implement rotations when the time comes
		// 			tri := t
		// 			for &p in tri.points {
		// 				p = (transform_matrix * spat.Vector4{p.x, p.y, p.z, 1}).xyz // heck yes it works!
		// 				// p += coll_obj.transform.position
		// 			}
		// 			reaction : spat.Vector
		// 			// hit := spat.sphere_trace_triangle(sphere_trace.origin, sphere_trace.end, sphere_trace.radius, tri.points.x, tri.points.y, tri.points.z, nil, nil)
		// 			hit := spat.sphere_trace_triangle_intersect(&sphere_trace, &tri, &reaction)
		// 			if hit {
		// 				fmt.println("We hit something boys!", time.now())
		// 				ins := ddu.Debug_Draw_Sphere_Instruction{}
		// 			}
		// 		}
		// 	}
		// }
	}


	// cells := spat.calculate_hashes_by_ray(spat.Ray{origin = player_loction, end = player_loction + spat.FORWARD_VEC3 * 10000})

	// for key, &cell in &cells {
	// 	key := key
	// 	locaiton := spat.calculate_hash_cell_width_location(&key)
	// 	ins: ddu.Debug_Draw_Instruction = ddu.Debug_Draw_Wire_Cube_Instruction {
	// 		location = locaiton,
	// 		size     = spat.HASH_CELL_SIZE,
	// 		color    = col.DARKPURPLE,
	// 	}
	// 	ddu.enqueue_draw_instruction(&ins)
	//
	// }


	test: ddu.Debug_Draw_Instruction = ddu.Debug_Draw_Cube_Instruction {
		location = spat.Vector{5, 0, 0},
		rot      = spat.QUATERNION_IDENTITY,
		size     = spat.ONE_VEC3 * 5,
		color    = col.DARKBROWN,
	}
	ddu.enqueue_draw_instruction(&test)


	debug_draw_data.active_cell = player_overlapping_cells
	debug_draw_data.active_cell_hash = active_hash_key
	return debug_draw_data
	// render.render(gc.current_level, gc.players, gc.cam, &player_overlapping_cells, active_hash_key, gc.game_state)
}

// Class that contains most resources that are global / created at the very start of the game.
Global_Context :: distinct struct {
	players:       ^plrs.Players,
	game_state:    ^gs.Game_State,
	current_level: ^l.Level,
	cam:           ^rl.Camera3D,
}
