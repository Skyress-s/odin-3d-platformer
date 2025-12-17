package main


import character "Character"
import spat "Spatial"
import "core:testing"
import e_tools "editor/tools"
import "game"
import gs "game_state"
import gameui "micro-ui"
import m_log "mph_log"
import plrs "players"
import rlb "raylib_bridge"
import "render"
import "serialization"
import rl "vendor:raylib"

import ui "ui/layout"
import ui_rr "ui/layout/raylib"


generate_camera :: proc() -> rl.Camera {
	return {
		position = {5, 1, 5},
		target = {0, 0, 3},
		up = {0, 3, 0},
		fovy = 110,
		projection = .PERSPECTIVE,
	}
}

main :: proc() {
	ok, file_logger_handle := m_log.logger_init()
	assert(ok, "Could not initialize project Logger.")
	defer m_log.logger_deinit(file_logger_handle)

	current_level := serialization.load_from_file_level("content/levels/2.I.map")

	game_state := gs.make_default_game_state()
	players := plrs.init_players()

	character.reset_run(
		&players.game,
		&current_level.start_position,
		&current_level.start_look_direction,
	)

	cam := generate_camera()

	players.editor.transform_tool = e_tools.init_transform_tool()

	character.start_speedrun(&players.game)

	gc: game.Global_Context = {
		players       = &players,
		game_state    = &game_state,
		current_level = &current_level,
		cam           = &cam,
	}

	ui.init(ui_rr.measure_text)
	defer ui.deinit()


	rlb.raylib_init()
	defer rlb.raylib_deinit()

	gameui.init_game_ui(&gameui.state.mu_ctx)
	defer gameui.deinit_game_ui()

	rl.SetTraceLogLevel(rl.TraceLogLevel.ERROR)

	// root_node := ui.create_tiling_nodes_2X()
	// TODO make esc NOT close the
	for !rl.WindowShouldClose() {
		
		// ui.update()
		// ui_render_commands := ui.layout(&root_node)
		// ui.render(&ui_render_commands)

		debug_draw_data := game.update(&gc)
		render.render(gc.current_level, gc.players, gc.cam, &debug_draw_data, gc.game_state)

	}
}


@(test)
test_main :: proc(t: ^testing.T) {
	testing.expect(t, true)

}
