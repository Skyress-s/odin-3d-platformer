package game_ui

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

import rl "vendor:raylib"

import ui "../"
import character "../../Character/"
import cc "../../Physics/collision_channel/"
import spat "../../Spatial/"
import et "../../editor/tools/"
import gs "../../game_state/"
import gctx "../../global_context"
import hms "../../handle_map/handle_map_static/"
import l "../../level/"
import "../../logs/"
import plrs "../../players/"
import "../../serialization/"
import vmouse "../../virtual_mouse/"
import clay "../clay-odin/"
import layout2 "../layout2/"
import ui_rr "../raylib/"

PATH_TO_LEVELS_FROM_CWD :: "content/levels/"
MAP_FILE_EXTENSION :: ".map"
MAP_FILE_EXTENSION_LENGTH :: len(MAP_FILE_EXTENSION)

layout_game_ui :: proc(node: ^layout2.Layout_Item, active_elems: ^layout2.Active_Elements) {
	gc := cast(^gctx.Global_Context)node.userdata
	assert(gc != nil)

	image_render_command := new(ui_rr.Custom_Render_Command, context.temp_allocator)
	image_render_command^ = ui_rr.Custom_Image_Render_Command {
		&gc.textures.render_targets.game.texture,
		false,
		true,
	}

	if clay.UI(clay.ID("game_render_window"))(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingGrow()}, layoutDirection = .TopToBottom},
		custom = clay.CustomElementConfig{image_render_command},
	},
	) {

		if clay.UI(clay.ID("game_window_for_mouse"))(
			config = clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					layoutDirection = .LeftToRight,
					sizing = {width = clay.SizingPercent(1), height = clay.SizingPercent(1)},

					// sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				},
				// backgroundColor = {50, 50, 50, 50},
			},
		) {
			on_hover :: proc "c" (
				id: clay.ElementId,
				pointerData: clay.PointerData,
				userData: rawptr,
			) {
				gc := cast(^gctx.Global_Context)userData

				assert_contextless(gc != nil)

				gc.mouse_over_game = gc.ui_context.layout_ctx.dragging_handle == {}
			}

			clay.OnHover(on_hover, gc)

			layout_reticle(gc.players)
			if gc.players.mode == .Game {
				layout_speedrun_timer(gc.players)
				layout_game_speed_indicator(gc.players^)


				if clay.UI(clay.ID("Game_Divide"))(
					config = clay.ElementDeclaration {
						layout = clay.LayoutConfig {
							layoutDirection = .LeftToRight,
							sizing = {
								width = clay.SizingPercent(1),
								height = clay.SizingPercent(1),
							},
							// sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						},
						// backgroundColor = {50, 50, 50, 50},
					},
				) {

					layout_stats(gc.players, gc.current_level)
				}
			} else {
				// Might want to have something here?


			}

		}
	}


	// if clay.Hovered() do log.errorf("hover over game window!!!!")


}

layout_game_cheats_window :: proc(
	node: ^layout2.Layout_Item,
	active_elems: ^layout2.Active_Elements,
) {
	gc := cast(^gctx.Global_Context)node.userdata
	assert(gc != nil)

	layout_cheats_panel(&gc.ui_context, gc.players, &gc.game_state)
}

layout_log_window :: proc(node: ^layout2.Layout_Item, active_elems: ^layout2.Active_Elements) {
	gc := cast(^gctx.Global_Context)node.userdata
	assert(gc != nil)

	if clay.UI()(
	{
		layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingGrow()}},
		clip = clay.ClipElementConfig{false, true, clay.GetScrollOffset()},
	},
	) {
		entire_log := logs.get_string_slice()
		log_lines := strings.split(entire_log, "\n")
		for log_line in log_lines {
			ui.layout_dynamic_text_entry(log_line)
		}
	}
}

layout_editor_details :: proc(node: ^layout2.Layout_Item, active_elems: ^layout2.Active_Elements) {
	gc := cast(^gctx.Global_Context)node.userdata
	assert(gc != nil)

	layout_details_panel(
		&gc.ui_context,
		gc.players,
		&gc.game_state,
		gc.current_level,
		active_elems,
	)
}

