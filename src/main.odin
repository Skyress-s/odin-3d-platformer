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
import clay "ui/clay-odin"
import rl "vendor:raylib"

import ui "ui"
import game_ui "ui/game_ui"
import layout "ui/layout"
import ui_rr "ui/layout/raylib"


GAME_WINDOW_NAME :: "game_window"

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

	clay_memory_arena := layout.init(ui_rr.measure_text)
	defer ui_rr.delete_raylib_fonts()
	defer layout.deinit(clay_memory_arena)

	root_node := layout.create_root_node()
	// defer layout.delete_all_child_nodes(&root_node)

	ui_context := ui.init_input_context()
	defer ui.deinit_input_context(&ui_context)

	gc: gctx.Global_Context = {
		players             = &players,
		game_state          = &game_state,
		current_level       = &current_level,
		root_node_tiling_ui = &root_node,
		camera_state        = camera.init(
			generate_camera(),
			camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
		),
		ui_context          = &ui_context,
	}

	defer {
		l.delete_level(gc.current_level)
	}

	layout.register_node(
		&root_node,
		layout.make_new_node_with_draw_proc(
			strings.clone(GAME_WINDOW_NAME),
			game_ui.layout_game_ui,
			&gc,
		),
	) // todo how to safe free string
	ui_active_elems := layout.Active_Elements{}
	defer delete(ui_active_elems.elems)
	// ui.register_node(&root_node, ui.make_new_node(strings.clone()"Debug"))

	render_targets := render.render_targets_init({0, 0}) // Will do a resize first frame. Could potentially do this here, by calculating the layout once. But keeping it simple for now.
	defer render.render_targets_deinit(render_targets)


	game_rt_needs_update := true
	// TODO make esc NOT close the
	for !rl.WindowShouldClose() {

		ui.update_input(&ui_context)
		layout_updated := false
		gc.mouse_over_game = false // todo feels kinda hacky


		ui.mouse_pressed_this_frame = rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
		layout.update_state()
		// todo move into ui.Context

		clay.BeginLayout()
		if clay.UI(clay.ID("root"))(
			config = clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					padding = clay.PaddingAll(10),
					layoutDirection = .TopToBottom,
					sizing = clay.Sizing {
						width = clay.SizingPercent(1),
						height = clay.SizingPercent(1),
					},
				},
				// backgroundColor = {25, 55, 55, 0},
			},
		) {
			game_window_bounds := clay.GetElementData(clay.ID(GAME_WINDOW_NAME)).boundingBox
			layout_updated = layout.layout_tiling_windows(
				&root_node,
				rl.IsKeyDown(rl.KeyboardKey.C),
				&ui_active_elems,
			)
		}

		ui_render_commands := clay.EndLayout()
		game_rt_needs_update |= layout_updated


		debug_draw_data: render.Debug_Draw_Data
		// Render phase
		// Render game window
		if layout.find_node(&root_node, GAME_WINDOW_NAME) != nil {
			game_window_bounds := clay.GetElementData(clay.ID(GAME_WINDOW_NAME)).boundingBox

			game_rect: rl.Rectangle = transmute(rl.Rectangle)game_window_bounds

			if game_rt_needs_update {
				render.resize_render_targets(&render_targets, game_rect)
			}

			debug_draw_data = game.update(&gc, game_rect)


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
			layout.render(&ui_render_commands)
			rl.EndDrawing()


			free_all(context.temp_allocator)

		}

		ui.end_frame(&ui_context)
	}


}


@(test)
test_main :: proc(t: ^testing.T) {
	main()
}
