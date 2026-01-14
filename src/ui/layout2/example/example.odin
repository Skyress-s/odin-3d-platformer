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
	defer rl.CloseWindow()

	rl.SetTargetFPS(180)
	rl.SetConfigFlags({.WINDOW_RESIZABLE})

	layout_ctx := layout.init(rr.measure_text)
	layout_ctx.debug_settings = {
		draw_ids           = true,
		draw_if_no_content = true,
	}

	defer layout.deinit(&layout_ctx)

	{
		node := layout.Layout_Item{}
		node.id = "Node 1"
		node.size_percent = {0.5, 1}

		layout.add_layout_node(&layout_ctx.lic, layout_ctx.root, 0, node)
	}
	{
		node := layout.Layout_Item{}
		node.id = "Node 2"
		node.size_percent = {0.5, 1}

		layout.add_layout_node(&layout_ctx.lic, layout_ctx.root, 0, node)
	}

	// TODO: unregister node?

	for !rl.WindowShouldClose() {
		layout.update_state()

		clay.BeginLayout()
		layout.layout(&layout_ctx)
		ui_render_commands := clay.EndLayout()

		{
			rl.BeginDrawing()

			rl.ClearBackground(rl.DARKGRAY)

			layout.render(&ui_render_commands)
			rl.EndDrawing()
		}

		free_all(context.temp_allocator)
	}

}
