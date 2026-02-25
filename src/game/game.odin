package game

import character "../Character"
import camera "../camera/"
import col "../color"
import ddu "../debug_draw_utils/"
import e_tools "../editor/tools"
import "../editor_player"
import cs "../engine/core/collision_scene/"
import cmq "../engine/core/collision_scene/query/"
import csq "../engine/core/collision_scene/query/"
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

import hm "core:container/handle_map"
import rl "vendor:raylib"

update :: proc(
	game: ^g.Game,
	game_rect: rl.Rectangle,
	can_receive_input: bool,
	mouse_pos: rl.Vector2,
) -> (
	debug_draw_data: render.Debug_Draw_Data,
) {
	dt := rl.GetFrameTime()
	mouse_pos := mouse_pos

	// cam := gc.camera_state.current_camera
	//
	// level := gc.current_level

	update_entities(game.world_session)

	ray := rlb.convert_ray(
		rl.GetScreenToWorldRayEx(
			mouse_pos - {game_rect.x, game_rect.y},
			gc.camera_state.current_camera,
			i32(game_rect.width),
			i32(game_rect.height),
		),
	)


	{
		@(static) cursor_enabled := false
		if rl.IsKeyPressed(.TAB) {
			GAME_CHEATS_WINDOW_NAME :: "game_cheats"

			cursor_enabled = !cursor_enabled
			if cursor_enabled {
				vmouse.show_cursor(gc.virtual_mouse_ctx)
				vmouse.free_mouse(gc.virtual_mouse_ctx)
			} else {
				vmouse.hide_cursor(gc.virtual_mouse_ctx)
				vmouse.restrict_mouse(
					gc.virtual_mouse_ctx,
					vmouse.Vec2 {
						game_rect.x + game_rect.width / 2,
						game_rect.y + game_rect.height / 2,
					},
				)
			}
		}

	}


	if can_receive_input {
		// should we change to another state
		if rl.IsKeyPressed(.Q) {
			switch gc.players.mode {
			case plrs.Player_Mode.Game:
				// enable editor mode
				// rl.EnableCursor()
				gc.players.editor.position = gc.players.game.verlet_component.position
				gc.players.editor.look_radians = gc.players.game.look_angles

				gc.players.mode = plrs.Player_Mode.Editor
				character.pause_speedrun(&gc.players.game)
			case plrs.Player_Mode.Editor:
				// enable game mode
				// rl.DisableCursor()


				gc.players.mode = plrs.Player_Mode.Game
				character.start_speedrun(&gc.players.game)
			}
		}

		switch gc.players.mode {
		case plrs.Player_Mode.Game:

		case plrs.Player_Mode.Editor:
		}
	}


	return debug_draw_data
	// render.render(gc.current_level, gc.players, gc.cam, &player_overlapping_cells, active_hash_key, gc.game_state)
}

// update_player_entity :: proc()

update_entities :: proc(world_session: ^world.World_Session) {
	itr := hm.iterator_make(&world_session.world.entities)
	game_player_bit_set: gent.Traits : {.Game_Player, .Transform}
	editor_player_bit_set: gent.Traits : {.Editor_Player, .Transform}
	transform_tool: gent.Traits : {.Transform, .Transform}

	for ent in hm.iterate(&itr) {
		if gent.has_traits(game_player_bit_set, ent^) {
			update_game_player(world_session, ent)
		}
		if gent.has_traits(editor_player_bit_set, ent^) {
			update_editor_player(world_session, ent)
		}
		if gent.has_traits(transform_tool, ent^) {
			update_transform_tool(world_session, ent)
		}
	}
}

