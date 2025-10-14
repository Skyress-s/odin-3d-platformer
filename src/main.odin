package main


import "core:strings"
import "render"
import "core:time"
import "core:log"
import "core:os"
import character "Character"
import p "Physics"
import cc "Physics/collision_channel"
import verlet "Physics/verlet"
import spat "Spatial"
import "base:builtin"
import intrinsics "base:intrinsics"
import "base:runtime"
import col "color"
import "core:debug/trace"
import "core:fmt"
import "core:io"
import "core:math"
import "core:math/linalg"
import "core:testing"
import ddu "debug_draw_utils"
import e_tools "editor/tools"
import "editor_player"
import "game"
import gs "game_state"
import hms "handle_map/handle_map_static"
import l "level"
import "lightray"
import gameui "micro-ui"
import mph_ui "mph_ui"
import "player_data"
import rlb "raylib_bridge"

import _players "players"
import "serialization"
import mu "vendor:microui"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import m_log "mph_log"


// global_trace_ctx: trace.Context
//
// debug_trace_assertion_failure_proc :: proc(prefix, message: string, loc := #caller_location) -> ! {
// 	runtime.print_caller_location(loc)
// 	runtime.print_string(" ")
// 	runtime.print_string(prefix)
// 	if len(message) > 0 {
// 		runtime.print_string(": ")
// 		runtime.print_string(message)
// 	}
// 	runtime.print_byte('\n')
//
// 	ctx := &global_trace_ctx
// 	if !trace.in_resolve(ctx) {
// 		buf: [64]trace.Frame
// 		runtime.print_string("Debug Trace:\n")
// 		frames := trace.frames(ctx, 1, buf[:])
// 		for f, i in frames {
// 			fl := trace.resolve(ctx, f, context.temp_allocator)
// 			if fl.loc.file_path == "" && fl.loc.line == 0 {
// 				continue
// 			}
// 			runtime.print_caller_location(fl.loc)
// 			runtime.print_string(" - frame ")
// 			runtime.print_int(i)
// 			runtime.print_byte('\n')
// 		}
// 	}
//
// 	runtime.trap()
// }

// some_type :: distinct union #no_nil {i32, f32}

game_static_shaders :: struct {
	shader_editor_tool_depth: ^rl.Shader,
}


logger_proc :: proc(data: rawptr, level: runtime.Logger_Level, text: string, options: runtime.Logger_Options, location := #caller_location)
{
	// string_data := cast(^string)data
	fmt.println(text)
	m_log.write_log(fmt.aprintf("{}: {}", strings.to_upper(fmt.aprint(level)), text))

	log.file_logger_proc(data, level, text, options, location)
	// string_data := cast(^log.File_Console_Logger_Data)data

	// fmt.printfln("{}: {}", level, text)
}

some_val :int  

main :: proc() {

	hand, open_file_err := os.open("test_log4.log", os.O_CREATE | os.O_RDWR | os.O_TRUNC, 0o666)
	if open_file_err != nil {

		fmt.println(open_file_err)
		return
	}
	defer os.close(hand)

	logger := log.create_file_logger(hand)
	defer log.destroy_file_logger(logger)


	context.logger = logger
	context.logger.procedure = logger_proc

	m_log.write_log("hello")
	log.infof("test")
	log.warn("This is a warning")
	// log.warn("This is a warning")
	// log.warn("This is a warning")
	// log.warn("This is a warning")

	// log.logf(log.Level.Error, "logging")
	// log.errorf("Error!!!!")
	//
	// log.debug("test")
	// log.warnf("this is a warning")


	// fmt.println("tufntufnt")


	game_state := gs.make_default_game_state()

	players := _players.Players{}

	players.mode = _players.Player_Mode.Game
	players.game = character.CharacternData {
		radius = 1,
		current_state = character.Airborne{},
		verlet_component = verlet.Velocity_Verlet_Component{position = spat.Vector{0, 0, 0}},
	}

	players.editor = editor_player.Editor_Player_Data {
		movement_speed = 30,
	}


	current_level := serialization.load_from_file_level("content/levels/2.I.map")

	current_level.start_position = spat.Vector{0, 100, 0}

	character.reset_run(
		&players.game,
		&current_level.start_position,
		&current_level.start_look_direction,
	)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1920, 1085, "mph*0.5mv^2")
	//rl.ToggleBorderlessWindowed()
	defer rl.CloseWindow()

	// rl.SetTargetFPS(180)
	rl.SetTargetFPS(180) // TODO CCD not working at low fps

	rl.SetWindowSize(rl.GetScreenWidth(), rl.GetScreenHeight())
	rl.DisableCursor()

	gameui.init_game_ui(&gameui.state.mu_ctx)
	defer gameui.deinit_game_ui()

	cam: rl.Camera3D = {
		position   = {5, 1, 5},
		target     = {0, 0, 3},
		up         = {0, 3, 0},
		fovy       = 110,
		projection = .PERSPECTIVE,
	}

	// position_transform_tool
	players.editor.transform_tool = e_tools.init_transform_tool(
		e_tools.State.Position,
		spat.Plane{spat.Vector{0, 10, 0}, spat.Vector{0, 1, 0}},
		rl.GetMousePosition(),
		&cam,
	)

	position_transform_tool := &players.editor.transform_tool

	character.start_speedrun(&players.game)

	// Shader stuff


	lightray.init_lighting()
	defer lightray.destroy_lighting()

	lightray.create_light(.DIRECTIONAL, {10, 10, 10}, spat.ZERO_VEC3, rl.RAYWHITE)
	{
		// backlight_color := rl.SKYBLUE
		backlight_color := rl.SKYBLUE
		// Color{ 102, 191, 255, 255 }

		lightray.create_light(.DIRECTIONAL, {-10, -10, 10}, spat.ZERO_VEC3, backlight_color)
	}

	gc: game.Global_Context = {
		players       = &players,
		game_state    = &game_state,
		current_level = &current_level,
		cam           = &cam,
	}

	rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
	// TODO make esc NOT close the 
	for !rl.WindowShouldClose() {
		debug_draw_data := game.update(&gc)
		render.render(gc.current_level, gc.players, gc.cam, &debug_draw_data, gc.game_state)
	}
}

