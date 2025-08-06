package game_state


make_default_game_state :: proc() -> (game_state:Game_State) {
	game_state.cheat_state = make_default_cheat_state()
	return game_state
}

Game_State :: distinct struct {
	cheat_state: Cheat_State,
}

make_default_cheat_state :: proc() -> Cheat_State {
	return Cheat_State{draw_bounds = true}
}

Cheat_State :: distinct struct {
	draw_bounds: bool,
}
