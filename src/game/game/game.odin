package game2

import layout "../../engine/core/ui/layout/"
import gctx "../../global_context/"
import "../world/"

Game :: struct {
	game_world:           ^world.World,
	// game_textures:          render.Textures,
	global_ctx:           gctx.Global_Context,
	game_window_handle:   layout.Layout_Item_Handle,
	game_rt_needs_update: bool,
}
