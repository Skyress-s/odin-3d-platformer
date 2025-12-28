package game_ui

import "core:fmt"
import rl "vendor:raylib"

import game_state "../game_state"
import l "../level"
import plrs "../players/"
import clay "clay-odin"
import layout "layout"

// Game Window Stats
stats :: proc(
	players: ^plrs.Players,
	// game_state: ^game_state.Game_State,
	// screen_rect: rl.Rectangle,
	// level: ^l.Level,
) {
	// target_rect := mu.Rect{0, 0, screen_rect.w / 2, screen_rect.h}
	// clay.BeginLayout()
	if clay.UI(clay.ID("stats_main"))(
	{
		// layout = {layoutDirection = node.layout_dir, sizing = {clay.SizingGrow(), clay.SizingGrow()}, padding = clay.PaddingAll(node_leaf_distance(node) == 1 ? 8/2 : 0), childGap = node_leaf_distance(node) == 1 ? 8 : 0},
		
		// layout = {
		// 	layoutDirection = .TopToBottom,
		// 	sizing = clay.Sizing{clay.SizingPercent(0.2), clay.SizingPercent(0.2)},
		// 	padding = clay.PaddingAll(8),
		// 	childGap = 8,
		// },
		// floating = clay.FloatingElementConfig{parentId = clay.ID("root").id},
		backgroundColor = {0, 0, 0, 0}, // node_leaf_distance(node^) == 0 ? auto_hightlight_color() : leaf_dist_to_color(node_leaf_distance(node^)),
	},
	) {
		char_data := &players.game
		clay.TextDynamic(fmt.tprintf("Position {:.1f}", char_data.verlet_component.position), clay.TextConfig({fontSize = 16, fontId = layout.FONT_ID_BODY_16, textColor = layout.COLOR_LIGHT }))
	}

	// return clay.EndLayout()

	// if mu.window(
	// 	ctx,
	// 	"stats",
	// 	target_rect,
	// 	{
	// 		mu.Opt.NO_INTERACT,
	// 		mu.Opt.NO_SCROLL,
	// 		mu.Opt.CLOSED,
	// 		mu.Opt.NO_FRAME,
	// 		mu.Opt.NO_RESIZE,
	// 		mu.Opt.NO_TITLE,
	// 	},
	// ) {
	// 	char_data := &players.game
	// 	mu.get_current_container(ctx).zindex = -100000
	// 	mu.get_current_container(ctx).rect = target_rect
	// 	// mu.layout_row(ctx, {-1})
	// 	// mu.label(ctx, fmt.aprintf("FPS {}", rl.GetFPS()))
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Position {:.1f}", char_data.verlet_component.position))
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Velocity {:.1f}", char_data.verlet_component.velocity))
	//
	// 	mu.layout_row(ctx, {-1})
	// 	vel_xz := char_data.verlet_component.velocity
	// 	vel_xz.y = 0
	// 	mu.label(ctx, fmt.aprintf("Velocity_XZ {:.1f}", linalg.length(vel_xz)))
	//
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Current State {:.1f}", char_data.current_state))
	//
	// 	// Rope length
	// 	rope_length := linalg.distance(
	// 		char_data.verlet_component.position,
	// 		char_data.hooked_position,
	// 	)
	// 	mu.layout_row(ctx, {-1})
	// 	mu.text(ctx, fmt.aprintf("Rope Length {:.1f}", char_data.is_hooked ? rope_length : 0))
	//
	//
	// 	m: f32 = 0.01
	// 	potential_energy := m * 30.0 * (char_data.verlet_component.position.y + 50.0)
	// 	kinetic_energy :=
	// 		0.5 *
	// 		m *
	// 		linalg.length(char_data.verlet_component.velocity) *
	// 		linalg.length(char_data.verlet_component.velocity)
	// 	total_energy := potential_energy + kinetic_energy
	//
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Potential {:.1f}", potential_energy))
	//
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Kinetic {:.1f}", kinetic_energy))
	//
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Total {:.1f}", total_energy))
	//
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Best run    {:.3f}", players.game.best_time))
	//
	// 	mu.layout_row(ctx, {-1})
	// 	mu.label(ctx, fmt.aprintf("Author time {:.3f}", level.author_time))
	//
	// }
}
