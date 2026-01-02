package game_ui

import "base:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:time"
import rl "vendor:raylib"

import game_state "../game_state"
import gctx "../global_context"
import l "../level"
import plrs "../players/"
import clay "clay-odin"
import layout "layout"

layout_game_ui :: proc(parent_node: ^layout.Tiling_Node) {
	gc := cast(^gctx.Global_Context)parent_node.userdata
	assert(gc != nil)

	if gc.players.mode == .Game {

		// floating

		layout_reticle(gc.players)
		layout_speedrun_timer(gc.players)

		if clay.UI(clay.ID("Game_Divide"))(
			config = clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					layoutDirection = .LeftToRight,
					sizing = {width = clay.SizingPercent(1), height = clay.SizingPercent(1)},
					// sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				},
				backgroundColor = {50, 50, 50, 50},
			},
		) {
			layout_stats(gc.players, gc.current_level)
			layout_cheats_panel(gc.players, gc.game_state, &gc.test_bool)
		}
	} else {
		// Might want to have something here?
		layout_reticle(gc.players)
	}


}


layout_editor_details :: proc(parent_node: ^layout.Tiling_Node) {
	gc := cast(^gctx.Global_Context)parent_node.userdata
	assert(gc != nil)


}

EDITOR_DETAILS_PANEL_NAME :: "Editor_Details_Panel"
make_editor_details_node :: proc(gc: ^gctx.Global_Context) -> layout.Tiling_Node {
	node := layout.make_new_node_with_draw_proc(
		EDITOR_DETAILS_PANEL_NAME,
		layout_editor_details,
		gc,
	)
	return node
}

text_entry :: proc(text: string, text_alignment: clay.TextAlignment = .Left) {
	clay.TextDynamic(
		text,
		clay.TextConfig(
			{
				fontSize      = 32,
				fontId        = layout.FONT_ID_BODY_16,
				textColor     = layout.COLOR_LIGHT,
				textAlignment = text_alignment,
				wrapMode      = .Words,
				// lineHeight = 4
			},
		),
	)

}

// Game Window Stats
layout_stats :: proc(
	players: ^plrs.Players,
	// game_state: ^game_state.Game_State,
	// screen_rect: rl.Rectangle,
	level: ^l.Level,
) {
	// target_rect := mu.Rect{0, 0, screen_rect.w / 2, screen_rect.h}
	// clay.BeginLayout()
	if clay.UI(clay.ID("stats_main"))(
	{
		// layout = {layoutDirection = node.layout_dir, sizing = {clay.SizingGrow(), clay.SizingGrow()}, padding = clay.PaddingAll(node_leaf_distance(node) == 1 ? 8/2 : 0), childGap = node_leaf_distance(node) == 1 ? 8 : 0},
		layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingGrow()}},
		// floating = clay.FloatingElementConfig {
		// 	offset = {50, 50},
		// 	attachTo = .Parent,
		// 	zIndex = 1000,
		// },
		backgroundColor = {0, 0, 0, 0}, // node_leaf_distance(node^) == 0 ? auto_hightlight_color() : leaf_dist_to_color(node_leaf_distance(node^)),
	},
	) {
		char_data := &players.game
		text_entry(fmt.tprintf("Position {:4.0f}", char_data.verlet_component.position))
		text_entry(fmt.tprintf("FPS {}", rl.GetFPS()))

		// Velocities
		text_entry(fmt.tprintf("Velocity {:.1f}", char_data.verlet_component.velocity))
		text_entry(fmt.tprintf("speed {:.1f}", linalg.length(char_data.verlet_component.velocity)))
		vel_xz := char_data.verlet_component.velocity
		vel_xz.y = 0
		text_entry(fmt.tprintf("Speed_XZ {:.1f}", linalg.length(vel_xz)))
		text_entry(fmt.tprintf("Current State {}", char_data.current_state))

		// Rope length
		rope_length := linalg.distance(
			char_data.verlet_component.position,
			char_data.hooked_position,
		)
		text_entry(fmt.tprintf("Rope Length {:.1f}", char_data.is_hooked ? rope_length : 0))

		// Enegies
		m: f32 = 0.01
		potential_energy := m * 30.0 * (char_data.verlet_component.position.y + 50.0)
		kinetic_energy :=
			0.5 *
			m *
			linalg.length(char_data.verlet_component.velocity) *
			linalg.length(char_data.verlet_component.velocity)
		total_energy := potential_energy + kinetic_energy
		text_entry(fmt.tprintf("Potential {:.1f}", potential_energy))
		text_entry(fmt.tprintf("Kinetic {:.1f}", kinetic_energy))
		text_entry(fmt.tprintf("Total {:.1f}", total_energy))
		text_entry(
			fmt.tprintf(
				"Best run    {}",
				players.game.best_time != 0 ? fmt.tprintf("{:.3f}", players.game.best_time) : fmt.tprint("No Time Set"),
			),
		)
		text_entry(fmt.tprintf("Author time {:.3f}", level.author_time))
	}
}


