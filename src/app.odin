package main

import ap "engine/application"
import game_interface "game/game_interface"
import back "vendor/back"


main :: proc() {
	context.assertion_failure_proc = back.assertion_failure_proc

	app := ap.Application{}
	game_inter := ap.Game_Interface{}

	game_interface.init_game_interface(&game_inter, context.allocator)
	defer game_interface.deinit_game_interface(&app.game_interface, context.allocator)


	ap.init(&app, game_inter)
	defer ap.deinit(&app)

	ap.run_game(&app)
}