layout_ui_data :: proc(node: ^layout2.Layout_Item, active_elems: ^layout2.Active_Elements) {
	gc := cast(^gctx.Global_Context)node.userdata
	assert(gc != nil)

	ui.layout_dynamic_text_entry(
		fmt.tprintf("Dragging Id {}", gc.ui_context.layout_ctx.dragging_handle),
	)
	ui.layout_dynamic_text_entry(
		fmt.tprintf("Virtual Mouse Pos {}", vmouse.get_mouse_pos(gc.virtual_mouse_ctx)),
	)
	ui.layout_dynamic_text_entry(fmt.tprintf("Mouse Pos {}", rl.GetMousePosition()))
	ui.layout_dynamic_text_entry(fmt.tprintf("Window Focused {}", rl.IsWindowFocused()))
	ui.layout_dynamic_text_entry(
		fmt.tprintf("Restrict Rect {}", gc.virtual_mouse_ctx.mouse_restrict_rect),
	)

	// ui.layout_dynamic_text_entry(
	// 	fmt.tprintf("Controlling leaf {}", gc.ui_context.layout_ctx.controlling_layout_item),
	// )
}

EDITOR_DETAILS_PANEL_NAME :: "Editor_Details_Panel"
make_editor_details_node :: proc(
	ctx: ^layout2.Context,
	gc: ^gctx.Global_Context,
) -> layout2.Layout_Item {
	node := layout2.make_layout_item(ctx, EDITOR_DETAILS_PANEL_NAME, gc, layout_editor_details)
	return node
}

GAME_WINDOW_NAME :: "Game_Window"
make_game_window_node :: proc(
	ctx: ^layout2.Context,
	gc: ^gctx.Global_Context,
) -> layout2.Layout_Item {
	node := layout2.make_layout_item(ctx, GAME_WINDOW_NAME, gc, layout_game_ui)
	node.size_percent = {1, 1} // Fill the entire available space
	return node
}

LOG_WINDOW_NAME :: "Log_Window"
make_log_window_node :: proc(
	ctx: ^layout2.Context,
	gc: ^gctx.Global_Context,
) -> layout2.Layout_Item {
	node := layout2.make_layout_item(ctx, LOG_WINDOW_NAME, gc, layout_game_ui)
	node.size_percent = {1, 1} // Fill the entire available space
	return node
}


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
		ui.layout_dynamic_text_entry(
			fmt.tprintf("Position {:4.0f}", char_data.verlet_component.position),
		)
		ui.layout_dynamic_text_entry(fmt.tprintf("FPS {}", rl.GetFPS()))

		// Velocities
		ui.layout_dynamic_text_entry(
			fmt.tprintf("Velocity {:.1f}", char_data.verlet_component.velocity),
		)
		ui.layout_dynamic_text_entry(
			fmt.tprintf("speed {:.1f}", linalg.length(char_data.verlet_component.velocity)),
		)
		vel_xz := char_data.verlet_component.velocity
		vel_xz.y = 0
		ui.layout_dynamic_text_entry(fmt.tprintf("Speed_XZ {:.1f}", linalg.length(vel_xz)))
		ui.layout_dynamic_text_entry(fmt.tprintf("Current State {}", char_data.current_state))

		// Rope length
		rope_length := linalg.distance(
			char_data.verlet_component.position,
			char_data.hooked_position,
		)
		ui.layout_dynamic_text_entry(
			fmt.tprintf("Rope Length {:.1f}", char_data.is_hooked ? rope_length : 0),
		)

		// Enegies
		m: f32 = 0.01
		potential_energy := m * 30.0 * (char_data.verlet_component.position.y + 50.0)
		kinetic_energy :=
			0.5 *
			m *
			linalg.length(char_data.verlet_component.velocity) *
			linalg.length(char_data.verlet_component.velocity)
		total_energy := potential_energy + kinetic_energy
		ui.layout_dynamic_text_entry(fmt.tprintf("Potential {:.1f}", potential_energy))
		ui.layout_dynamic_text_entry(fmt.tprintf("Kinetic {:.1f}", kinetic_energy))
		ui.layout_dynamic_text_entry(fmt.tprintf("Total {:.1f}", total_energy))
		ui.layout_dynamic_text_entry(
			fmt.tprintf(
				"Best run    {}",
				players.game.best_time != 0 ? fmt.tprintf("{:.3f}", players.game.best_time) : fmt.tprint("No Time Set"),
			),
		)
		ui.layout_dynamic_text_entry(fmt.tprintf("Author time {:.3f}", level.author_time))
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
				pointerCaptureMode = .Passthrough,
			},
			backgroundColor = layout2.COLOR_GREEN,
		},
	) {

	}
}

