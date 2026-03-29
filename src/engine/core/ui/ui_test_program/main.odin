package ui_test

import ui "../"
import clay "../clay-odin/"
import layout "../layout/"
import ui_rr "../raylib/"
import "core:c"
import "core:fmt"
import rl "vendor:raylib"
/*
* Rework Tiling Nodes to use a handle map instead? Easier to serialize?
* Shotdown properly
* Make sure stuff is added on the correct side when Tiling Nodes aer added and removed
	* clay_arena := layout.init(rr.measure_text) // Remember to remove
	* defer layout.deinit(clay_arena)
* Focus id system inspired by micro ui! 
* Widget can call that is has focus. And hold it. update_control()
*/

main :: proc() {

	window_width := c.int(f64(rl.GetMonitorWidth(rl.GetCurrentMonitor())) * 0.7)
	window_height := c.int(f64(rl.GetMonitorHeight(rl.GetCurrentMonitor())) * 0.7)
	rl.InitWindow(2000, 1200, "Window Test")
	defer rl.CloseWindow()

	rl.SetTargetFPS(180)
	rl.SetConfigFlags({.WINDOW_RESIZABLE})

	ui_context := ui.init()
	defer ui.deinit(&ui_context)
	layout_ctx := &ui_context.layout_ctx
	defer layout.deinit(layout_ctx)
	layout_ctx.debug_settings = {
		draw_ids           = true,
		draw_if_no_content = true,
	}

	layout.add_layout_node(
		&layout_ctx.lic,
		layout_ctx.root,
		0,
		// layout.make_debug_leaf_layout_item(layout_ctx),
		layout.make_layout_item(layout_ctx, "game_window", &ui_context, layout_window_1),
	)
	layout.add_layout_node(
		&layout_ctx.lic,
		layout_ctx.root,
		0,
		// layout.make_debug_leaf_layout_item(layout_ctx),
		layout.make_layout_item(layout_ctx, "stats_window", &ui_context, layout_stats_window),
	)

	layout.normalize_sizes_recursive(&layout_ctx.lic, layout_ctx.root)
	layout.update_layout_dir(&layout_ctx.lic, layout_ctx.root)
	// layout.add_layout_item_node()

	// TODO: unregister node?

	for !rl.WindowShouldClose() {

		ui.update_state(&ui_context)

		clay.BeginLayout()
		layout.layout(layout_ctx)
		ui_render_commands := clay.EndLayout()

		layout.interaction(layout_ctx, ui_context.hover_id == 0)

		{
			scoped_drawing()

			rl.ClearBackground(rl.DARKGRAY)

			layout.render(&ui_render_commands)

		}

		ui.end_frame(&ui_context)


		free_all(context.temp_allocator)
	}

}

@(deferred_none = scoped_drawing_end)
scoped_drawing :: proc() {
	rl.BeginDrawing()

}

scoped_drawing_end :: proc() {
	rl.EndDrawing()

}
