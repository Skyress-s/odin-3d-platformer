package main

import "base:runtime"
import "core:c"
import "core:debug/trace"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

import character "Character"
import camera "camera"
import "core:testing"
import e_tools "editor/tools"
import "game"
import gs "game_state"
import gctx "global_context"
import l "level"
import plrs "players"
import rlb "raylib_bridge"
import "render"
import "serialization"
import rl "vendor:raylib"

import layout "ui/layout2"


USE_TRACESTACK :: #config(USE_TRACESTACK, false)

generate_camera :: proc() -> rl.Camera {
	return {
		position = {5, 1, 5},
		target = {0, 0, 3},
		up = {0, 3, 0},
		fovy = 95,
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

	current_level := serialization.load_from_file_level("content/levels/2.I.map")

	game_state := gs.make_default_game_state()
	players := plrs.init_players()

	character.reset_run(
		&players.game,
		&current_level.start_position,
		&current_level.start_look_direction,
	)

	players.editor.transform_tool = e_tools.init_transform_tool()

	character.start_speedrun(&players.game)

	rlb.raylib_init()
	defer rlb.raylib_deinit()

	rl.SetTraceLogLevel(rl.TraceLogLevel.ERROR)

	gc: gctx.Global_Context = {
		players             = &players,
		game_state          = &game_state,
		current_level       = &current_level,
		root_node_tiling_ui = nil,
		camera_state        = camera.init(
			generate_camera(),
			camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
		),
		ui_context          = nil,
	}

	defer {
		l.delete_level(gc.current_level)
	}

	render_targets := render.render_targets_init({0, 0})
	defer render.render_targets_deinit(render_targets)

	// layout_ctx := layout.init(rr.measure_text)
	// defer layout.deinit(&layout_ctx)
	// layout_ctx.debug_settings = {
	// 	draw_ids           = true,
	// 	draw_if_no_content = true,
	// }

	game_rt_needs_update := true

	for !rl.WindowShouldClose() {
		gc.mouse_over_game = true

		if rl.IsWindowResized() {
			game_rt_needs_update = true
		}

		game_rect := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

		if game_rt_needs_update {
			render.resize_render_targets(&render_targets, game_rect)
			game_rt_needs_update = false
		}

		debug_draw_data := game.update(&gc, game_rect)

		render.render(
			gc.current_level,
			gc.players,
			gc.camera_state.current_camera,
			&debug_draw_data,
			gc.game_state,
			game_rect,
			&render_targets,
		)

		rl.BeginDrawing()
		rl.ClearBackground({14, 35, 45, 255})

		// draw game
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

		free_all(context.temp_allocator)
	}
}


@(test)
test_main :: proc(t: ^testing.T) {
	main()
}
