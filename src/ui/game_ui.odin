package game_ui

import "core:fmt"
import "core:math/linalg"
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
	level: ^l.Level,
) {
	// target_rect := mu.Rect{0, 0, screen_rect.w / 2, screen_rect.h}
	// clay.BeginLayout()
	if clay.UI(clay.ID("stats_main"))(
	{
		// layout = {layoutDirection = node.layout_dir, sizing = {clay.SizingGrow(), clay.SizingGrow()}, padding = clay.PaddingAll(node_leaf_distance(node) == 1 ? 8/2 : 0), childGap = node_leaf_distance(node) == 1 ? 8 : 0},
		layout = {layoutDirection = .TopToBottom},
		floating = clay.FloatingElementConfig {
			offset = {50, 50},
			attachTo = .Parent,
			zIndex = 1000,
		},
		backgroundColor = {0, 0, 0, 0}, // node_leaf_distance(node^) == 0 ? auto_hightlight_color() : leaf_dist_to_color(node_leaf_distance(node^)),
	},
	) {
		text_entry :: proc(text: string) {
			clay.TextDynamic(
				text,
				clay.TextConfig(
					{
						fontSize = 32,
						fontId = layout.FONT_ID_BODY_16,
						textColor = layout.COLOR_LIGHT,
					},
				),
			)

		}
		char_data := &players.game
		text_entry(fmt.tprintf("Position {:4.0f}", char_data.verlet_component.position))
		text_entry(fmt.tprintf("Position {:4.0f}", char_data.verlet_component.position))
		text_entry(fmt.tprintf("FPS {}", rl.GetFPS()))

		// Velocities
		text_entry(fmt.tprintf("Velocity {:.1f}", char_data.verlet_component.velocity))
		vel_xz := char_data.verlet_component.velocity
		vel_xz.y = 0
		text_entry(fmt.tprintf("Velocity_XZ {:.1f}", linalg.length(vel_xz)))
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
		text_entry(fmt.tprintf("Best run    {}", players.game.best_time != 0 ? fmt.tprintf("{:.3f}",players.game.best_time) : fmt.tprint("No Time Set")))
		text_entry(fmt.tprintf("Author time {:.3f}", level.author_time))
	}
}
