package global_context

import camera "../camera"
import gs "../game_state/"
import l "../level/"
import plrs "../players/"
import ui "../ui/"
import layout2 "../ui/layout2/"

import rl "vendor:raylib"

// Class that contains most resources that are global / created at the very start of the game.
Global_Context :: distinct struct {
	players:             ^plrs.Players,
	game_state:          ^gs.Game_State,
	current_level:       ^l.Level,
	// cam:                 ^rl.Camera3D,
	camera_state:        camera.Global_State,
	ui_context:          ^ui.Context,
	mouse_over_game:     bool, // cursor over the game window. And not obstructed by other ui
}
