package game_interface

import character "../../Character/"
import camera "../../camera/"
import e_tools "../../editor/tools/"
import ap "../../engine/application/"
import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene/"
import csq "../../engine/core/collision_scene/query/"
import logs "../../engine/core/logs"
import spat "../../engine/core/spatial/"
import ui "../../engine/core/ui/"
import clay "../../engine/core/ui/clay-odin/"
import layout "../../engine/core/ui/layout/"
import vmouse "../../engine/core/virtual_mouse/"
import game2 "../../game/"
import gent "../../game/game_entities/"
import game_ui "../../game/game_ui/"
import sent "../../game/spawn_entities/"
import w "../../game/world/"
import gs "../../game_state/"
import player_data "../../player_data/"
import plrs "../../players/"
import rlb "../../raylib_bridge/"
import render "../../render/"
import render_game "../../render/game/"
import serial "../../serialization/serialize/"
import g "../game"
import wutils "../world_utils/"
import hm "core:container/handle_map"
import rl "vendor:raylib"

import "base:runtime"
import "core:fmt"
import "core:math/linalg"

init_game_interface :: proc(game_interface: ^ap.Game_Interface, allocator: runtime.Allocator) {
	game := new(g.Game, allocator)
	game_interface^ = ap.Game_Interface {
		game,
		game_init,
		game_deinit,
		game_update,
		game_update_physics,
		game_render,
	}
}

deinit_game_interface :: proc(game_interface: ^ap.Game_Interface, allocator: runtime.Allocator) {
	free(game_interface.data)
}

@(private)
game_init :: proc(app: ^ap.Application) {
	logs.warnf(.Gamelogic, "Initializing Game")

	serial.init_user_serializers()


	game := cast(^g.Game)app.game_interface.data
	assert(game != nil)
	game.ui_context = &app.ui_context
	game.virtual_mouse_ctx = &app.virtual_mouse_ctx

	game.textures = render.textures_init(
		{
			i32(app.ui_context.layout_ctx.screen_dimensions.width),
			i32(app.ui_context.layout_ctx.screen_dimensions.width),
		},
	)

	game.camera_state = camera.init(
		rl.Camera{fovy = 95, projection = .PERSPECTIVE},
		camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
	)
	game.world_session = new(w.World_Session)
	w.world_session_init(game.world_session)

	// current_level := serialization.load_from_file_level("content/levels/2.I.map")
	current_world := new(w.World)
	wutils.make_basic_world(current_world)
	game.world_session.last_loaded_world = serial.world_to_bytes(current_world, context.allocator)
	free(current_world)


	wutils.reload_world(game.world_session)

	// w.set_snapshot_world(game, current_world)
	// w.restore_from_snapshot(game)

	players: ^plrs.Players = &game.players
	plrs.init_players(players)
	players.editor.transform_tool = e_tools.init_transform_tool()

	player_initial_state := game.player_initial_state
	character.reset_run(
		&players.game,
		player_initial_state.position,
		player_initial_state.speed,
		player_initial_state.look_direction,
	)
	character.start_speedrun(&players.game)


	rlb.raylib_init()

	// game.global_ctx = {
	// 	players           = players,
	// 	game_state        = gs.make_default_game_state(),
	// 	ui_context        = &app.ui_context,
	// 	camera_state      = camera.init(
	// 		generate_camera(),
	// 		camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
	// 	),
	// 	textures          = render.textures_init({0, 0}),
	// 	virtual_mouse_ctx = &app.virtual_mouse_ctx,
	// }

	// Add game window as a Layout_Item in the layout system
	game_window_handle := game_ui.setup_initial_window_layout(game)
	game.game_window_handle = game_window_handle

	setup_mouse(game.ui_context, game.virtual_mouse_ctx, game_window_handle)

	game.game_rt_needs_update = true

	rl.SetExitKey(.Y)

	logs.warnf(.Gamelogic, "Finished Initializing Game")
}

@(private)
game_deinit :: proc(app: ^ap.Application) {
	logs.warnf(.Gamelogic, "Deinitializing Game")
	game := cast(^g.Game)app.game_interface.data

	render.textures_deinit(game.textures)

	rlb.raylib_deinit()


	cs.deinit_collision_scene(&game.collision_scene)

	w.world_deinit(game.world)
	free(game.world)

	w.world_session_deinit(game.world_session)
	free(game.world_session)

	serial.denit_user_serializers()

	logs.warnf(.Gamelogic, "Finished Deinitializing Game")
}

get_camera_from_active_player :: proc(game: g.Game, players: plrs.Players) -> rl.Camera {
	switch (players.mode) {
	case .Game:
		camera_state := game.camera_state
		return camera.create_camera(camera_state)
	case .Editor:
		game_player := players.editor
		player_pos := game_player.position
		_, forward, _ := player_data.calculate_direction_from_look(game_player.look_data)
		cam := rl.Camera {
			position   = player_pos,
			target     = player_pos + forward,
			up         = {0, 3, 0},
			fovy       = 95,
			projection = .PERSPECTIVE,
		}

		return cam
	}

	unreachable()
}

