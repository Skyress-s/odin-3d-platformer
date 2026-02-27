package game2

import layout "../../engine/core/ui/layout/"
import vmouse "../../engine/core/virtual_mouse/"
import gs "../../game_state/"
import render "../../render/"
import w "../world/"

import ui "../../engine/core/ui/"

Game :: struct {
	using world_session:  ^w.World_Session,
	// game_textures:          render.Textures,
	game_window_handle:   layout.Layout_Item_Handle,
	game_rt_needs_update: bool,
	mouse_over_game:      bool,
	textures:             render.Textures,
	virtual_mouse_ctx:    ^vmouse.Context,
	ui_context:           ^ui.Context,
	game_state:           gs.Game_State,
}
