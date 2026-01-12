package ui_test

import ui "../"
import clay "../clay-odin/"
import layout "../layout/"
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

	ui_context := ui.init_input_context()
	defer ui.deinit_input_context(&ui_context)

	ui_active_elems := layout.Active_Elements{}
	defer delete(ui_active_elems.elems)

	layout.register_node(
		&ui_context.root_node,
		layout.make_new_node_with_draw_proc(fmt.aprint("window_1"), layout_window_1, &ui_context),
	)

	layout.register_node(
		&ui_context.root_node,
		layout.make_new_node_with_draw_proc(
			fmt.aprint("stats_window"),
			layout_stats_window,
			&ui_context,
		),
	)
	// todo unregister node?

	for !rl.WindowShouldClose() {
		{
			// fmt.println("FRAME START")
			// UI Layout
			// fmt.println("update_input")
			ui.update_input(&ui_context)

			// fmt.println("update_state")
			layout.update_state()
			// fmt.printfln("focus id {}", ui_context.focus_id)

			// fmt.println("clay.BeginLayout")
			clay.BeginLayout()

			// fmt.println("layout_tiling_windows")
			layout_updated := layout.layout_tiling_windows(
				&ui_context.root_node,
				rl.IsKeyDown(rl.KeyboardKey.C),
				&ui_active_elems,
			)
			ui_render_commands := clay.EndLayout()

			// Drawing Step
			scoped_drawing()

			rl.ClearBackground(rl.DARKGRAY)


			layout.render(&ui_render_commands)

			// fmt.println(ui_context)

		}

		// if ui_context.focus_id != 0 {
		// 	fmt.printfln("FOCUS ID {}", ui_context.focus_id)
		// }

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
