package application
import "../core/logs/"
import "../core/ui/"
import vmouse "../core/virtual_mouse/"
import "core:fmt"
import rl "vendor:raylib"

Application :: struct {
	game_interface:    Game_Interface,
	ui_context:        ui.Context,
	virtual_mouse_ctx: vmouse.Context,
	// resources: fonts, textures?,
}


Game_Interface :: struct {
	data:           rawptr,
	init:           proc(app: ^Application),
	deinit:         proc(app: ^Application),
	update:         proc(app: ^Application),
	update_physics: proc(app: ^Application),
	render:         proc(app: ^Application),
}

init :: proc(app: ^Application, game: Game_Interface) {
	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.InitWindow(1920, 1085, "mph*0.5mv^2")
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})

	rl.SetTargetFPS(180) // TODO CCD not working at low fps

	app.game_interface = game
	app.ui_context = ui.init()
	app.virtual_mouse_ctx = vmouse.init(
		get_screen_dimentions(),
		disable_cursor,
		is_window_focused,
		show_mouse_proc,
		hide_mouse_proc,
		is_cursor_hidden_proc,
	)


	// rl.SetWindowSize(rl.GetScreenWidth(), rl.GetScreenHeight())


	// lightray.init_lighting()
	//
	//
	// lightray.create_light(.DIRECTIONAL, {10, 10, 10}, spat.ZERO_VEC3, rl.RAYWHITE)
	// {
	// 	// backlight_color := rl.SKYBLUE
	// 	backlight_color := rl.SKYBLUE
	// 	// Color{ 102, 191, 255, 255 }
	//
	// 	lightray.create_light(.DIRECTIONAL, {-10, -10, 10}, spat.ZERO_VEC3, backlight_color)
	// }

	rl.SetExitKey(.Y)

}

deinit :: proc(app: ^Application) {

	// lightray.destroy_lighting()
	ui.deinit(&app.ui_context)
}

run_game :: proc(app: ^Application) {
	assert(app != nil)
	assert(app.game_interface.data != nil)

	// Setup logger
	context.logger = logs.init()
	defer logs.deinit()

	// Run Game
	app.game_interface.init(app)
	for (!rl.WindowShouldClose()) {

		vmouse.update(
			&app.virtual_mouse_ctx,
			rl.GetMouseDelta(),
			{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		)

		app.game_interface.update(app)
		app.game_interface.render(app)
	}

	app.game_interface.deinit(app)
}
