package game_interface

import ap "../../engine/application/"
import game "../game"

import "base:runtime"

init_game_interface :: proc(game_interface: ^ap.Game_Interface, allocator: runtime.Allocator) {
	game := new(game.Game, allocator)
	game_interface^ = app.Game_Interface{&game, init, deinit, update, update_physics, render}
}

deinit_game_interface :: proc(game_interface: ^app.Game_Interface, allocator: runtime.Allocator) {
	free(game_interface.data)
}

@(private)
init :: proc(app: ^ap.Application) {
	game := cast(^game.Game)app.game_interface.data
	assert(game)


	// current_level := serialization.load_from_file_level("content/levels/2.I.map")
	current_level := make_basic_level()

	players := plrs.init_players()

	character.reset_run(
		&players.game,
		&current_level.start_position,
		&current_level.start_look_direction,
	)

	players.editor.transform_tool = e_tools.init_transform_tool()

	character.start_speedrun(&players.game)

	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rlb.raylib_init()
	defer rlb.raylib_deinit()


	gc: gctx.Global_Context = {
		players           = &players,
		game_state        = gs.make_default_game_state(),
		current_level     = &current_level,
		ui_context        = ui.init(),
		camera_state      = camera.init(
			generate_camera(),
			camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
		),
		textures          = render.textures_init({0, 0}),
		virtual_mouse_ctx = vmouse.init(
			{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
			disable_cursor,
			is_window_focused,
			show_mouse_proc,
			hide_mouse_proc,
			is_cursor_hidden_proc,
		),
	}

	defer {
		ui.deinit(&gc.ui_context)
		l.delete_level(gc.current_level)
		render.textures_deinit(gc.textures)
	}

	// Add game window as a Layout_Item in the layout2 system

	game_window_handle := game_ui.setup_initial_window_layout(&gc)

	setup_mouse(&gc, game_window_handle)

	game_rt_needs_update := true

	rl.SetExitKey(.Y)
	for !rl.WindowShouldClose() {

		debug_draw_data, game_rect := update_all(&gc, &game_rt_needs_update, game_window_handle)

		render_all(&gc, &debug_draw_data, game_rect)

		ui.end_frame(&gc.ui_context)
		free_all(context.temp_allocator)
	}

}

@(private)
deinit :: proc(app: ^ap.Application) {}
@(private)
update :: proc(app: ^ap.Application) {}
@(private)
update_physics :: proc(app: ^ap.Application) {}
@(private)
render :: proc(app: ^ap.Application) {}
