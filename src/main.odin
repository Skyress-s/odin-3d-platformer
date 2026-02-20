package main

import "base:runtime"
import cm "core/collision_mesh"
import cs "core/collision_scene"
import csq "core/collision_scene/query"
import spat "core/spatial"
import "core:c"
import hm "core:container/handle_map"
import "core:debug/trace"
import "core:fmt"
import "core:log"
import "core:mem"
import gent "game/game_entities"
import sent "game/spawn_entities"

import character "Character"
import camera "camera"
import "core:testing"
import e_tools "editor/tools"
import app "engine"
import "game"
import gs "game_state"
import gctx "global_context"
import l "level"
import "logs"
import plrs "players"
import rlb "raylib_bridge"
import "render"
import "serialization"
import ui "ui"
import clay "ui/clay-odin"
import game_ui "ui/game_ui"
import layout2 "ui/layout"
import rl "vendor:raylib"
import vmouse "virtual_mouse"


USE_TRACESTACK :: #config(USE_TRACESTACK, false)

generate_camera :: proc() -> rl.Camera {
	return {
		position = {5, 1, 5},
		target = {0, 0, 3},
		up = {0, 3, 0},
		fovy = 95,
		projection = .PERSPECTIVE,
	}
}

when USE_TRACESTACK {
	global_trace_ctx: trace.Context

	debug_trace_assertion_failure_proc :: proc(
		prefix, message: string,
		loc := #caller_location,
	) -> ! {
		runtime.print_caller_location(loc)
		runtime.print_string(" ")
		runtime.print_string(prefix)
		if len(message) > 0 {
			runtime.print_string(": ")
			runtime.print_string(message)
		}
		runtime.print_byte('\n')

		ctx := &global_trace_ctx
		if !trace.in_resolve(ctx) {
			buf: [64]trace.Frame
			runtime.print_string("Debug Trace:\n")
			frames := trace.frames(ctx, 1, buf[:])
			for f, i in frames {
				fl := trace.resolve(ctx, f, context.temp_allocator)
				if fl.loc.file_path == "" && fl.loc.line == 0 {
					continue
				}
				runtime.print_caller_location(fl.loc)
				runtime.print_string(" - frame ")
				runtime.print_int(i)
				runtime.print_byte('\n')
			}
		}
		runtime.trap()
	}
}

disable_cursor :: proc() {
	rl.DisableCursor()
}
is_window_focused :: proc() -> bool {
	return rl.IsWindowFocused()
}
show_mouse_proc :: proc() {

	rl.EnableCursor()
}
hide_mouse_proc :: proc() {

	rl.DisableCursor()

}
is_cursor_hidden_proc :: proc() -> bool {
	return rl.IsCursorHidden()
}


main2 :: proc() {
	when USE_TRACESTACK {
		trace.init(&global_trace_ctx)
		defer trace.destroy(&global_trace_ctx)

		context.assertion_failure_proc = debug_trace_assertion_failure_proc
	}

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))

				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	context.logger = logs.init()
	defer logs.deinit()
	// defer log.destroy_console_logger(context.logger)

	// current_level := serialization.load_from_file_level("content/levels/2.I.map")
	current_level := make_basic_level()

	players := plrs.init_players()

	character.reset_run(
		&players.game,
		&current_level.start_position,
		&current_level.start_look_direction,
	)

	players.editor.transform_tool = e_tools.init_transform_tool()

	character.start_speedrun(&players.game)

	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rlb.raylib_init()
	defer rlb.raylib_deinit()


	gc: gctx.Global_Context = {
		players           = &players,
		game_state        = gs.make_default_game_state(),
		current_level     = &current_level,
		ui_context        = ui.init(),
		camera_state      = camera.init(
			generate_camera(),
			camera.Settings{fovy_increase_per_unit_speed = 0.35, lerp_speed = 5},
		),
		textures          = render.textures_init({0, 0}),
		virtual_mouse_ctx = vmouse.init(
			{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
			disable_cursor,
			is_window_focused,
			show_mouse_proc,
			hide_mouse_proc,
			is_cursor_hidden_proc,
		),
	}

	defer {
		ui.deinit(&gc.ui_context)
		l.delete_level(gc.current_level)
		render.textures_deinit(gc.textures)
	}

	// Add game window as a Layout_Item in the layout2 system

	game_window_handle := game_ui.setup_initial_window_layout(&gc)

	setup_mouse(&gc, game_window_handle)

	game_rt_needs_update := true

	rl.SetExitKey(.Y)
	for !rl.WindowShouldClose() {

		debug_draw_data, game_rect := update_all(&gc, &game_rt_needs_update, game_window_handle)

		render_all(&gc, &debug_draw_data, game_rect)

		ui.end_frame(&gc.ui_context)
		free_all(context.temp_allocator)
	}
}

