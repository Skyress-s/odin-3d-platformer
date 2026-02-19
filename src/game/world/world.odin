package world

import cm "../../core/collision_mesh/"
import cs "../../core/collision_scene/"
import hent "../../core/entity_handle/"
import spat "../../core/spatial/"
import gent "../../game/game_entities/"
import "base:runtime"
import "core:fmt"

import mem "core:mem"
import vmem "core:mem/virtual"

Time_Trail_Float :: f64

// Restart level?
//
Application :: struct {
	game: Game,
	// ui_context:        ui.Context,
	// virtual_mouse_ctx: vmouse.Context,
	// resources: fonts, textures?,

	// ----
	// players:           ^plrs.Players,
	// game_state:        gs.Game_State,
	// current_level:     ^l.Level,
	// // cam:                 ^rl.Camera3D,
	// camera_state:      camera.Global_State,
	// ui_context:        ui.Context,
	// mouse_over_game:   bool, // cursor over the game window. And not obstructed by other ui
	// virtual_mouse_ctx: vmouse.Context,
}

Game_Interface :: struct {
	data:   rawptr,
	init:   proc(app: ^Application),
	deinit: proc(app: ^Application),
	update: proc(app: ^Application),
	render: proc(app: ^Application),
}

// Lifetime: For duration of entire program
// Contains global data.
Game :: struct {
	game_world: ^World,
	// game_textures:          render.Textures,
}


// Lifetime: For the duration a single "speedrun"" on a map lasts.
Level :: struct {
	collision_scene:              cs.Collision_Scene, // Reset between speedruns
	player_initial_state:         Player_Initial_State,
	author_best_speedrun_capture: Speedrun_Capture,
	entities:                     gent.Game_Entity_Handle_Map,
}

// Lifetime: For the duration the player is on a map.
World :: struct {
	col_meshes:                    cm.Collider_Mesh_Context, // Persist between speedruns
	level:                         ^Level, // Only one level active at the time. Lets not overscope this project.
	current_best_speedrun_capture: Speedrun_Capture,

	// ---------------------------------------
	level_allocator:               mem.Allocator,
	level_arena:                   vmem.Arena,
}

Player_Initial_State :: struct {
	position, speed, look_direction: spat.Vector,
}

Speedrun_Capture :: struct {
	time: Time_Trail_Float,
}

game_init :: proc(game: ^Game) {

}

game_deinit :: proc(game: ^Game) {

}

world_init :: proc(world: ^World) {
	arena_err := vmem.arena_init_growing(&world.level_arena)
	assert(arena_err == nil, fmt.tprint(arena_err))
	world.level_allocator = vmem.arena_allocator(&world.level_arena)
}

world_deinit :: proc(world: ^World) {
	vmem.arena_destroy(&world.level_arena)
}

world_load_level :: proc(world: ^World, level: ^Level) {
	// loads level with level_allocator
	// Load relevant assets (collision meshes) and assign to Collider_Mesh_Context
}

// Does not delete level, called needs to remove level
world_unload_level :: proc(world: ^World) {
	world.level = nil

	// reset collision scene
}

// External memory?
world_goto_next_level :: proc(world: ^World, level_path: string) {
	free_all(world.level_allocator)
	// load level
	// assign it
	// remove unused colmeshes
	// recalc shg
}

world_restart :: proc(world: ^World, level_path: string) {
	world_goto_next_level(world, level_path)
}

level_init :: proc(level: ^Level, allocator: runtime.Allocator) {
	cs.init_collision_scene(&level.collision_scene, allocator)
}

level_deinit :: proc(level: ^Level, allocator: runtime.Allocator) {
	cs.deinit_collision_scene(&level.collision_scene, allocator)
}