layout_reticle :: proc(
	players: ^plrs.Players, // screen_dimentions: [2]i32,
	// screen_rect: mu.Rect,
) {
	if clay.UI(clay.ID("reticle_main"))(
		config = clay.ElementDeclaration {
			floating = clay.FloatingElementConfig {
				zIndex = 0,
				expand = {2.0, 2.0},
				attachTo = .Parent,
				attachment = clay.FloatingAttachPoints{parent = .CenterCenter},
			},
			backgroundColor = layout.COLOR_GREEN,
		},
	) {

	}
}


layout_speedrun_timer :: proc(players: ^plrs.Players) {

	duration_seconds := time.duration_seconds(
		time.stopwatch_duration(players.game.speedrun_stop_watch),
	)

	if clay.UI(clay.ID("speedrun_timer_main"))(
		config = clay.ElementDeclaration {
			floating = clay.FloatingElementConfig {
				attachTo = .Parent,
				attachment = clay.FloatingAttachPoints{parent = .CenterTop},
				expand = {100, 100},
			},
			// backgroundColor = layout.COLOR_GREEN,
		},
	) {
		text_entry(fmt.tprintf("{:.3f} s", duration_seconds), .Center)

	}
}

// Important that the memory of 'clicked' exitsts until 'EndLayout' is called
Layout_Button :: proc(text: string, color, color_hover : clay.Color, clicked: ^bool,) {


	if clay.UI()(
		config = clay.ElementDeclaration {
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
			},

			backgroundColor = clay.Hovered() ? color_hover : color,
		},
	) {

		on_hoover :: proc "c" (id: clay.ElementId, pointerData: clay.PointerData, userData: rawptr){
			clicked := cast(^bool)userData 
			clicked^ = pointerData.state == .PressedThisFrame
		}
		clay.OnHover(on_hoover, clicked)

		text_entry(fmt.tprintf("{} hover? :{}", text, clay.Hovered()))
	}
}

Cheats_Panel_UI_State :: struct {
	show_controls, show_cheats: bool,
}


