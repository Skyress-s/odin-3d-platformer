package global_context

import gs "../game_state/"
import l "../level/"
import plrs "../players/"
import layout "../ui/layout/"

import rl "vendor:raylib"

// Class that contains most resources that are global / created at the very start of the game.
Global_Context :: distinct struct {
	players:             ^plrs.Players,
	game_state:          ^gs.Game_State,
	current_level:       ^l.Level,
	cam:                 ^rl.Camera3D,
	root_node_tiling_ui: ^layout.Tiling_Node,
	mouse_over_game:     bool, // cursor over the game window. And not obstructed by other ui
}
