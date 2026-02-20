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
import world "../../game/world/"
import gs "../../game_state/"
import gctx "../../global_context/"
import l "../../level/"
import plrs "../../players/"
import rlb "../../raylib_bridge/"
import render "../../render/"
import "../../serialization/"
import game "../game"
import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

import "base:runtime"

init_game_interface :: proc(game_interface: ^ap.Game_Interface, allocator: runtime.Allocator) {
	game := new(game.Game, allocator)
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

	game := cast(^game.Game)app.game_interface.data
	assert(game != nil)

	game.game_world = new(world.World)
	world.world_init(game.game_world)

	// current_level := serialization.load_from_file_level("content/levels/2.I.map")
	current_level := new(l.Level, game.game_world.level_allocator)
	current_level^ = make_basic_level()

	players := plrs.init_players()

	character.reset_run(
		&players.game,
		&current_level.start_position,
		&current_level.start_look_direction,
	)

	players.editor.transform_tool = e_tools.init_transform_tool()

	character.start_speedrun(&players.game)

	rlb.raylib_init()


	game.global_ctx = {
		players           = players,
		game_state        = gs.make_default_game_state(),
		current_level     = current_level,
		ui_context        = &app.ui_context,
		camera_state      = camera.init(
			generate_camera(),
			camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
		),
		textures          = render.textures_init({0, 0}),
		virtual_mouse_ctx = &app.virtual_mouse_ctx,
	}

	// Add game window as a Layout_Item in the layout system

	game_window_handle := game_ui.setup_initial_window_layout(&game.global_ctx)
	game.game_window_handle = game_window_handle

	setup_mouse(&game.global_ctx, game_window_handle)

	game.game_rt_needs_update = true

	rl.SetExitKey(.Y)
	// for !rl.WindowShouldClose() {
	//
	// 	debug_draw_data, game_rect := update_all(&gc, &game_rt_needs_update, game_window_handle)
	//
	// 	render_all(&gc, &debug_draw_data, game_rect)
	//
	// 	ui.end_frame(&gc.ui_context)
	// 	free_all(context.temp_allocator)
	// }

}

@(private)
game_deinit :: proc(app: ^ap.Application) {
	logs.warnf(.Gamelogic, "Deinitializing Game")
	game := cast(^game.Game)app.game_interface.data

	// ui.deinit(game.global_ctx.ui_context)
	l.delete_level(game.global_ctx.current_level)
	render.textures_deinit(game.global_ctx.textures)

	rlb.raylib_deinit()
}

@(private)
game_update :: proc(app: ^ap.Application) {
	game := cast(^game.Game)app.game_interface.data
	gc := &game.global_ctx


	debug_draw_data, game_rect := update_all(
		gc,
		&game.game_rt_needs_update,
		game.game_window_handle,
	)

	render_all(gc, &debug_draw_data, game_rect)

	ui.end_frame(gc.ui_context)
	free_all(context.temp_allocator)
}


@(private)
game_update_physics :: proc(app: ^ap.Application) {}
@(private)
game_render :: proc(app: ^ap.Application) {}

update_all :: proc(
	gc: ^gctx.Global_Context,
	game_rt_needs_update: ^bool,
	game_window_handle: layout.Layout_Item_Handle,
) -> (
	render.Debug_Draw_Data,
	rl.Rectangle,
) {

	ui_context := gc.ui_context
	layout_ctx := &ui_context.layout_ctx
	// Update first. So inputs are most up to date

	gc.mouse_over_game = false // Will be set to true by layout_game_ui if hovered
	// Update UI state (mouse, keyboard, etc.)
	ui.update_state(gc.ui_context, vmouse.get_mouse_pos(gc.virtual_mouse_ctx^))

	if rl.IsWindowResized() {
		game_rt_needs_update^ = true
	}

	// Get game rect from layout system (after first frame, use cached bounding box)
	game_rect := get_game_rect(gc, game_window_handle)

	// Check if render target needs resize
	if game_rt_needs_update^ ||
	   (gc.textures.render_targets.game.texture.width != i32(game_rect.width)) ||
	   (gc.textures.render_targets.game.texture.height != i32(game_rect.height)) {
		render.resize_render_targets(&gc.textures.render_targets, game_rect)
		game_rt_needs_update^ = false
	}

	debug_draw_data := game2.update(
		gc,
		game_rect,
		gc.ui_context.layout_ctx.hover_layout_handle == game_window_handle,
		vmouse.get_mouse_pos(gc.virtual_mouse_ctx^),
	)

	return debug_draw_data, game_rect
}

