package ui_test

import layout "../"
import hms "../../../handle_map/handle_map_static/"
import clay "../../clay-odin/"
import rr "../raylib"
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

	ctx := layout.Context{}
	ctx.debug_settings = {
		draw_ids           = true,
		draw_if_no_content = true,
	}

	arena := layout.init(rr.measure_text)
	defer layout.deinit(arena)


	{
		root := layout.Layout_Item{}
		root.id = "Root"
		root.size_percent = {1, 1}
		root.layout_dir = .LeftToRight
		handle, _ := hms.add(&ctx.lic, root)

		ctx.root = handle
	}

	{
		node := layout.Layout_Item{}
		node.id = "Node 1"
		node.size_percent = {0.5, 1}

		layout.add_layout_node(&ctx.lic, ctx.root, 0, node)
	}
	{
		node := layout.Layout_Item{}
		node.id = "Node 2"
		node.size_percent = {0.5, 1}

		layout.add_layout_node(&ctx.lic, ctx.root, 0, node)
	}

	// TODO: unregister node?

	for !rl.WindowShouldClose() {
		// ui.update_input(&ui_context)

		layout.update_state()

		clay.BeginLayout()
		layout.layout(&ctx)

		// layout_updated := layout.layout_tiling_windows(
		// 	&ui_context.root_node,
		// 	rl.IsKeyDown(rl.KeyboardKey.C),
		// 	&ui_active_elems,
		// )
		ui_render_commands := clay.EndLayout()

		{
			scoped_drawing()

			rl.ClearBackground(rl.DARKGRAY)

			layout.render(&ui_render_commands)
		}

		// ui.end_frame(&ui_context)


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