layout_game_speed_indicator :: proc(
	players: plrs.Players, // screen_dimentions: [2]i32,
	// screen_rect: mu.Rect,
) {
	player_speed := linalg.length(players.game.verlet_component.velocity)
	ui_height_mod := (u16(player_speed) / 8)
	if clay.UI(clay.ID("speed_text"))(
		config = clay.ElementDeclaration {
			layout = {
				childAlignment = {.Center, .Center},
				sizing         = {
					clay.SizingFixed(300),
					clay.SizingFixed(32 + c.float(ui_height_mod)),
				},
				// sizing = {clay.SizingFit(), clay.SizingFit()},
			},
			floating = clay.FloatingElementConfig {
				attachTo = .Parent,
				attachment = clay.FloatingAttachPoints {
					parent = .CenterBottom,
					element = .CenterBottom,
				},
				expand = {0, 0},
				pointerCaptureMode = .Passthrough,
				offset = {
					// math.sin_f32(f32(rl.GetTime()) * f32(player_speed) / 10) * 15,
					0,
					-32 * 2 + c.float(ui_height_mod) / 2,
				}, // -32 font height
			},
			backgroundColor = clay.Color{50, 50, 50, 50},
		},
	) {

		player_speed := linalg.length(players.game.verlet_component.velocity)
		clay.TextDynamic(
			fmt.tprintf("{:0.0f}", player_speed),
			clay.TextConfig(
				{
					fontSize = 32 + ui_height_mod,
					fontId = layout2.FONT_ID_BODY_16,
					textColor = layout2.COLOR_LIGHT,
					textAlignment = .Right,
					wrapMode = .Words,
					lineHeight = 32,
					letterSpacing = 0,
				},
			),
		)
		// ui.layout_dynamic_text_entry()
		// ui.layout_dynamic_text_entry(
		// 	fmt.tprintf("{:4.1f} u/s", linalg.length(players.game.verlet_component.velocity)),
		// 	.Right,
		// )

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
				pointerCaptureMode = .Passthrough,
			},
			// backgroundColor = layout.COLOR_GREEN,
		},
	) {
		ui.layout_dynamic_text_entry(fmt.tprintf("{:.3f} s", duration_seconds), .Center)

	}
}

Cheats_Panel_UI_State :: struct {
	show_controls, show_cheats: bool,
}


layout_cheats_panel :: proc(ctx: ^ui.Context, players: ^plrs.Players, game_state: ^gs.Game_State) {


	if clay.UI(clay.ID("cheats_panel_main"))(
		config = clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				layoutDirection = .TopToBottom,
				sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
			},
			// backgroundColor = layout.COLOR_RED,
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
		}
		@(static) panel_cheats_dropdown := false
		if ui.layout_dropdown(ctx, fmt.tprint("Cheats"), &panel_cheats_dropdown) {

			@(static) cheats_dropdown := false
			@(static) controls_dropdown := false
			if ui.layout_dropdown(ctx, fmt.tprint("Controls"), &controls_dropdown) {
				layout_controls_sheet()
			}
			if ui.layout_dropdown(ctx, fmt.tprint("Cheats"), &cheats_dropdown) {

				ui.layout_checkbox("air_jumping", &players.game.air_jumping_cheat)

				ui.layout_checkbox("SHG_bounds", &game_state.cheat_state.draw_bounds)
				ui.layout_checkbox(
					"debug_draw_utils",
					&game_state.cheat_state.draw_debug_draw_utilities_instructions,
				)
				ui.layout_checkbox(
					"player_in_active_cell",
					&game_state.cheat_state.change_color_when_player_in_cell,
				)
			}
		}

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

	ui.layout_dynamic_text_entry(fmt.tprint("WASD  - Movement"), .Left)
	ui.layout_dynamic_text_entry(fmt.tprint("SPACE - Jump"), .Left)
	ui.layout_dynamic_text_entry(fmt.tprint("R     - Reset Run"), .Left)
	ui.layout_dynamic_text_entry(fmt.tprint("Q     - Open / Close Editor"), .Left)
}


