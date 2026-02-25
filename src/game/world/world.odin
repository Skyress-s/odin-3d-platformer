package world

import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene/"
import hent "../../engine/core/entity_handle/"
import spat "../../engine/core/spatial/"
import gent "../../game/game_entities/"
import sent "../../game/spawn_entities/"
import "base:runtime"
import "core:fmt"

import mem "core:mem"
import vmem "core:mem/virtual"

Time_Trail_Float :: f64

// Lifetime: For duration of entire program
// Contains global data.
//
//
// Impl :: struct {}
// Data :: struct {
// 	using i: Impl,
// }
//
// ALevel :: struct {
// 	using data: Data,
// }
//
// foo :: proc(i: Impl) {
// 	//
// }
//
// main :: proc() {
// 	level: ALevel
//
// 	foo(level)
// }

// Lifetime: For the duration a single "speedrun"" on a map lasts.
World :: struct {
	using collision_scene:        cs.Collision_Scene, // Reset between speedruns
	using entities:               gent.Game_Entity_Handle_Map,
	using col_meshes:             cm.Collider_Mesh_Context, // Persist between speedruns
	author_best_speedrun_capture: Speedrun_Capture,
	player_initial_state:         Player_Initial_State,
}

// Lifetime: For the duration the player is on a map.
// Maybe better name is world session?
World_Session :: struct {
	using level:                   ^World, // Only one level active at the time. Lets not overscope this project.
	// Copied when we restart the run. Important that all
	world_snapshot:                ^World,
	current_best_speedrun_capture: Speedrun_Capture,
	level_allocator:               mem.Allocator,
	level_arena:                   vmem.Arena,
}

Player_Initial_State :: struct {
	position, speed, look_direction: spat.Vector,
}

Speedrun_Capture :: struct {
	time: Time_Trail_Float,
}

// game_init :: proc(game: ^Game) {
//
// }

// game_deinit :: proc(game: ^Game) {
//
// }

world_init :: proc(world: ^World_Session) {
	arena_err := vmem.arena_init_growing(&world.level_arena)
	assert(arena_err == nil, fmt.tprint(arena_err))
	world.level_allocator = vmem.arena_allocator(&world.level_arena)
}

world_deinit :: proc(world: ^World_Session) {
	vmem.arena_destroy(&world.level_arena)
}

world_load_level :: proc(world: ^World_Session, level: ^World) {
	world.level = level
	sent.reconstruct_spatial_hash_grid_from_entities(&level.collision_scene, &world.level.entities)
	// loads level with level_allocator
	// Load relevant assets (collision meshes) and assign to Collider_Mesh_Context
}

// Does not delete level, called needs to remove level
world_unload_level :: proc(world: ^World_Session) {
	world.level = nil

	// reset collision scene
}

// External memory?
world_goto_next_level :: proc(world: ^World_Session, level_path: string) {
	free_all(world.level_allocator)
	// load level
	// assign it
	// remove unused colmeshes
	// recalc shg
}

world_restart :: proc(world: ^World_Session, level_path: string) {
	world_goto_next_level(world, level_path)
}

level_init :: proc(level: ^World, allocator: runtime.Allocator) {
	cs.init_collision_scene(&level.collision_scene, allocator)
}

level_deinit :: proc(level: ^World, allocator: runtime.Allocator) {
	cs.deinit_collision_scene(&level.collision_scene)
}