@(private)
game_update :: proc(app: ^ap.Application) {
	game := get_game_checked(app^)

	cam := get_camera_from_active_player(game^, game.players)

	debug_draw_data, game_rect := update_all(game, cam)

	render_all(game, &debug_draw_data, game_rect, cam)

	ui.end_frame(game.ui_context)
	free_all(context.temp_allocator)
}


@(private)
game_update_physics :: proc(app: ^ap.Application) {}
@(private)
game_render :: proc(app: ^ap.Application) {}

update_all :: proc(game: ^g.Game, cam: rl.Camera) -> (render.Debug_Draw_Data, rl.Rectangle) {
	ui_context := game.ui_context
	layout_ctx := &ui_context.layout_ctx

	// Get game rect from layout system (after first frame, use cached bounding box)
	game_rect := get_game_rect(&game.ui_context.layout_ctx, game.game_window_handle)

	debug_draw_data := game2.update(
		game,
		game_rect,
		game.ui_context.layout_ctx.hover_layout_handle == game.game_window_handle,
		vmouse.get_mouse_pos(game.virtual_mouse_ctx^),
		cam,
	)

	return debug_draw_data, game_rect
}

render_all :: proc(
	game: ^g.Game,
	debug_draw_data: ^render.Debug_Draw_Data,
	game_rect: rl.Rectangle,
	cam: rl.Camera,
) {
	if rl.IsWindowResized() {
		game.game_rt_needs_update = true
	}
	// Check if render target needs resize
	if game.game_rt_needs_update ||
	   (game.textures.render_targets.game.texture.width != i32(game_rect.width)) ||
	   (game.textures.render_targets.game.texture.height != i32(game_rect.height)) {
		render.resize_render_targets(&game.textures.render_targets, game_rect)
		game.game_rt_needs_update = false
	}

	layout_ctx := &game.ui_context.layout_ctx
	// render to RT
	render_game.render(game, debug_draw_data, game_rect, cam)

	// Layout pass
	free_all(game.ui_context.layout_ctx.temp_allocator)
	clay.BeginLayout()
	layout.layout(layout_ctx)
	ui_render_commands := clay.EndLayout()

	// logs.errorf(.UI, "Root Size {}", get_game_rect(gc, layout_ctx.root))

	// Handle layout interactions (only when not hovering game)
	// TODO: Wwhn in editor mode. Game should not grab mouse (move to center) when clicking the screen
	// with the intent to change the layout
	layout.interaction(layout_ctx, true) // !gc.mouse_over_game

	rl.BeginDrawing()
	rl.ClearBackground({14, 35, 45, 255})

	// Draw UI overlay
	layout.render(&ui_render_commands)

	if !vmouse.is_cursor_hidden(game.virtual_mouse_ctx^) {
		x := i32(game.virtual_mouse_ctx.mouse_position.x)
		y := i32(game.virtual_mouse_ctx.mouse_position.y)


		rl.DrawTexturePro(
			game.textures.cursor_texture,
			rl.Rectangle {
				0,
				0,
				f32(game.textures.cursor_texture.width - 1),
				f32(game.textures.cursor_texture.height - 1),
			},
			rl.Rectangle {
				game.virtual_mouse_ctx.mouse_position.x,
				game.virtual_mouse_ctx.mouse_position.y,
				24,
				24,
			},
			{},
			{},
			rl.WHITE,
		)

	}

	game_ui.render_restrict_rect(game.virtual_mouse_ctx^)

	rl.EndDrawing()
}

get_game_rect :: proc(
	layout_context: ^layout.Context,
	game_window_handle: layout.Layout_Item_Handle,
) -> (
	game_rect: rl.Rectangle,
) {
	game_item := layout.get_item_checked(&layout_context.lic, game_window_handle)

	// TODO: Get body not the outline.
	game_element_data := clay.GetElementData(clay.GetElementId(clay.MakeString(game_item.id)))

	if game_element_data.found {
		game_rect = rl.Rectangle {
			game_element_data.boundingBox.x,
			game_element_data.boundingBox.y,
			game_element_data.boundingBox.width,
			game_element_data.boundingBox.height,
		}
	} else {
		// Fallback for first frame before layout is computed
		game_rect = rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	}

	return game_rect
}


setup_mouse :: proc(
	ui_context: ^ui.Context,
	vmouse_ctx: ^vmouse.Context,
	game_window_handle: layout.Layout_Item_Handle,
) {
	layout_ctx := &ui_context.layout_ctx

	// Need to layout before we access clay data to setup virtual_mouse
	layout.normalize_sizes_recursive(&layout_ctx.lic, layout_ctx.root)
	layout.update_layout_dir(&layout_ctx.lic, layout_ctx.root)
	{

		clay.BeginLayout()
		layout.layout(layout_ctx)
		ui_render_commands := clay.EndLayout()
	}
	{
		item := layout.get_item_checked(&ui_context.layout_ctx.lic, game_window_handle)
		bounds := layout.get_clay_bounding_box_checked(item.id)

		vmouse.restrict_mouse(
			vmouse_ctx,
			vmouse.Vec2{f32(bounds.x + bounds.width / 2), f32(bounds.y + bounds.height / 2)},
		)
		vmouse.hide_cursor(vmouse_ctx)
	}
}


@(private)
get_game_checked :: proc(app: ap.Application) -> ^g.Game {
	game := cast(^g.Game)app.game_interface.data
	assert(game != nil)
	return game
}
