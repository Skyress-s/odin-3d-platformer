package main

import "base:runtime"
import "core:debug/trace"

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
import clay "ui/clay-odin"
import rl "vendor:raylib"

import ui "ui/layout"
import ui_rr "ui/layout/raylib"


GAME_WINDOW_NAME :: "game_window"

generate_camera :: proc() -> rl.Camera {
	return {
		position = {5, 1, 5},
		target = {0, 0, 3},
		up = {0, 3, 0},
		fovy = 110,
		projection = .PERSPECTIVE,
	}
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


	rlb.raylib_init()
	defer rlb.raylib_deinit()

	gameui.init_game_ui(&gameui.state.mu_ctx)
	defer gameui.deinit_game_ui()

	rl.SetTraceLogLevel(rl.TraceLogLevel.ERROR)

	ui.init(ui_rr.measure_text)
	defer ui.deinit()

	root_node := ui.create_root_node()
	defer ui.delete_all_child_nodes(&root_node)

	ui.register_node(&root_node, ui.make_new_node(GAME_WINDOW_NAME))
	ui.register_node(&root_node, ui.make_new_node("Debug"))
	// TODO make esc NOT close the
	for !rl.WindowShouldClose() {

		ui.update()
		ui_render_commands := ui.layout(&root_node)
		ui.render(&ui_render_commands)

		debug_draw_data := game.update(&gc)

		// Render phase

		// Render game window
		// game_rect, game_rect_ok := ui.get_node(&root_node, GAME_WINDOW_NAME)
		// assert(game_rect_ok)
		game_window_bounds := clay.GetElementData(clay.ID(GAME_WINDOW_NAME)).boundingBox
		game_rect := rl.Rectangle {
			x      = game_window_bounds.x,
			y      = game_window_bounds.y,
			width  = game_window_bounds.width,
			height = game_window_bounds.height,
		}

		// game_rect.width = 1000
		// game_rect.height = 1000

		render.render(
			gc.current_level,
			gc.players,
			gc.cam,
			&debug_draw_data,
			gc.game_state,
			game_rect,
		)

	}


}


@(test)
test_main :: proc(t: ^testing.T) {
	testing.expect(t, true)

}
