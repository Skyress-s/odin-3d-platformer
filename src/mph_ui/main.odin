package mph_ui

import gs "../game_state"
import plrs "../players"
import mu "vendor:microui"
import character "../Character"
import e_plr "../editor_player"


all_windows :: proc(
	ctx: ^mu.Context,
	players: ^plrs.Players,
	game_state: ^gs.Game_State,
	screen_dimensions: [2]i32,
) {
	screen_rect := mu.Rect{0, 0, screen_dimensions.x, screen_dimensions.y}

	switch players.mode{
	case .Game:
	case .Editor:
		details_panel(ctx, players, game_state, screen_rect)
	}
}

details_panel :: proc(
	ctx: ^mu.Context,
	players: ^plrs.Players,
	game_state: ^gs.Game_State,
	screen_rect: mu.Rect,
) {
	percent :f32= 0.30
	screen_rect := screen_rect
	screen_rect.x += (cast(i32)(cast(f32)screen_rect.w * (1 - percent)))
	screen_rect.w = cast(i32)(cast(f32)screen_rect.w * percent) 

	if mu.window(ctx, "details_panel", screen_rect, {}) {
		mu.layout_row(ctx, {-1})
		mu.button(ctx, "duplicate")
	}
}