render_all :: proc(
	gc: ^gctx.Global_Context,
	debug_draw_data: ^render.Debug_Draw_Data,
	game_rect: rl.Rectangle,
) {
	layout_ctx := &gc.ui_context.layout_ctx
	// render to RT
	render.render(
		gc.current_level,
		&gc.players,
		gc.camera_state.current_camera,
		debug_draw_data,
		&gc.game_state,
		game_rect,
		&gc.textures.render_targets,
	)

	// Layout pass
	free_all(gc.ui_context.layout_ctx.temp_allocator)
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

	if !vmouse.is_cursor_hidden(gc.virtual_mouse_ctx^) {
		x := i32(gc.virtual_mouse_ctx.mouse_position.x)
		y := i32(gc.virtual_mouse_ctx.mouse_position.y)


		rl.DrawTexturePro(
			gc.textures.cursor_texture,
			rl.Rectangle {
				0,
				0,
				f32(gc.textures.cursor_texture.width - 1),
				f32(gc.textures.cursor_texture.height - 1),
			},
			rl.Rectangle {
				gc.virtual_mouse_ctx.mouse_position.x,
				gc.virtual_mouse_ctx.mouse_position.y,
				24,
				24,
			},
			{},
			{},
			rl.WHITE,
		)

	}

	game_ui.render_restrict_rect(gc.virtual_mouse_ctx^)

	rl.EndDrawing()


}

get_game_rect :: proc(
	gc: ^gctx.Global_Context,
	game_window_handle: layout.Layout_Item_Handle,
) -> (
	game_rect: rl.Rectangle,
) {
	game_item := layout.get_item_checked(&gc.ui_context.layout_ctx.lic, game_window_handle)

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


setup_mouse :: proc(gc: ^gctx.Global_Context, game_window_handle: layout.Layout_Item_Handle) {
	ui_context := gc.ui_context
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
			gc.virtual_mouse_ctx,
			vmouse.Vec2{f32(bounds.x + bounds.width / 2), f32(bounds.y + bounds.height / 2)},
		)
		vmouse.hide_cursor(gc.virtual_mouse_ctx)
	}
}


make_basic_level :: proc() -> (level: l.Level) {
	cm.init(&level.collsion_scene.collision_meshes)
	ents := &level.entities

	ent1 := sent.spawn_box(
		{
			position = spat.ONE_VEC3 * 5,
			rotation = spat.QUATERNION_IDENTITY,
			scale = spat.ONE_VEC3 * 4,
		},
		&level,
	)
	gent.add_traits_checked({.Grabable}, ent1)

	sent.spawn_box(
		{
			position = -spat.UP_VEC3 * 8,
			rotation = spat.QUATERNION_IDENTITY,
			scale = spat.ONE_VEC3 + spat.Vector{1, 0, 1} * 8,
		},
		&level,
	)

	sent.reconstruct_spatial_hash_grid_from_entities(&level.collsion_scene, &level.entities)

	csq.shg_valid_checked(level.entities, level.collsion_scene.spatial_hash_grid)

	itr := hm.iterator_make(&level.entities)
	for item in hm.iterate(&itr) {
		logs.errorf(.Gamelogic, "ent handle {}", item.handle)
	}

	logs.errorf(.Gamelogic, "shg {}", level.collsion_scene.spatial_hash_grid)

	return level
}

generate_camera :: proc() -> rl.Camera {
	return {
		position = {5, 1, 5},
		target = {0, 0, 3},
		up = {0, 3, 0},
		fovy = 95,
		projection = .PERSPECTIVE,
	}
}
