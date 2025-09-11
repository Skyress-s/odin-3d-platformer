package mph_ui

import character "../Character"
import cc "../Physics/collision_channel/"
import spat "../Spatial"
import e_plr "../editor_player"
import gs "../game_state"
import "../game_state"
import hms "../handle_map/handle_map_static/"
import l "../level"
import plrs "../players"
import serialization "../serialization"
import "core:fmt"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import mu "vendor:microui"

all_windows :: proc(
	ctx: ^mu.Context,
	players: ^plrs.Players,
	game_state: ^gs.Game_State,
	screen_dimensions: [2]i32,
	level: ^l.Level,
) {
	// 	timer := time.Stopwatch{}
	// time.stopwatch_start(&timer)

	screen_rect := mu.Rect{0, 0, screen_dimensions.x, screen_dimensions.y}

	draw_reticle(ctx, screen_dimensions)

	switch players.mode {
	case .Game:
		cheats_panel(ctx, screen_dimensions, players, game_state, screen_rect)
		speedrun_timer(ctx, screen_dimensions, players, screen_rect)

		stats(ctx, players, game_state, screen_rect)

		if game_state.finished_level {
			if mu.window(ctx, "FINISHED LEVEL", screen_rect) {
				mu.layout_row(ctx, {-1})
				mu.text(
					ctx,
					fmt.aprintf(
						"You finished the level in: {:.1f}",
						time.duration_seconds(
							time.stopwatch_duration(players.game.speedrun_stop_watch),
						),
					),
				)

			}
		}


	case .Editor:
		details_panel(ctx, players, game_state, screen_rect, level)
	}
}

map_directory :: proc(ctx: ^mu.Context) -> string {

	cwd := os.get_current_directory()
	f, err := os.open(cwd)
	defer os.close(f)
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not open directory for reading", err)
		os.exit(1)
	}
	fis: []os.File_Info
	defer os.file_info_slice_delete(fis)

	fis, err = os.read_dir(f, -1) // -1 reads all file infos
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not read directory", err)
		os.exit(2)
	}


	return vis_dir(ctx, os.File_Info{fullpath = filepath.join({cwd, "levels"})}, true)
}

vis_dir :: proc(ctx: ^mu.Context, file_dir: os.File_Info, force_open: bool = false) -> string {
	// fmt.println("Trying to vis_dir: ", file_dir.fullpath)
	cwd := file_dir
	f, err := os.open(cwd.fullpath)
	defer os.close(f)
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not open directory for reading", err)
		os.exit(1)
	}
	fis: []os.File_Info
	defer os.file_info_slice_delete(fis)

	fis, err = os.read_dir(f, -1) // -1 reads all file infos
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not read directory", err)
		os.exit(2)
	}

	current_dir_name := filepath.base(file_dir.fullpath)

	opts: mu.Options = force_open ? {mu.Opt.EXPANDED} : {}

	clicked_map_name := ""
	if .ACTIVE in mu.begin_treenode(ctx, fmt.aprintf("{}", current_dir_name), opts) {
		for fi in fis {
			full_directory, name := filepath.split(fi.fullpath)


			if fi.is_dir {
				dir_name := vis_dir(ctx, fi)
				if dir_name != "" do clicked_map_name = dir_name
			} else if strings.contains(filepath.ext(fi.name), ".map") {
				if .SUBMIT in mu.button(ctx, fmt.aprintf("{}", name)) {
					clicked_map_name, _ = filepath.rel(os.get_current_directory(), fi.fullpath)
					// fmt.println("cwd:", os.get_current_directory())
					// fmt.println("target: ", fi.fullpath)
					// fmt.println(clicked_map_name)
					//clicked_map_name = fi.fullpath
				}
			}

			//mu.layout_row(ctx, {-1})

			//fmt.printfln("%v (%v bytes)", name, fi.size)

		}

		mu.end_treenode(ctx)
	}

	return clicked_map_name
}