layout_cheats_panel :: proc(players: ^plrs.Players, game_state: ^game_state.Game_State, test_bool: ^bool) {

	if clay.UI(clay.ID("cheats_panel_main"))(
		config = clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				layoutDirection = .TopToBottom,
				sizing = clay.Sizing{width = clay.SizingPercent(0.3), height = clay.SizingGrow()},
			},
			backgroundColor = layout.COLOR_RED,
		},
	) {

		// clay.GetMaxElementCount

		// if .ACTIVE in mu.treenode(ctx, "Controls", {mu.Opt.EXPANDED}) {
		// }
		//
		// 		mu.get_current_container(ctx).rect = screen_rect
		//
		// 		mu.layout_next(ctx)
		//
		// 		if .ACTIVE in mu.treenode(ctx, "CHEATS") {
		if clay.UI()(
			config = clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					layoutDirection = .TopToBottom,
					sizing = {clay.SizingGrow(), clay.SizingFit()},
				},
			},
		) {
			layout_controls_sheet()
		}
		if clay.UI(clay.ID("binginbg"))(
			config = clay.ElementDeclaration {
				// layout = {sizing = {clay.SizingFixed(50), clay.SizingFixed(50)}},
				layout = {
					layoutDirection = .TopToBottom,
					// sizing = {clay.SizingFixed(50), clay.SizingFixed(50)},
					sizing          = {clay.SizingGrow(), clay.SizingGrow()},
				},
				backgroundColor = layout.COLOR_BLUE,
			},
		) {
			Layout_Button(fmt.tprint("test button"), layout.COLOR_BLACK, layout.COLOR_LIGHT_BLACK, test_bool)

		}
		// mu.checkbox(ctx, "air_jumping", &players.game.air_jumping_cheat)
		// mu.checkbox(ctx, "SHG_bounds", &game_state.cheat_state.draw_bounds)
		// mu.checkbox(
		// 	ctx,
		// 	"debug_draw_utils",
		// 	&game_state.cheat_state.draw_debug_draw_utilities_instructions,
		// )
		// mu.checkbox(
		// 	ctx,
		// 	"player_in_active_cell",
		// 	&game_state.cheat_state.change_color_when_player_in_cell,
		// )
		// 		}
		//
		// 		mu.layout_next(ctx)
		//
		// 		// if .ACTIVE in mu.treenode(ctx, "MISC") {
		// 		// 	if stats_container != nil {
		// 		// 		mu.layout_row(ctx, {-1})
		// 		// 		open := bool(stats_container.open)
		// 		// 		mu.checkbox(ctx, "display_stats", &open)
		// 		//
		// 		// 		stats_container.open = b32(open)
		// 		// 	}
		// 		// }
		// 	}
		//
		// }

	}
	// percent: f32 = 0.30
	// screen_rect := screen_rect
	// screen_rect.x += (cast(i32)(cast(f32)screen_rect.w * (1 - percent)))
	// screen_rect.w = cast(i32)(cast(f32)screen_rect.w * percent)
	// // rect := mu.Rect{screen_dimentions.x - 400, 0, 400, 400}
	//
	// stats_container := mu.get_container(
	// ctx, // TODO we should get the container, but it should be hidden / closed by default!
	// "stats",
	// {
	// 	// mu.Opt.NO_INTERACT,
	// 	// mu.Opt.NO_SCROLL,
	// 	// mu.Opt.CLOSED,
	// 	// mu.Opt.NO_FRAME,
	// 	// mu.Opt.NO_RESIZE,
	// 	// mu.Opt.NO_TITLE,
	// },
	// ) // TODO this crashes the game.
	// if mu.window(
	// 	ctx,
	// 	"Cheat Window (TAB to free mouse)",
	// 	screen_rect,
	// 	{mu.Opt.NO_CLOSE, mu.Opt.NO_FRAME, .NO_TITLE},
	// ) {
	// 	mu.get_current_container(ctx).rect = screen_rect
	//
	// 	if .ACTIVE in mu.treenode(ctx, "MENU (TAB to free mouse)", {mu.Opt.EXPANDED}) {
	// 		if .ACTIVE in mu.treenode(ctx, "Controls", {mu.Opt.EXPANDED}) {
	// 			controls_sheet(ctx)
	// 		}
	//
	// 		mu.get_current_container(ctx).rect = screen_rect
	//
	// 		mu.layout_next(ctx)
	//
	// 		if .ACTIVE in mu.treenode(ctx, "CHEATS") {
	// 			mu.layout_row(ctx, {-1})
	// 			mu.checkbox(ctx, "air_jumping", &players.game.air_jumping_cheat)
	//
	// 			mu.layout_row(ctx, {-1})
	// 			mu.checkbox(ctx, "SHG_bounds", &game_state.cheat_state.draw_bounds)
	//
	// 			mu.layout_row(ctx, {-1})
	// 			mu.checkbox(
	// 				ctx,
	// 				"debug_draw_utils",
	// 				&game_state.cheat_state.draw_debug_draw_utilities_instructions,
	// 			)
	//
	// 			mu.layout_row(ctx, {-1})
	// 			mu.checkbox(
	// 				ctx,
	// 				"player_in_active_cell",
	// 				&game_state.cheat_state.change_color_when_player_in_cell,
	// 			)
	// 		}
	//
	// 		mu.layout_next(ctx)
	//
	// 		// if .ACTIVE in mu.treenode(ctx, "MISC") {
	// 		// 	if stats_container != nil {
	// 		// 		mu.layout_row(ctx, {-1})
	// 		// 		open := bool(stats_container.open)
	// 		// 		mu.checkbox(ctx, "display_stats", &open)
	// 		//
	// 		// 		stats_container.open = b32(open)
	// 		// 	}
	// 		// }
	// 	}
	//
	// }
}

layout_controls_sheet :: proc() {

	text_entry(fmt.tprint("WASD	- Movement"), .Left)
	text_entry(fmt.tprint("SPACE	- Jump"), .Left)
	text_entry(fmt.tprint("R		- Reset Run"), .Left)
	text_entry(fmt.tprint("Q		- Open / Close Editor"), .Left)
}