get_default_start_location_look_direction :: proc() -> (location, look_direction: spat.Vector) {
	location = {0, 0, 0}
	look_direction = {1, 0, 0}
	return location, look_direction
}

add_debug_level_objects :: proc(
	level: ^l.Level,
	collision_objects: ^spat.Collision_Object_Handle_Map,
	spaital_hash_grid: ^map[spat.Hash_Key]spat.Hash_Cell,
) {

	q := linalg.QUATERNIONF32_IDENTITY


	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{16, 16, 16}, q, {1, 1, 1}}, spat.Box{{10.0, 10.0, 9.0}}},
	)

	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape {
			{{9, 17, 9}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
			spat.Box{{1.0, 1.0, 1.0}},
		},
	)

	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape {
			{{0, -20, 0}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
			spat.Box{{150.0, 10.0, 150}},
		},
	)

	// spat.add_shape_to_hash_map(
	// 	collision_objects,
	// 	spaital_hash_grid,
	// 	&spat.Collision_Shape{{{17, 6, 9}, {}, {1, 1, 1}}, spat.Sphere{5.0}},
	// )
	//
	// spat.add_shape_to_hash_map(
	// 	collision_objects,
	// 	spaital_hash_grid,
	// 	&spat.Collision_Shape{{{-32, 0, 0}, q, {1, 1, 1}}, spat.Cylinder{9.0, 3.0}},
	// )

	q2 := linalg.quaternion_from_forward_and_up_f32({1, 1, 1}, {1, -1, 1})
	//box3 := Collision_Shape{i, {{-32, 0, 0}, q, {2, 2, 2}}, Box{{9.0, 9.0, 9.0}}}
	spat.add_shape_to_hash_map(
		collision_objects,
		spaital_hash_grid,
		&spat.Collision_Shape{{{-32, 0, 0}, q2, {2, 2, 2}}, spat.Box{{9.0, 9.0, 9.0}}},
	)

	for box_num in 0 ..= 5 {
		id := spat.add_shape_to_hash_map(
			collision_objects,
			spaital_hash_grid,
			&spat.Collision_Shape {
				{{cast(f32)(box_num * 90 + 100), 0, 0}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
				spat.Box{{3, 3, 40}},
			},
		)

		level.grappable[id] = true

	}

	tris: [dynamic]spat.Collision_Triangle

	append_quad :: proc(
		tris: ^[dynamic]spat.Collision_Triangle,
		a, b, c, d: rl.Vector3,
		offs: rl.Vector3 = {},
	) {
		points := []spat.Collision_Triangle {
			spat.Collision_Triangle{{b + offs, a + offs, c + offs}},
			spat.Collision_Triangle{{b + offs, c + offs, d + offs}},
		}
		append(tris, ..points)
	}

	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 0})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 10})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 0, 10})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 10, 10}, {10, 10, 10}, {10, 0, 20})
	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 10, 30})

	spat.create_and_add_collision_object_from_tris(
		collision_objects,
		spaital_hash_grid,
		tris,
		true,
	)

	// Add finish volume
	finish_object_shape := spat.Collision_Shape {
		spat.Transform{spat.Vector{0, -10, 0}, spat.QUATERNION_IDENTITY, spat.ONE_VEC3},
		spat.Box{{4, 4, 4}},
	}
	bounds := spat.get_bounds(finish_object_shape)
	collision_object_data := spat.shape_to_collision_object(&finish_object_shape)
	collision_object_data.collision_channels = cc.get_non_blocking()

	id := spat.add_to_object_map(collision_objects, collision_object_data)
	spat.add_to_spatial_hash_grid(spaital_hash_grid, collision_object_data, id)
	spat.add_to_finish_volumes(&level.finish_volumes, id)
}

@(test)
first_test :: proc(t: ^testing.T) {
	testing.expect(t, true)

}