layout_details_panel :: proc(
	ctx: ^ui.Context,
	players: ^plrs.Players,
	game_state: ^gs.Game_State,
	level: ^l.Level,
	active_elems: ^layout2.Active_Elements,
) {
	current_id := players.editor.transform_tool.target_object_id


	col_scene := &level.collsion_scene

	@(static) object_manip_dropdown := false
	if current_id != spat.INVALID_OBJECT_ID {
		current_coll_obj := hms.get(&level.collsion_scene.collision_object_map, current_id)
		if ui.layout_dropdown(ctx, fmt.tprintf("Object Manipulation"), &object_manip_dropdown) {

			ui.layout_dynamic_text_entry(fmt.tprint(current_id))
			if ui.layout_button_immediate(ctx, fmt.tprint("Duplicate")) {
				if current_coll_obj != nil {
					new_id := spat.add_to_level(
						&col_scene.collision_object_map,
						&col_scene.spatial_hash_grid,
						current_coll_obj.data,
					)

					_, is_kill_volume := col_scene.kill_volumes[current_id]
					if is_kill_volume {
						col_scene.kill_volumes[new_id] = true
					}

					_, is_grappable := col_scene.grappable[current_id]
					if is_grappable {
						col_scene.grappable[new_id] = true
					}
				}
			}
			if ui.layout_button_immediate(ctx, fmt.tprint("Delete")) {
				if current_coll_obj != nil {
					spat.remove_from_level(
						&col_scene.collision_object_map,
						&col_scene.spatial_hash_grid,
						current_id,
					)
					players.editor.transform_tool.target_object_id = {}

					logs.debug(.UI, "id {}", current_id)
					logs.debug(.UI, "kill_volumes {}", col_scene.kill_volumes)
					logs.debug(.UI, "before {}", len(col_scene.kill_volumes))
					delete_key(&col_scene.kill_volumes, current_id)
					logs.debug(.UI, "after {}", len(col_scene.kill_volumes))
					delete_key(&col_scene.grappable, current_id)
					delete_key(&col_scene.finish_volumes, current_id)
					return
				}
			}


			{
				_, is_kill_volume := col_scene.kill_volumes[current_id]

				if ui.layout_checkbox_immediate(ctx, fmt.tprint("Kill Volume"), &is_kill_volume) {
					if is_kill_volume do col_scene.kill_volumes[current_id] = true
					else do delete_key(&col_scene.kill_volumes, current_id)
				}
			}

			{
				_, grappable := col_scene.grappable[current_id]

				if ui.layout_checkbox_immediate(ctx, fmt.aprintf("Grappable"), &grappable) {
					if grappable do col_scene.grappable[current_id] = true
					else do delete_key(&col_scene.grappable, current_id)
				}
			}

			{
				is_colliding := cc.is_blocking(current_coll_obj.collision_channels)
				if ui.layout_checkbox_immediate(ctx, fmt.aprintf("Colliding"), &is_colliding) {
					current_coll_obj.collision_channels =
						is_colliding ? cc.get_blocking() : cc.get_non_blocking()
					// TODO we should also activate kill volumes when we get a normal collision.
				}
			}

			{
				if ui.layout_button_immediate(ctx, fmt.tprint("Reset Rotation")) {
					current_coll_obj.transform.rotation = spat.QUATERNION_IDENTITY
				}
				if ui.layout_button_immediate(ctx, fmt.tprint("Random Rotation")) {
					current_coll_obj.transform.rotation = spat.rand_rot()
				}
			}

		}
	}


	@(static) level_stuff_dropdown := false
	if ui.layout_dropdown(ctx, fmt.tprint("Level Stuff"), &level_stuff_dropdown) {

		@(static) buf: [128]byte
		@(static) buf_len: int

		clicked_file_path := map_directory(ctx, active_elems)

		double_click := (clicked_file_path != "" && string(buf[:buf_len]) == clicked_file_path)

		if clicked_file_path != "" {
			builder := strings.builder_make()

			fmt.println(clicked_file_path)
			buf_len = copy(buf[0:], clicked_file_path)

		}

		if clay.UI()(
		{
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
			},
		},
		) {
			ui.layout_dynamic_text_entry(fmt.tprint("Level: "))
			ui.layout_textbox_immediate2(ctx, buf[:], &buf_len)

		}


		// mu.text(ctx, "Level:")
		// if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {
		// 	fmt.println("Submit!")
		// }

		if ui.layout_button_immediate(ctx, fmt.tprint("Save Level")) {

			level.author_time = players.game.best_time
			serialization.save_to_file(level, to_cwd_map_path_from_local(string(buf[:buf_len])))
		}

		// if mu.Result.SUBMIT in mu.button(ctx, "save_level") {
		// 	level.author_time = players.game.best_time
		//
		// 	serialization.save_to_file(level, to_cwd_map_path_from_local(string(buf[:buf_len])))
		//
		// }

		if ui.layout_button_immediate(ctx, fmt.tprint("Load Level")) {
			level^ = serialization.load_from_file_level(
				to_cwd_map_path_from_local(string(buf[:buf_len])),
			)

			character.notify_level_loaded(&players.game)
			character.reset_run(&players.game, &level.start_position, &level.start_look_direction)

		}

	}

	// ui.set_focus(ctx, "ui_playground")
	if ui.layout_dropdown(ctx, fmt.tprintf("ui_playground"), &object_manip_dropdown) {
		@(static) text_buf: [512]byte = {}
		@(static) text_buf_length: int = 0
		ui.layout_textbox_immediate2(ctx, text_buf[:], &text_buf_length) // , clay.GetElementId(clay.MakeString("ui_playground")).id
	}


	layout_editor_options(ctx)
}