update_all :: proc(
	gc: ^gctx.Global_Context,
	game_rt_needs_update: ^bool,
	game_window_handle: layout2.Layout_Item_Handle,
) -> (
	render.Debug_Draw_Data,
	rl.Rectangle,
) {

	ui_context := gc.ui_context
	layout_ctx := &ui_context.layout_ctx
	// Update first. So inputs are most up to date
	vmouse.update(
		&gc.virtual_mouse_ctx,
		rl.GetMouseDelta(),
		{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
	)

	gc.mouse_over_game = false // Will be set to true by layout_game_ui if hovered
	// Update UI state (mouse, keyboard, etc.)
	ui.update_state(&gc.ui_context, vmouse.get_mouse_pos(gc.virtual_mouse_ctx))

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

	debug_draw_data := game.update(
		gc,
		game_rect,
		gc.ui_context.layout_ctx.hover_layout_handle == game_window_handle,
		vmouse.get_mouse_pos(gc.virtual_mouse_ctx),
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
		gc.players,
		gc.camera_state.current_camera,
		debug_draw_data,
		&gc.game_state,
		game_rect,
		&gc.textures.render_targets,
	)

	// Layout pass
	free_all(gc.ui_context.layout_ctx.temp_allocator)
	clay.BeginLayout()
	layout2.layout(layout_ctx)
	ui_render_commands := clay.EndLayout()

	// Handle layout interactions (only when not hovering game)
	// TODO: Wwhn in editor mode. Game should not grab mouse (move to center) when clicking the screen
	// with the intent to change the layout
	layout2.interaction(layout_ctx, true) // !gc.mouse_over_game

	rl.BeginDrawing()
	rl.ClearBackground({14, 35, 45, 255})

	// Draw UI overlay
	layout2.render(&ui_render_commands)

	if !vmouse.is_cursor_hidden(gc.virtual_mouse_ctx) {
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

	game_ui.render_restrict_rect(gc.virtual_mouse_ctx)

	rl.EndDrawing()


}

get_game_rect :: proc(
	gc: ^gctx.Global_Context,
	game_window_handle: layout2.Layout_Item_Handle,
) -> (
	game_rect: rl.Rectangle,
) {
	game_item := layout2.get_item_checked(&gc.ui_context.layout_ctx.lic, game_window_handle)

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


@(test)
test_main :: proc(t: ^testing.T) {
	main()
}

setup_mouse :: proc(gc: ^gctx.Global_Context, game_window_handle: layout2.Layout_Item_Handle) {
	ui_context := gc.ui_context
	layout_ctx := &ui_context.layout_ctx


	// Need to layout before we access clay data to setup virtual_mouse
	layout2.normalize_sizes_recursive(&layout_ctx.lic, layout_ctx.root)
	layout2.update_layout_dir(&layout_ctx.lic, layout_ctx.root)
	{

		clay.BeginLayout()
		layout2.layout(layout_ctx)
		ui_render_commands := clay.EndLayout()
	}
	{
		item := layout2.get_item_checked(&ui_context.layout_ctx.lic, game_window_handle)
		bounds := layout2.get_clay_bounding_box_checked(item.id)

		vmouse.restrict_mouse(
			&gc.virtual_mouse_ctx,
			vmouse.Vec2{f32(bounds.x + bounds.width / 2), f32(bounds.y + bounds.height / 2)},
		)
		vmouse.hide_cursor(&gc.virtual_mouse_ctx)
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

	return level
}
