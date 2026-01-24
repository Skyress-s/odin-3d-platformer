package ui_test

import ui "../"
import clay "../clay-odin/"
import layout "../layout2/"
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

	rl.InitWindow(1000, 1000, "Window Test")

	rl.SetTargetFPS(180)
	rl.SetConfigFlags({.WINDOW_RESIZABLE})

	ui_context := ui.init()
	defer ui.deinit(&ui_context)

	layout.add_layout_node(&ui_context.layout_ctx.lic, ui_context.layout_ctx.root, 0, layout.make)
	layout.add_layout_item_node()

	layout.register_node(
		&ui_context.root_node,
		layout.make_new_node_with_draw_proc(
			fmt.aprint("stats_window"),
			layout_stats_window,
			&ui_context,
		),
	)
	// TODO: unregister node?

	for !rl.WindowShouldClose() {
		ui.update_input(&ui_context)

		clay.BeginLayout()

		layout_updated := layout.layout_tiling_windows(
			&ui_context.root_node,
			rl.IsKeyDown(rl.KeyboardKey.C),
			&ui_active_elems,
		)
		ui_render_commands := clay.EndLayout()

		{
			scoped_drawing()

			rl.ClearBackground(rl.DARKGRAY)

			layout.render(&ui_render_commands)

		}

		ui.end_frame(&ui_context)


		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}

@(deferred_none = scoped_drawing_end)
scoped_drawing :: proc() {
	rl.BeginDrawing()

}

scoped_drawing_end :: proc() {
	rl.EndDrawing()

}
