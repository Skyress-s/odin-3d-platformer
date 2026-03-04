package game

import character "../Character"
import update_character "../Character/update/"
import camera "../camera/"
import col "../color"
import ddu "../debug_draw_utils/"
import e_tools "../editor/tools"
import "../editor_player"
import cs "../engine/core/collision_scene/"
import cmq "../engine/core/collision_scene/query/"
import csq "../engine/core/collision_scene/query/"
import logs "../engine/core/logs"
import verlet "../engine/core/physics/verlet"
import spat "../engine/core/spatial"
import vmouse "../engine/core/virtual_mouse"
import g "../game/game/"
import gent "../game/game_entities/"
import sent "../game/spawn_entities/"
import world "../game/world/"
import gs "../game_state"
import "../player_data"
import plrs "../players"
import rlb "../raylib_bridge"
import render "../render/"
import "core:math/linalg"
import "core:unicode/utf8/utf8string"

import hm "core:container/handle_map"
import rl "vendor:raylib"

update :: proc(
	game: ^g.Game,
	game_rect: rl.Rectangle,
	can_receive_input: bool,
	mouse_pos: rl.Vector2,
	cam: rl.Camera,
) -> (
	debug_draw_data: render.Debug_Draw_Data,
) {
	dt := rl.GetFrameTime()
	mouse_pos := mouse_pos

	update_entities(game.world_session)

	ray := rlb.ray_from_game_rect_cam_mouse(cam, mouse_pos, game_rect)

	players := &game.players


	if can_receive_input {
		switch game.players.mode {
		case plrs.Player_Mode.Game:
			if rl.IsKeyPressed(.TAB) {

				if vmouse.is_cursor_hidden(game.virtual_mouse_ctx^) {
					vmouse.show_cursor(game.virtual_mouse_ctx)
					vmouse.free_mouse(game.virtual_mouse_ctx)
				} else {
					vmouse.hide_cursor(game.virtual_mouse_ctx)
					vmouse.restrict_mouse(
						game.virtual_mouse_ctx,
						vmouse.Vec2 {
							game_rect.x + game_rect.width / 2,
							game_rect.y + game_rect.height / 2,
						},
					)
				}
			}
			update_game_player(game, &debug_draw_data, dt)
		case plrs.Player_Mode.Editor:
			update_editor_player(game)
			editor_player.update(&players.editor, game.virtual_mouse_ctx, dt)
			update_transform_tool(game, cam, ray, dt)
		}
		// should we change to another state
		if rl.IsKeyPressed(.Q) {
			switch game.players.mode {
			case plrs.Player_Mode.Game:
				// enable editor mode
				// rl.EnableCursor()
				game.players.editor.position = game.players.game.verlet_component.position
				game.players.editor.look_radians = game.players.game.look_angles

				game.players.mode = plrs.Player_Mode.Editor
				character.pause_speedrun(&game.players.game)
			case plrs.Player_Mode.Editor:
				// enable game mode
				// rl.DisableCursor()


				game.players.mode = plrs.Player_Mode.Game
				vmouse.hide_cursor(game.virtual_mouse_ctx)
				vmouse.restrict_mouse(
					game.virtual_mouse_ctx,
					vmouse.Vec2 {
						game_rect.x + game_rect.width / 2,
						game_rect.y + game_rect.height / 2,
					},
				)

				character.start_speedrun(&game.players.game)
			}
		}
	}


	return debug_draw_data
}


update_entities :: proc(world_session: ^world.World_Session) {
	// itr := hm.iterator_make(&world_session.world.entities)
	// game_player_bit_set: gent.Traits : {.Game_Player, .Transform}
	// editor_player_bit_set: gent.Traits : {.Editor_Player, .Transform}
	// transform_tool: gent.Traits : {.Transform, .Transform}
	//
	// for ent in hm.iterate(&itr) {
	// 	if gent.has_traits(game_player_bit_set, ent^) {
	// 		update_game_player(world_session, ent)
	// 	}
	// 	if gent.has_traits(editor_player_bit_set, ent^) {
	// 		update_editor_player(world_session, ent)
	// 	}
	// 	if gent.has_traits(transform_tool, ent^) {
	// 		update_transform_tool(world_session, ent)
	// 	}
	// }
}

