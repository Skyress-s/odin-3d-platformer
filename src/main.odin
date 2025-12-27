package main

import "core:strings"
import "core:fmt"
import "core:mem"
import "base:runtime"
import "core:c"
import "core:debug/trace"
import "core:log"
import "core:time"

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

USE_TRACESTACK :: #config(USE_TRACESTACK, false)

generate_camera :: proc() -> rl.Camera {
	return {
		position = {5, 1, 5},
		target = {0, 0, 3},
		up = {0, 3, 0},
		fovy = 110,
		projection = .PERSPECTIVE,
	}
}

when USE_TRACESTACK {
	global_trace_ctx: trace.Context

	debug_trace_assertion_failure_proc :: proc(
		prefix, message: string,
		loc := #caller_location,
	) -> ! {
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
}

main :: proc() {
	when USE_TRACESTACK {
		trace.init(&global_trace_ctx)
		defer trace.destroy(&global_trace_ctx)

		context.assertion_failure_proc = debug_trace_assertion_failure_proc
	}

	// when ODIN_DEBUG {
	//
	// 	// create the allocator
	// 	tracker: mem.Tracking_Allocator
	//
	// 	// initialize the allocator to wrap around the default allocator in context
	// 	mem.tracking_allocator_init(&tracker, context.allocator)
	//
	// 	// convert the tracking allocator to the allocator interface and make it the
	// 	// default allocator
	// 	context.allocator = mem.tracking_allocator(&tracker)
	//
	// 	defer {
	// 		fmt.eprintf("Tracking allocator results:\n")
	// 		if len(tracker.allocation_map) > 0 {
	// 			for _, leak in tracker.allocation_map {
	// 				fmt.eprintf("%v leaked %m\n", leak.location, leak.size)
	// 			}
	// 		} else {
	// 			fmt.eprintf("No leaks!\n")
	// 		}
	//
	// 		fmt.eprintf("Tracking allocator bad frees:\n")
	// 		if len(tracker.bad_free_array) > 0 {
	// 			for b in tracker.bad_free_array {
	// 				fmt.eprintf("Bad free at: %v\n", b.location)
	// 			}
	// 		} else {
	// 			fmt.eprintf("No bad frees!\n")
	// 		}
	//
	// 		mem.tracking_allocator_destroy(&tracker)
	// 	}
	// }
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))

				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	main_console_logger := log.create_console_logger()
	context.logger = main_console_logger
	defer log.destroy_console_logger(main_console_logger)
	// ok, file_logger_handle := m_log.logger_init()
	// assert(ok, "Could not initialize project Logger.")
	// defer m_log.logger_deinit(file_logger_handle)

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

	ui.register_node(&root_node, ui.make_new_node(strings.clone(GAME_WINDOW_NAME))) // todo how to safe free string
	// ui.register_node(&root_node, ui.make_new_node(strings.clone()"Debug"))

	render_targets := render.render_targets_init({0, 0}) // Will do a resize first frame. Could potentially do this here, by calculating the layout once. But keeping it simple for now.
	defer render.render_targets_deinit(render_targets)


	game_rt_needs_update := true
	// TODO make esc NOT close the
	for !rl.WindowShouldClose() {

		ui.update_state()
		ui_render_commands, layout_updated := ui.create_layout_tiling(&root_node, true)
		game_rt_needs_update |= layout_updated

		// resize render targets


		// log.infof("num rendering commands {}", ui_render_commands.length)
		// sw : time.Stopwatch
		// time.stopwatch_start(&sw)
		// time.stopwatch_stop(&sw)

		// rl.BeginDrawing()
		// rl.DrawRectangleV({100,100}, {100,100}, rl.RED)
		// rl.EndDrawing()
		// time.sleep(100 * time.Millisecond)

		// log.infof("render duration {}", time.duration_milliseconds(time.stopwatch_duration(sw)))

		debug_draw_data := game.update(&gc)

		// Render phase

		// Render game window
		if ui.find_node(&root_node, GAME_WINDOW_NAME) != nil {
			game_window_bounds := clay.GetElementData(clay.ID(GAME_WINDOW_NAME)).boundingBox
			game_rect := rl.Rectangle {
				x      = game_window_bounds.x,
				y      = game_window_bounds.y,
				width  = game_window_bounds.width,
				height = game_window_bounds.height,
			}

			if game_rt_needs_update {
				render.resize_render_targets(&render_targets, game_rect)
			}


			render.render(
				gc.current_level,
				gc.players,
				gc.cam,
				&debug_draw_data,
				gc.game_state,
				game_rect,
				&render_targets,
			)


			rl.BeginDrawing()
			rl.ClearBackground({14, 35, 45, 255})
			ui.render(&ui_render_commands)

			rl.DrawTexturePro(
				render_targets.game.texture,
				rl.Rectangle {
					0,
					0,
					f32(render_targets.game.texture.width),
					f32(-render_targets.game.texture.height),
				},
				game_rect,
				{},
				0,
				rl.WHITE,
			)
			rl.EndDrawing()
		}

		// render.render(
		// 	gc.current_level,
		// 	gc.players,
		// 	gc.cam,
		// 	&debug_draw_data,
		// 	gc.game_state,
		// 	rl.Rectangle{0,0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())})

	}


}


@(test)
test_main :: proc(t: ^testing.T) {
	main()

}