speedrun_timer :: proc(
	ctx: ^mu.Context,
	screen_dimentions: [2]i32,
	players: ^plrs.Players,
	screen_rect: mu.Rect,
) {
	width, height: i32 = 250, 50
	target_rect := mu.Rect{screen_dimentions.x / 2 - width / 2, 0, width, height}
	if mu.window(
		ctx,
		"t",
		target_rect,
		{mu.Opt.NO_FRAME, .NO_TITLE, .NO_INTERACT, .NO_SCROLL, .NO_RESIZE},
	) {
		current_container := mu.get_current_container(ctx)
		current_container.rect = target_rect
		mu.layout_row(ctx, {-1})
		duration_seconds := time.duration_seconds(
			time.stopwatch_duration(players.game.speedrun_stop_watch),
		)
		mu.text(ctx, fmt.aprintf("Current time: {:.1f}", duration_seconds))

	}
}

cheats_panel :: proc(
	ctx: ^mu.Context,
	screen_dimentions: [2]i32,
	players: ^plrs.Players,
	game_state: ^game_state.Game_State,
	screen_rect: mu.Rect,
) {

	percent: f32 = 0.30
	screen_rect := screen_rect
	screen_rect.x += (cast(i32)(cast(f32)screen_rect.w * (1 - percent)))
	screen_rect.w = cast(i32)(cast(f32)screen_rect.w * percent)
	// rect := mu.Rect{screen_dimentions.x - 400, 0, 400, 400}

	stats_container := mu.get_container(ctx, "stats")
	if mu.window(
		ctx,
		"Cheat Window (TAB to free mouse)",
		screen_rect,
		{mu.Opt.NO_CLOSE, mu.Opt.NO_FRAME},
	) {
		mu.get_current_container(ctx).rect = screen_rect


		mu.text(ctx, "CHEATS")
		mu.layout_row(ctx, {-1})
		mu.checkbox(ctx, "air_jumping", &players.game.air_jumping_cheat)

		mu.layout_row(ctx, {-1})
		mu.checkbox(ctx, "draw_spatial_hash_grid_bounds", &game_state.cheat_state.draw_bounds)

		mu.layout_row(ctx, {-1})
		mu.checkbox(
			ctx,
			"change_color_when\nplayer_in_cell",
			&game_state.cheat_state.change_color_when_player_in_cell,
		)

		mu.layout_next(ctx)
		mu.layout_next(ctx)
		mu.text(ctx, "MISC")

		mu.layout_row(ctx, {-1})
		open := bool(stats_container.open) 
		mu.checkbox(ctx, "display_stats", &open)

		stats_container.open = b32(open)
	}
}

file_path_load_save := ""

