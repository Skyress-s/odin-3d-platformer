package world

import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene/"
import hent "../../engine/core/entity_handle/"
import spat "../../engine/core/spatial/"
import gent "../../game/game_entities/"
import "base:runtime"
import "core:fmt"

import mem "core:mem"
import vmem "core:mem/virtual"

Time_Trail_Float :: f64

// Lifetime: For duration of entire program
// Contains global data.


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

// game_init :: proc(game: ^Game) {
//
// }
//
// game_deinit :: proc(game: ^Game) {
//
// }

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
	cs.deinit_collision_scene(&level.collision_scene)
}
