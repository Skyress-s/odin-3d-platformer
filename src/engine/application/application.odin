package application
import "../core/ui/"
import vmouse "../core/virtual_mouse/"

Application :: struct {
	game_interface:    Game_Interface,
	ui_context:        ui.Context,
	virtual_mouse_ctx: vmouse.Context,
	// resources: fonts, textures?,

	// ----
	// players:           ^plrs.Players,
	// game_state:        gs.Game_State,
	// current_level:     ^l.Level,
	// // cam:                 ^rl.Camera3D,
	// camera_state:      camera.Global_State,
	// ui_context:        ui.Context,
	// mouse_over_game:   bool, // cursor over the game window. And not obstructed by other ui
	// virtual_mouse_ctx: vmouse.Context,
}

Game_Interface :: struct {
	data:   rawptr,
	init:   proc(app: ^Application),
	deinit: proc(app: ^Application),
	update: proc(app: ^Application),
	render: proc(app: ^Application),
}