update_game_player :: proc(world_session: ^world.World_Session, ent: ^gent.Entity) {
	camera.interp_fov(
		&gc.camera_state,
		linalg.length(gc.players.game.verlet_component.velocity),
		dt,
	)
	character.update_character(
		&gc.players.game,
		gc.current_level,
		&gc.game_state,
		dt,
		gc.virtual_mouse_ctx^,
	)

	ents_in_player_position_cell := cmq.entities_in_bound(
		level.entities,
		level.collsion_scene.spatial_hash_grid,
		spat.make_bound_by_position(gc.players.game.verlet_component.position),
		context.temp_allocator,
	)


	overlapping_finish_volume :=
		cmq.any_entity_in_bound_has_traits(
			level.entities,
			level.collsion_scene.spatial_hash_grid,
			spat.make_bound_by_position(gc.players.game.verlet_component.position),
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
		gc.game_state.finished_level = true
		character.pause_speedrun(&gc.players.game)
		run_time := character.get_current_speedrun_time(&gc.players.game)

		if gc.players.game.best_time > run_time || gc.players.game.best_time == 0 {
			gc.players.game.best_time = run_time
		}
	}

	// Kill volumes
	//
	cmq.shg_valid_checked(level.entities, level.collsion_scene.spatial_hash_grid)

	overlapping_kill_volumes :=
		cmq.any_entity_in_bound_has_traits(
			level.entities,
			level.collsion_scene.spatial_hash_grid,
			spat.make_bound_by_position(gc.players.game.verlet_component.position),
			{.Kill},
			context.temp_allocator,
		) !=
		{}
	if overlapping_kill_volumes {
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
	player_overlapping_cells := cs.calculate_overlapping_cells_by_bound(player_bounds)
	defer delete(player_overlapping_cells)

	active_hash_key := cs.Hash_Location(gc.players.game.verlet_component.position)
	active_cell := gc.current_level.collsion_scene.spatial_hash_grid[active_hash_key]

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
		_, forward, right := player_data.calculate_direction_from_look(gc.players.game.look_angles)

		camera.update_transform(
			&gc.camera_state,
			gc.players.game.verlet_component.position,
			forward,
			right,
		)
	case plrs.Player_Mode.Editor:
	// gc.cam.position = gc.players.editor.position
	// gc.cam.target = gc.cam.position + forward
	// gc.cam.up = linalg.cross(forward, right)
	}

	player_loction := gc.players.game.verlet_component.position
	_, player_look_direction, _ := player_data.calculate_direction_from_look(
		gc.players.game.look_angles,
	)


	debug_draw_data.active_cell = player_overlapping_cells
	debug_draw_data.active_cell_hash = active_hash_key


}

update_editor_player :: proc(world_session: ^world.World_Session, ent: ^gent.Entity) {
	_, forward, right := player_data.calculate_direction_from_look(gc.players.editor.look_data)

	camera.update_transform(&gc.camera_state, gc.players.editor.position, forward, right)

}

update_transform_tool :: proc(world_session: ^world.World_Session, ent: ^gent.Entity) {
	position_transform_tool := &gc.players.editor.transform_tool

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
				&level.collsion_scene,
				&level.entities,
			)
		}


	}

	// was inside editor player update loop before
	if gc.mouse_over_game {
		if rl.IsKeyPressed(.ONE) {
			position_transform_tool.active_tool = e_tools.Position_Tool{}
		} else if rl.IsKeyPressed(.TWO) {
			position_transform_tool.active_tool = e_tools.Rotation_Tool{}
		} else if rl.IsKeyPressed(.THREE) {
			position_transform_tool.active_tool = e_tools.Scale_Tool{}
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) && gc.mouse_over_game {
			ddu.enqueue_ins(
				&ddu.Line_Ins {
					spat.Ray{ray.origin + {0, -1, 0}, ray.end + (ray.end - ray.origin) * 10000},
					col.RED,
				},
				10,
			)
			e_tools.on_click(position_transform_tool, &cam, gc.current_level, mouse_pos, ray)

		}
		if position_transform_tool.target_object_id.idx != 0 {
			if position_transform_tool.dragging {
				e_tools.update_transform_tool(
					position_transform_tool,
					&cam,
					rl.IsMouseButtonPressed(rl.MouseButton.LEFT),
					rl.IsMouseButtonDown(rl.MouseButton.LEFT),
					&gc.current_level.entities,
					ray,
				)
			}
		}
		editor_player.update(&gc.players.editor, gc.virtual_mouse_ctx, dt)

	}

}
