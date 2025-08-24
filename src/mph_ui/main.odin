package mph_ui

import character "../Character"
import e_plr "../editor_player"
import gs "../game_state"
import "../game_state"
import l "../level"
import plrs "../players"
import mu "vendor:microui"


all_windows :: proc(
	ctx: ^mu.Context,
	players: ^plrs.Players,
	game_state: ^gs.Game_State,
	screen_dimensions: [2]i32,
	level: ^l.Level,
) {
	screen_rect := mu.Rect{0, 0, screen_dimensions.x, screen_dimensions.y}


	draw_reticle(ctx, screen_dimensions)

	switch players.mode {
	case .Game:
		cheats_panel(ctx, screen_dimensions, players, game_state, screen_rect)

	case .Editor:
		details_panel(ctx, players, game_state, screen_rect, level)
	}
}

cheats_panel :: proc(
	ctx: ^mu.Context,
	screen_dimentions: [2]i32,
	players: ^plrs.Players,
	game_state: ^game_state.Game_State,
	screen_rect: mu.Rect,
) {

	percent: f32 = 0.20
	screen_rect := screen_rect
	screen_rect.x += (cast(i32)(cast(f32)screen_rect.w * (1 - percent)))
	screen_rect.w = cast(i32)(cast(f32)screen_rect.w * percent)
	// rect := mu.Rect{screen_dimentions.x - 400, 0, 400, 400}
	if mu.window(ctx, "Cheat Window", screen_rect, {mu.Opt.NO_CLOSE, mu.Opt.NO_FRAME}) {
		mu.get_current_container(ctx).rect = screen_rect

		mu.text(ctx, "CHEATS")
		mu.layout_row(ctx, {-1})
		mu.checkbox(ctx, "air_jumping", &players.game.air_jumping_cheat)

		mu.layout_row(ctx, {-1})
		mu.checkbox(ctx, "draw_spatial_hash_grid_bounds", &game_state.cheat_state.draw_bounds)
	}
}

details_panel :: proc(
	ctx: ^mu.Context,
	players: ^plrs.Players,
	game_state: ^gs.Game_State,
	screen_rect: mu.Rect,
	level: ^l.Level,
) {

	percent: f32 = 0.20
	screen_rect := screen_rect
	screen_rect.x += (cast(i32)(cast(f32)screen_rect.w * (1 - percent)))
	screen_rect.w = cast(i32)(cast(f32)screen_rect.w * percent)

	if mu.window(ctx, "details_panel", screen_rect, {}) {
		current_container := mu.get_current_container(ctx)
		current_container.rect = screen_rect

		mu.layout_row(ctx, {-1})
		if mu.Result.SUBMIT in mu.button(ctx, "duplicate") {
			
			players.editor.
		}
	}
}

draw_reticle :: proc(ctx: ^mu.Context, screen_dimensions: [2]i32) {
	center := mu.Vec2{screen_dimensions.x / 2, screen_dimensions.y / 2}
	// Draw cross hair
	{
		crosshair_opts: mu.Options = {
			mu.Opt.NO_INTERACT,
			mu.Opt.NO_SCROLL,
			mu.Opt.NO_CLOSE,
			mu.Opt.NO_RESIZE,
			mu.Opt.NO_TITLE,
		}
		/*
		CROSSHAIR_LENGTH :: 15
		CROSSHAIR_THICKNESS :: 2
		crosshair_rect_v := mu.Rect {
			center.x - CROSSHAIR_THICKNESS / 2,
			center.y - CROSSHAIR_LENGTH / 2,
			CROSSHAIR_THICKNESS,
			CROSSHAIR_LENGTH,
		}
		crosshair_rect_h := mu.Rect {
			center.x - CROSSHAIR_LENGTH / 2,
			center.y - CROSSHAIR_THICKNESS / 2,
			CROSSHAIR_LENGTH,
			CROSSHAIR_THICKNESS,
		}
		mu.window(ctx, "crosshair", crosshair_rect_v, crosshair_opts)
		mu.window(ctx, "crosshair", crosshair_rect_h, crosshair_opts)
		*/
		CROSSHAIR_DOT_SIZE :: 5
		crosshair_rect := mu.Rect {
			center.x - CROSSHAIR_DOT_SIZE / 2,
			center.y - CROSSHAIR_DOT_SIZE / 2,
			CROSSHAIR_DOT_SIZE,
			CROSSHAIR_DOT_SIZE,
		}
		if (mu.window(ctx, "crosshair", crosshair_rect, crosshair_opts)) {
			mu.get_current_container(ctx).rect = crosshair_rect
		}

	}


}