details_panel :: proc(
	ctx: ^mu.Context,
	players: ^plrs.Players,
	game_state: ^gs.Game_State,
	screen_rect: mu.Rect,
	level: ^l.Level,
) {

	percent: f32 = 0.40
	screen_rect := screen_rect
	screen_rect.x += (cast(i32)(cast(f32)screen_rect.w * (1 - percent)))
	screen_rect.w = cast(i32)(cast(f32)screen_rect.w * percent)

	if mu.window(ctx, "details_panel", screen_rect, {}) {

		current_container := mu.get_current_container(ctx)
		current_container.rect = screen_rect

		current_id := players.editor.transform_tool.target_object_id


		if current_id != spat.INVALID_OBJECT_ID {
			current_coll_obj := hms.get(&level.collision_object_map, current_id)
			if (.ACTIVE in mu.treenode(ctx, "Object Manipulation")) {
				mu.layout_row(ctx, {-1})
				if mu.Result.SUBMIT in mu.button(ctx, "duplicate") {
					if current_coll_obj != nil {
						spat.add_to_level(
							&level.collision_object_map,
							&level.spatial_hash_grid,
							current_coll_obj.data,
						)
					}
				}
				{
					_, is_kill_volume := level.kill_volumes[current_id]
					// copy_is_kill_volume := is_kill_volume

					if .CHANGE in mu.checkbox(ctx, fmt.aprintf("Kill Volume"), &is_kill_volume) {
						if is_kill_volume do level.kill_volumes[current_id] = true
						else do delete_key(&level.kill_volumes, current_id)
					}
				}

				{
					_, grappable := level.grappable[current_id]
					// copy_is_kill_volume := is_kill_volume

					if .CHANGE in mu.checkbox(ctx, fmt.aprintf("Grappable"), &grappable) {
						if grappable do level.grappable[current_id] = true
						else do delete_key(&level.grappable, current_id)
					}
				}

				{
					is_colliding := cc.is_blocking(current_coll_obj.collision_channels)
					if .CHANGE in mu.checkbox(ctx, fmt.aprintf("Colliding"), &is_colliding) {
						current_coll_obj.collision_channels =
							is_colliding ? cc.get_blocking() : cc.get_non_blocking()
						// TODO we should also activate kill volumes when we get a normal collision.
					}
				}

			}}


		if .ACTIVE in mu.treenode(ctx, "Level Stuff") {
			@(static) buf: [128]byte
			@(static) buf_len: int

			mu.layout_row(ctx, {-1})
			if mu.Result.SUBMIT in mu.button(ctx, "save_level") {
				serialization.save_to_file(level, string(buf[:buf_len]))
			}
			mu.layout_row(ctx, {-1})
			if mu.Result.SUBMIT in mu.button(ctx, "load_level") {
				level^ = serialization.load_from_file_level(string(buf[:buf_len]))
				character.reset_run(
					&players.game,
					&level.start_position,
					&level.start_look_direction,
				)
			}

			mu.layout_next(ctx) // Also function as a spaces

			mu.layout_row(ctx, {65, -1})
			mu.text(ctx, "Level:")
			if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {
				fmt.println("Submit!")
			}


			clicked_file_path := map_directory(ctx)
			if clicked_file_path != "" {
				// level^ = serialization.load_from_file_level(clicked_file_path)
				builder := strings.builder_make()

				// state.log_buf_len += copy(state.log_buf[state.log_buf_len:], str)
				fmt.println(clicked_file_path)
				buf_len = copy(buf[0:], clicked_file_path)

			}
		}
	}
}

stats :: proc(
	ctx: ^mu.Context,
	players: ^plrs.Players,
	game_state: ^game_state.Game_State,
	screen_rect: mu.Rect,
) {
	if mu.window(
		ctx,
		"stats",
		mu.Rect{0, 0, screen_rect.w / 2, screen_rect.h},
		{
			mu.Opt.CLOSED,
			mu.Opt.NO_INTERACT,
			mu.Opt.NO_SCROLL,
			mu.Opt.NO_CLOSE,
			mu.Opt.NO_FRAME,
			mu.Opt.NO_RESIZE,
			mu.Opt.NO_TITLE,
		},
	) {
		char_data := &players.game
		mu.get_current_container(ctx).zindex = -100000
		// mu.layout_row(ctx, {-1})
		// mu.label(ctx, fmt.aprintf("FPS {}", rl.GetFPS()))
		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.aprintf("Position {}", char_data.verlet_component.position))
		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.aprintf("Velocity {}", char_data.verlet_component.velocity))

		mu.layout_row(ctx, {-1})
		vel_xz := char_data.verlet_component.velocity
		vel_xz.y = 0
		mu.label(ctx, fmt.aprintf("Velocity_XZ {}", linalg.length(vel_xz)))

		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.aprintf("Current State {}", char_data.current_state))

		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.aprintf("Player Data {}", char_data.verlet_component.position))

		// Rope length
		rope_length := linalg.distance(
			char_data.verlet_component.position,
			char_data.hooked_position,
		)
		mu.layout_row(ctx, {-1})
		mu.text(ctx, fmt.aprintf("Rope Length {}", char_data.is_hooked ? rope_length : 0))


		m: f32 = 0.01
		potential_energy := m * 30.0 * (char_data.verlet_component.position.y + 50.0)
		kinetic_energy :=
			0.5 *
			m *
			linalg.length(char_data.verlet_component.velocity) *
			linalg.length(char_data.verlet_component.velocity)
		total_energy := potential_energy + kinetic_energy

		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.aprintf("Potential {}", potential_energy))

		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.aprintf("Kinetic {}", kinetic_energy))

		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.aprintf("Total {}", total_energy))


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
