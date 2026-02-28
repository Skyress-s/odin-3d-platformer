package main

import "base:runtime"
import ap "engine/application"
import gi "game/game_interface"
import back "vendor/back"


main :: proc() {

	// Assert callstack
	context.assertion_failure_proc = back.assertion_failure_proc

	back.register_segfault_handler()

	// Tracking allocator callstack
	track: back.Tracking_Allocator
	back.tracking_allocator_init(&track, context.allocator)
	defer back.tracking_allocator_destroy(&track)

	context.allocator = back.tracking_allocator(&track)
	defer back.tracking_allocator_print_results(&track)

	// Actual game
	game_interface := ap.Game_Interface{}
	gi.init_game_interface(&game_interface, context.allocator)
	defer gi.deinit_game_interface(&game_interface, context.allocator)

	// Application
	app := ap.Application{}
	ap.init(&app, game_interface)
	defer ap.deinit(&app)

	ap.run_game(&app)
}
