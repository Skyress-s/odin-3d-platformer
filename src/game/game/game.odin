package game2

import layout "../../engine/core/ui/layout/"
import vmouse "../../engine/core/virtual_mouse/"
import render "../../render/"
import "../world/"

import ui "../../engine/core/ui/"

Game :: struct {
	using world_session:  ^world.World_Session,
	// game_textures:          render.Textures,
	game_window_handle:   layout.Layout_Item_Handle,
	game_rt_needs_update: bool,
	textures:             render.Textures,
	virtual_mouse_ctx:    ^vmouse.Context,
	ui_context:           ui.Context,
}
