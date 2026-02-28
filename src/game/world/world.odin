package world

import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene/"
import hent "../../engine/core/entity_handle/"
import logs "../../engine/core/logs"
import spat "../../engine/core/spatial/"
import gent "../../game/game_entities/"
import sent "../../game/spawn_entities/"
import w "../../game/world/"
import plrs "../../players/"


import "base:runtime"
import "core:fmt"
import mem "core:mem"
import vmem "core:mem/virtual"
import "core:time"

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
World_Contents :: struct {
	using collision_scene:        cs.Collision_Scene, // Reset between speedruns
	using entities:               gent.Game_Entity_Handle_Map,
	using col_meshes:             cm.Collider_Mesh_Context, // Persist between speedruns
	author_best_speedrun_capture: Speedrun_Capture,
	player_initial_state:         Player_Initial_State,
}

World :: struct {
	using world_contents: World_Contents,
	world_allocator:      mem.Allocator,
	level_arena:          vmem.Arena,
}

// Lifetime: For the duration the player is on a map.
// Maybe better name is world session?
World_Session :: struct {
	using world:                   ^World, // Only one level active at the time. Lets not overscope this project.
	using players:                 plrs.Players,
	// Copied when we restart the run. Important that all
	// world_snapshot:                ^World,
	current_best_speedrun_capture: Speedrun_Capture,
}

Player_Initial_State :: struct {
	position, speed, look_direction: spat.Vector,
}

Speedrun_Capture :: struct {
	time: time.Stopwatch,
}

// game_init :: proc(game: ^Game) {
//
// }

// game_deinit :: proc(game: ^Game) {
//
// }
//
world_init :: proc(world: ^World) {
	arena_err := vmem.arena_init_growing(&world.level_arena)
	assert(arena_err == nil, fmt.tprint(arena_err))
	world.world_allocator = vmem.arena_allocator(&world.level_arena)

}

world_deinit :: proc(world: ^World) {
	vmem.arena_destroy(&world.level_arena)
}

world_session_init :: proc(world: ^World_Session) {
}

world_session_deinit :: proc(world: ^World_Session) {
}

// set_snapshot_world :: proc(world: ^World_Session, level: ^World) {
// 	world.world_snapshot = level
// 	// sent.reconstruct_spatial_hash_grid_from_entities(&level.collision_scene, &world.level.entities)
// 	// loads level with level_allocator
// 	// Load relevant assets (collision meshes) and assign to Collider_Mesh_Context
// }
//
// restore_from_snapshot :: proc(world_session: ^World_Session) {
// 	free_all(world_session.world_allocator)
// 	fresh_world := new(World)
// 	w.world_init(fresh_world)
// 	fresh_world.world_contents = world_session.world_snapshot.world_contents
// 	world_session.world = fresh_world
// }

// Does not delete level, called needs to remove level
world_unload_level :: proc(world: ^World_Session) {
	world.world = nil

	// reset collision scene
}

// External memory?
world_goto_next_level :: proc(world_session: ^World_Session, world: ^World) {
	world_deinit(world_session.world)

	free(world_session.world)

	world_session.world = world
	// load level
	// assign it
	// remove unused colmeshes
	// recalc shg
}

// world_restart :: proc(world: ^World_Session, level_path: string) {
// 	world_goto_next_level(world, level_path)
// }
