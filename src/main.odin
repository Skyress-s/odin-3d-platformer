package main

import "base:runtime"
import "core:c"
import "core:debug/trace"
import "core:fmt"
import "core:log"
import "core:mem"

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
import ui "ui"
import clay "ui/clay-odin"
import game_ui "ui/game_ui"
import layout2 "ui/layout2"
import rl "vendor:raylib"


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

	// Initialize UI system
	ui_context := ui.init()
	defer ui.deinit(&ui_context)

	gc: gctx.Global_Context = {
		players        = &players,
		game_state     = &game_state,
		current_level  = &current_level,
		ui_context     = &ui_context,
		camera_state   = camera.init(
			generate_camera(),
			camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
		),
		render_targets = render.render_targets_init({0, 0}),
	}

	defer {
		l.delete_level(gc.current_level)
		render.render_targets_deinit(gc.render_targets)
	}


	// Add game window as a Layout_Item in the layout2 system
	layout_ctx := &ui_context.layout_ctx
	game_window_item := game_ui.make_game_window_node(layout_ctx, &gc)
	game_window_handle := layout2.add_layout_node(
		&layout_ctx.lic,
		layout_ctx.root,
		0,
		game_window_item,
	)
	{
		ui_layout_item := layout2.make_layout_item(
			layout_ctx,
			"ui_details",
			&gc,
			game_ui.layout_ui_data,
		)
		ui_layout_item.size_percent = {0.5, 0.5}
		layout2.add_layout_node(&layout_ctx.lic, layout_ctx.root, 0, ui_layout_item)
	}
	layout2.normalize_sizes_recursive(&layout_ctx.lic, layout_ctx.root)
	layout2.update_layout_dir(&layout_ctx.lic, layout_ctx.root)

	game_rt_needs_update := true

	for !rl.WindowShouldClose() {
		gc.mouse_over_game = false // Will be set to true by layout_game_ui if hovered

		// Update UI state (mouse, keyboard, etc.)
		ui.update_state(&ui_context)

		if rl.IsWindowResized() {
			game_rt_needs_update = true
		}

		// Get game rect from layout system (after first frame, use cached bounding box)
		game_item := layout2.get_item_checked(&layout_ctx.lic, game_window_handle)

		// TODO: Get body not the outline.
		game_element_data := clay.GetElementData(clay.GetElementId(clay.MakeString(game_item.id)))

		game_rect: rl.Rectangle
		if game_element_data.found {
			game_rect = rl.Rectangle {
				game_element_data.boundingBox.x,
				game_element_data.boundingBox.y,
				game_element_data.boundingBox.width,
				game_element_data.boundingBox.height,
			}
		} else {
			// Fallback for first frame before layout is computed
			game_rect = rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		}

		// Check if render target needs resize
		if game_rt_needs_update ||
		   (gc.render_targets.game.texture.width != i32(game_rect.width)) ||
		   (gc.render_targets.game.texture.height != i32(game_rect.height)) {
			render.resize_render_targets(&gc.render_targets, game_rect)
			game_rt_needs_update = false
		}

		debug_draw_data := game.update(
			&gc,
			game_rect,
			layout_ctx.controlling_layout_item == game_window_handle,
		)

		render.render(
			gc.current_level,
			gc.players,
			gc.camera_state.current_camera,
			&debug_draw_data,
			gc.game_state,
			game_rect,
			&gc.render_targets,
		)

		// Layout pass
		clay.BeginLayout()
		layout2.layout(layout_ctx)
		ui_render_commands := clay.EndLayout()

		// Handle layout interactions (only when not hovering game)
		// TODO: Wwhn in editor mode. Game should not grab mouse (move to center) when clicking the screen
		// with the intent to change the layout
		layout2.interaction(layout_ctx, true) // !gc.mouse_over_game

		rl.BeginDrawing()
		rl.ClearBackground({14, 35, 45, 255})

		// Draw UI overlay
		layout2.render(&ui_render_commands)

		rl.EndDrawing()

		ui.end_frame(&ui_context)
		free_all(context.temp_allocator)
	}
}


@(test)
test_main :: proc(t: ^testing.T) {
	main()
}
