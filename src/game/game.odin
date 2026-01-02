package game

import character "../Character"
import col "../color"
import hms "../handle_map/handle_map_static"
import "../render"
import "core:log"
import "core:reflect"
import "core:time"

import ui "../ui"

import verlet "../Physics/verlet"
import spat "../Spatial"
import ddu "../debug_draw_utils/"
import "../editor_player"
import gs "../game_state"
import gctx "../global_context"
import l "../level"
import "../mph_ui/"
import "../player_data"
import plrs "../players"
import layout "../ui/layout"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import mu "vendor:microui"
import rl "vendor:raylib"

import e_tools "../editor/tools"

update :: proc(gc: ^gctx.Global_Context) -> (debug_draw_data: render.Debug_Draw_Data) {
	dt := rl.GetFrameTime()
	// dt = 0.06

	// if ((rl.GetScreenWidth() != gameui.state.screen_width) ||
	// 	   (rl.GetScreenHeight() != gameui.state.screen_height)) {
	// 	gameui.resize_ui()
	// }

	// gameui.handle_input_micro_ui(&gameui.state.mu_ctx)
	//
	// mu.begin(&gameui.state.mu_ctx)
	// mph_ui.all_windows(
	// 	&gameui.state.mu_ctx,
	// 	gc.players,
	// 	gc.game_state,
	// 	{rl.GetScreenWidth(), rl.GetScreenHeight()},
	// 	gc.current_level,
	// )
	// //gameui.all_windows(&gameui.state.mu_ctx, &players, &game_state)
	// mu.end(&gameui.state.mu_ctx)
	// gameui.render(&gameui.state.mu_ctx)


	// Is our mouse overlapping any widget? (naive implementation)
	// mouse_over_ui := false
	// for &container in gameui.state.mu_ctx.containers {
	// 	if mu.rect_overlaps_vec2(container.rect, gameui.state.mu_ctx.mouse_pos) &&
	// 	   container.zindex >= 0 { 	// container.zindex >= 0 feels abit hacky
	//
	// 		mouse_over_ui = true
	// 		break
	// 	}
	// }
	// mouse_over_ui = mu.rect_overlaps_vec2(mu.get_container(&gameui.state.mu_ctx, "details_panel").rect, gameui.state.mu_ctx.mouse_pos)
	//
	// if (rl.IsKeyPressed(rl.KeyboardKey.LEFT_ALT)) {
	//
	// 	container := mu.get_container(&gameui.state.mu_ctx, "Log")
	// 	container.open = !container.open
	// }
	// time.stopwatch_stop(&timer)
	// fmt.printfln("micro-ui layout time {}", time.duration_microseconds(time.stopwatch_duration(timer)))

	position_transform_tool := &gc.players.editor.transform_tool

	if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) &&
	   position_transform_tool.target_object_id.idx != 0 {
		// fmt.printfln("Trying to select an object, mouse_over_ui: {}", mouse_over_ui)

		// if !mouse_over_ui {
		if position_transform_tool.dragging == true {
			position_transform_tool.dragging = false
			position_transform_tool.target_object_id = spat.notify_object_transform_changed(
				&gc.current_level.collision_object_map,
				&gc.current_level.spatial_hash_grid,
				position_transform_tool.target_object_id,
			)
			//position_transform_tool.target_object_id.idx = 0
		}
		// }


	}

	// should we change to another state
	if rl.IsKeyPressed(.Q) {
		switch gc.players.mode {
		case plrs.Player_Mode.Game:
			// enable editor mode
			rl.EnableCursor()
			gc.players.editor.position = gc.players.game.verlet_component.position
			gc.players.editor.look_radians = gc.players.game.look_angles

			found_node := layout.find_node(gc.root_node_tiling_ui, ui.EDITOR_DETAILS_PANEL_NAME)
			if found_node == nil {
				ok, new_editor_details_node := layout.register_node(
					gc.root_node_tiling_ui,
					ui.make_editor_details_node(gc),
				)
				assert(ok)
				found_node = new_editor_details_node
			}


			gc.players.mode = plrs.Player_Mode.Editor
			character.pause_speedrun(&gc.players.game)
		case plrs.Player_Mode.Editor:
			// enable game mode
			rl.DisableCursor()


			if found_node := layout.find_node(
				gc.root_node_tiling_ui,
				ui.EDITOR_DETAILS_PANEL_NAME,
			); found_node != nil {
				layout.unregister_node(gc.root_node_tiling_ui, ui.EDITOR_DETAILS_PANEL_NAME)
			}

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

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT)  /*&& !mouse_over_ui*/{
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
	defer delete(player_overlapping_cells)

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


			// Add gravity
			gc.players.game.verlet_component.acceleration += {0, -30, 0}
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

	// sphere_trace := spat.Sphere_Trace {
	// 	ray = spat.Ray{origin = player_loction, end = player_loction + player_look_direction * 10},
	// 	radius = 1,
	// }
	//
	// ddu.enqueue_ins(
	// 	&ddu.Wire_Cyllinder_Ins{sphere_trace = sphere_trace, color = col.RED},
	// )
	//
	// ddu.enqueue_ins(&ddu.Line_Ins{ray = sphere_trace.ray, color = col.ORANGE})
	//
	// rays := spat.calculate_rays_by_sphere_trace(&sphere_trace)
	// for &ray in &rays {
	//
	// 	ddu.enqueue_ins(&ddu.Line_Ins{ray = ray, color = col.DARKBLUE})
	// }
	//
	// hashes := spat.calculate_hashes_by_rays(&rays)
	// for hash in &hashes {
	// 	hash := hash
	// 	loc := spat.calculate_hash_cell_width_location(&hash)
	// 	ddu.enqueue_ins(
	// 		&ddu.Wire_Cube_Ins {
	// 			location = loc,
	// 			size = spat.HASH_CELL_SIZE,
	// 			color = col.DARKPURPLE,
	// 		},
	// 	)
	// }

	ddu.enqueue_ins(
		&ddu.Cube_Ins {
			location = spat.Vector{5, 0, 0},
			rot = spat.QUATERNION_IDENTITY,
			size = spat.ONE_VEC3 * 5,
			color = col.DARKBROWN,
		},
	)


	debug_draw_data.active_cell = player_overlapping_cells
	debug_draw_data.active_cell_hash = active_hash_key

	return debug_draw_data
	// render.render(gc.current_level, gc.players, gc.cam, &player_overlapping_cells, active_hash_key, gc.game_state)
}