update_game_player :: proc(game: ^g.Game, debug_draw_data: ^render.Debug_Draw_Data, dt: f32) {
	camera.interp_fov(
		&game.camera_state,
		linalg.length(game.players.game.verlet_component.velocity),
		dt,
	)
	update_character.update_character(
		&game.players.game,
		game.world_session,
		&game.game_state,
		dt,
		game.virtual_mouse_ctx^,
	)

	ents_in_player_position_cell := cmq.entities_in_bound(
		game.entities,
		game.collision_scene.spatial_hash_grid,
		spat.make_bound_by_position(game.players.game.verlet_component.position),
		context.temp_allocator,
	)


	overlapping_finish_volume :=
		cmq.any_entity_in_bound_has_traits(
			game.entities,
			game.collision_scene.spatial_hash_grid,
			spat.make_bound_by_position(game.players.game.verlet_component.position),
			{.Finish},
			context.temp_allocator,
		) !=
		{}
	// overlapping_star_volume := cmq.does_location_overlap_finish_volume(
	// 	&gc.current_level.collsion_scene.stars,
	// 	&gc.current_level.collsion_scene.collision_object_map,
	// 	&gc.players.game.verlet_component.position,
	// )
	//
	// if (overlapping_star_volume != spat.INVALID_OBJECT_ID) {
	// 	gc.current_level.collsion_scene.stars[overlapping_star_volume] = true
	// }

	if overlapping_finish_volume {
		game.game_state.finished_level = true
		character.pause_speedrun(&game.players.game)
		run_time := character.get_current_speedrun_time(&game.players.game)

		if game.players.game.best_time > run_time || game.players.game.best_time == 0 {
			game.players.game.best_time = run_time
		}
	}

	// Kill volumes
	//
	cmq.shg_valid_checked(game.entities, game.collision_scene.spatial_hash_grid)

	overlapping_kill_volumes :=
		cmq.any_entity_in_bound_has_traits(
			game.entities,
			game.collision_scene.spatial_hash_grid,
			spat.make_bound_by_position(game.players.game.verlet_component.position),
			{.Kill},
			context.temp_allocator,
		) !=
		{}
	if overlapping_kill_volumes {
		initial_state := game.player_initial_state
		character.reset_run(
			&game.players.game,
			initial_state.position,
			initial_state.speed,
			initial_state.look_direction,
		)
	}

	// TODO we should not hash the location, but the entire shape. So we can overlap two (or 8) cells simultainiusly
	player_bounds := spat.Bound {
		game.players.game.verlet_component.position - spat.ONE_VEC3 * game.players.game.radius,
		game.players.game.verlet_component.position + spat.ONE_VEC3 * game.players.game.radius,
	}
	player_overlapping_cells := cs.calculate_overlapping_cells_by_bound(player_bounds)
	defer delete(player_overlapping_cells)

	active_hash_key := cs.Hash_Location(game.players.game.verlet_component.position)
	active_cell := game.spatial_hash_grid[active_hash_key]

	// Collide with cubes / planes
	active_cell_objects_ids := &active_cell.objects_ids


	switch game.players.mode {
	case plrs.Player_Mode.Game:
		if !game.game_state.finished_level {
			verlet.velocity_verlet_leap(&game.players.game.verlet_component, dt)

			update_character.update_character_physics(
				&game.players.game,
				game.world,
				game.world,
				&player_overlapping_cells,
				dt,
			)

			game.players.game.verlet_component.position_last_update =
				game.players.game.verlet_component.position
			verlet.velocity_verlet_frog(&game.players.game.verlet_component, dt)


			// Add gravity
			game.players.game.verlet_component.acceleration += {0, -30, 0}
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
	// update_game_player(game, debug_draw_data, dt)
	_, forward, right := player_data.calculate_direction_from_look(game.players.game.look_angles)

	camera.update_transform(
		&game.camera_state,
		game.players.game.verlet_component.position,
		forward,
		right,
	)

	player_loction := game.players.game.verlet_component.position
	_, player_look_direction, _ := player_data.calculate_direction_from_look(
		game.players.game.look_angles,
	)


	debug_draw_data.active_cell = player_overlapping_cells
	debug_draw_data.active_cell_hash = active_hash_key
}

update_editor_player :: proc(game: ^g.Game) {
	_, forward, right := player_data.calculate_direction_from_look(game.players.editor.look_data)

	camera.update_transform(&game.camera_state, game.players.editor.position, forward, right)

}

update_transform_tool :: proc(game: ^g.Game, cam: rl.Camera, ray: spat.Ray, dt: f32) {
	position_transform_tool := &game.players.editor.transform_tool

	if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) &&
	   position_transform_tool.target_object_id.idx != 0 {
		// fmt.printfln("Trying to select an object, mouse_over_ui: {}", mouse_over_ui)

		// if !mouse_over_ui {
		if position_transform_tool.dragging == true {
			position_transform_tool.dragging = false
			// position_transform_tool.target_object_id = csq.notify_object_transform_changed(
			// 	gc.current_level,
			// 	position_transform_tool.target_object_id,
			// )
			//
			sent.reconstruct_spatial_hash_grid_from_entities(
				&game.collision_scene,
				&game.entities,
				game.world_session.world_allocator,
			)
		}


	}

	// was inside editor player update loop before
	if game.mouse_over_game {
		if rl.IsKeyPressed(.ONE) {
			position_transform_tool.active_tool = e_tools.Position_Tool{}
		} else if rl.IsKeyPressed(.TWO) {
			position_transform_tool.active_tool = e_tools.Rotation_Tool{}
		} else if rl.IsKeyPressed(.THREE) {
			position_transform_tool.active_tool = e_tools.Scale_Tool{}
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			ddu.enqueue_ins(
				&ddu.Line_Ins {
					spat.Ray{ray.origin + {0, -1, 0}, ray.end + (ray.end - ray.origin) * 10000},
					col.RED,
				},
				10,
			)
			e_tools.on_click(
				position_transform_tool,
				cam,
				&game.collision_scene,
				&game.entities,
				game.virtual_mouse_ctx.mouse_position,
				ray,
			)

		}
		if position_transform_tool.target_object_id.idx != 0 {
			if position_transform_tool.dragging {
				e_tools.update_transform_tool(
					position_transform_tool,
					cam,
					rl.IsMouseButtonPressed(rl.MouseButton.LEFT),
					rl.IsMouseButtonDown(rl.MouseButton.LEFT),
					&game.entities,
					ray,
				)
			}
		}

	}

}
