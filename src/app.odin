package main

import ap "engine/application"


main :: proc() {
	app := ap.Application{}

	ap.init(&app, ap.Game_Interface{})
	dummy_game: f32 = 64
	app.game_interface.data = &dummy_game
	ap.run_game(&app)
	ap.deinit(&app)
}