layout_editor_options :: proc(ctx: ^ui.Context) {
	ui.layout_checkbox("Edit Objects Local", &et.tooltip_local)
}


map_directory :: proc(ctx: ^ui.Context, active_elems: ^layout2.Active_Elements) -> string {

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


	return vis_dir(
		ctx,
		os.File_Info{fullpath = filepath.join({cwd, PATH_TO_LEVELS_FROM_CWD})},
		active_elems,
		true,
	)
}

vis_dir :: proc(
	ctx: ^ui.Context,
	file_dir: os.File_Info,
	active_elems: ^layout2.Active_Elements,
	force_open: bool = false,
) -> string {
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

	// opts: mu.Options = force_open ? {mu.Opt.EXPANDED} : {}

	clicked_map_name := ""


	active_elem := layout2.active_elements_get_or_add(active_elems, current_dir_name)
	if ui.layout_dropdown(ctx, fmt.tprintf("{}", current_dir_name), &active_elem.active) {
		for fi in fis {
			full_directory, name := filepath.split(fi.fullpath)

			if len(name) > MAP_FILE_EXTENSION_LENGTH do name = name[:(len(name) - MAP_FILE_EXTENSION_LENGTH)]

			if fi.is_dir {
				dir_name := vis_dir(ctx, fi, active_elems)
				if dir_name != "" do clicked_map_name = dir_name
			} else if strings.contains(filepath.ext(fi.name), MAP_FILE_EXTENSION) {
				if ui.layout_button_immediate(ctx, fmt.tprintf("{}", name)) {
					clicked_map_name = to_local_from_cwd_map_path(fi.fullpath)
				}
			}

		}
	}
	// if .ACTIVE in mu.begin_treenode(ctx, fmt.aprintf("{}", current_dir_name), opts) {
	// 	for fi in fis {
	// 		full_directory, name := filepath.split(fi.fullpath)
	//
	// 		if len(name) > MAP_FILE_EXTENSION_LENGTH do name = name[:(len(name) - MAP_FILE_EXTENSION_LENGTH)]
	//
	// 		if fi.is_dir {
	// 			dir_name := vis_dir(ctx, fi)
	// 			if dir_name != "" do clicked_map_name = dir_name
	// 		} else if strings.contains(filepath.ext(fi.name), MAP_FILE_EXTENSION) {
	// 			if .SUBMIT in mu.button(ctx, fmt.aprintf("{}", name)) {
	//
	// 				clicked_map_name = to_local_from_cwd_map_path(fi.fullpath)
	// 			}
	// 		}
	//
	// 	}
	//
	// 	mu.end_treenode(ctx)
	// }

	return clicked_map_name
}

// Example: will transform Morgan_Amazing to content/levels/Morgan_Amazing.map
to_cwd_map_path_from_local :: proc(local_path: string) -> string {
	return filepath.join(
		{PATH_TO_LEVELS_FROM_CWD, strings.concatenate({local_path, MAP_FILE_EXTENSION})},
	)
}

// Example: will transform content/levels/Morgan_Amazing.map to Morgan_Amazing
to_local_from_cwd_map_path :: proc(cwd_path: string) -> string {
	local_path, _ := filepath.rel(
		filepath.join({os.get_current_directory(), PATH_TO_LEVELS_FROM_CWD}),
		cwd_path,
	)
	local_path = local_path[:(len(local_path) - MAP_FILE_EXTENSION_LENGTH)]

	return local_path
}

render_restrict_rect :: proc(ctx: vmouse.Context) {

	top_left := ctx.mouse_restrict_rect.position
	top_right := top_left + {ctx.mouse_restrict_rect.dimensions.x, 0}
	bottom_left := top_left + {0, ctx.mouse_restrict_rect.dimensions.y}
	bottom_right := top_right + {0, ctx.mouse_restrict_rect.dimensions.y}

	LINE_THICKNESS :: 8
	draw_mouse_restrict_corner_box :: proc(pos: vmouse.Vec2) {
		rl.DrawRectangle(
			i32(pos.x - LINE_THICKNESS / 2),
			i32(pos.y - LINE_THICKNESS / 2),
			LINE_THICKNESS,
			LINE_THICKNESS,
			rl.PURPLE,
		)
	}
	rl.DrawLineEx(top_left, top_right, LINE_THICKNESS, rl.PURPLE)
	rl.DrawLineEx(top_right, bottom_right, LINE_THICKNESS, rl.PURPLE)
	rl.DrawLineEx(bottom_right, bottom_left, LINE_THICKNESS, rl.PURPLE)
	rl.DrawLineEx(bottom_left, top_left, LINE_THICKNESS, rl.PURPLE)
	draw_mouse_restrict_corner_box(top_left)
	draw_mouse_restrict_corner_box(top_right)
	draw_mouse_restrict_corner_box(bottom_left)
	draw_mouse_restrict_corner_box(bottom_right)
}

setup_initial_window_layout :: proc(
	gc: ^gctx.Global_Context,
) -> (
	game_handle: layout2.Layout_Item_Handle,
) {
	layout_ctx := &gc.ui_context.layout_ctx

	game_window_item := make_game_window_node(layout_ctx, gc)
	game_window_handle := layout2.add_layout_node(
		&layout_ctx.lic,
		layout_ctx.root,
		0,
		game_window_item,
	)
	{
		ui_layout_item := layout2.make_layout_item(layout_ctx, "ui_details", gc, layout_ui_data)
		ui_layout_item.size_percent = {0.5, 0.5}
		layout2.add_layout_node(&layout_ctx.lic, layout_ctx.root, 0, ui_layout_item)
	}
	{
		log_layout_item := layout2.make_layout_item(layout_ctx, "log", gc, layout_log_window)
		log_layout_handle := layout2.add_layout_node(
			&layout_ctx.lic,
			layout_ctx.root,
			0,
			log_layout_item,
		)

		editor_default_layout_item := layout2.make_layout_item(
			layout_ctx,
			"editor_details",
			gc,
			layout_editor_details,
		)

		editor_default_layout_item_handle := layout2.add_to_context(
			layout_ctx,
			editor_default_layout_item,
		)

		layout2.insert_item_new_level(
			layout_ctx,
			{0.5, 0.5},
			0,
			.Bottom,
			log_layout_handle,
			editor_default_layout_item_handle,
		)
	}
	{
	}
	return game_window_handle
}
